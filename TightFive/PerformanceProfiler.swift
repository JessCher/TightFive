import SwiftUI
import UIKit
import Combine

/// Advanced performance profiler for debugging bottlenecks
/// 
/// Usage:
/// 1. Add `.performanceOverlay()` to your root view
/// 2. Tap the FPS badge to show detailed metrics
/// 3. Use `PerformanceProfiler.shared.measureSync` for synchronous operations
/// 4. Use `PerformanceProfiler.shared.measureAsync` for async operations
///
/// Example:
/// ```swift
/// PerformanceProfiler.shared.measureSync("View Setup") {
///     // Your code here
/// }
/// ```
@MainActor
final class PerformanceProfiler: ObservableObject {
    static let shared = PerformanceProfiler()
    
    // MARK: - Published State
    @Published var isOverlayVisible = false
    @Published var currentFPS: Double = 60.0
    @Published var cpuUsage: Double = 0.0
    @Published var memoryUsageMB: Double = 0.0
    @Published var activeOperations: [String] = []
    
    // MARK: - Metrics
    struct Metric: Identifiable {
        let id = UUID()
        let name: String
        let duration: TimeInterval
        let timestamp: Date
        let cpuAtStart: Double
        let cpuAtEnd: Double
        let memoryAtStart: Double
        let memoryAtEnd: Double
        
        var formattedDuration: String {
            if duration < 0.001 {
                return String(format: "%.3f µs", duration * 1_000_000)
            } else if duration < 1.0 {
                return String(format: "%.2f ms", duration * 1000)
            } else {
                return String(format: "%.2f s", duration)
            }
        }
        
        var severity: MetricSeverity {
            if duration > 0.5 {
                return .critical
            } else if duration > 0.1 {
                return .warning
            } else if duration > 0.016 { // > 1 frame at 60fps
                return .attention
            } else {
                return .normal
            }
        }
    }
    
    enum MetricSeverity {
        case normal
        case attention
        case warning
        case critical
        
        var color: Color {
            switch self {
            case .normal: return .green
            case .attention: return .yellow
            case .warning: return .orange
            case .critical: return .red
            }
        }
    }
    
    @Published private(set) var metrics: [Metric] = []
    private let maxMetrics = 200
    
    // MARK: - Display Link for FPS
    private var displayLink: CADisplayLink?
    private var frameCount = 0
    private var lastTimestamp: CFTimeInterval = 0
    
    // MARK: - Monitoring Timer
    private var monitoringTimer: Timer?
    
    // MARK: - Initialization
    private init() {}
    
    // MARK: - Control
    func startMonitoring() {
        stopMonitoring()
        
        // FPS monitoring
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkTick))
        displayLink?.add(to: .main, forMode: .common)
        
        // CPU/Memory monitoring - every 0.5 seconds
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.updateSystemMetrics()
        }
    }
    
    func stopMonitoring() {
        displayLink?.invalidate()
        displayLink = nil
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }
    
    @objc private func displayLinkTick() {
        guard let displayLink else { return }
        
        let currentTimestamp = displayLink.timestamp
        
        if lastTimestamp == 0 {
            lastTimestamp = currentTimestamp
            return
        }
        
        frameCount += 1
        let elapsed = currentTimestamp - lastTimestamp
        
        if elapsed >= 1.0 {
            currentFPS = Double(frameCount) / elapsed
            frameCount = 0
            lastTimestamp = currentTimestamp
        }
    }
    
    private func updateSystemMetrics() {
        cpuUsage = _getCPUUsage()
        memoryUsageMB = _getMemoryUsage()
    }
    
    // MARK: - Measurement
    
    /// Measure a synchronous operation
    func measureSync(_ name: String, operation: () -> Void) {
        let cpuStart = _getCPUUsage()
        let memStart = _getMemoryUsage()
        let start = CFAbsoluteTimeGetCurrent()
        
        activeOperations.append(name)
        operation()
        activeOperations.removeAll { $0 == name }
        
        let duration = CFAbsoluteTimeGetCurrent() - start
        let cpuEnd = _getCPUUsage()
        let memEnd = _getMemoryUsage()
        
        recordMetric(name: name, duration: duration, cpuStart: cpuStart, cpuEnd: cpuEnd, memStart: memStart, memEnd: memEnd)
    }
    
    /// Measure an async operation
    func measureAsync(_ name: String, operation: @escaping () async throws -> Void) async rethrows {
        let cpuStart = _getCPUUsage()
        let memStart = _getMemoryUsage()
        let start = CFAbsoluteTimeGetCurrent()
        
        activeOperations.append(name)
        try await operation()
        activeOperations.removeAll { $0 == name }
        
        let duration = CFAbsoluteTimeGetCurrent() - start
        let cpuEnd = _getCPUUsage()
        let memEnd = _getMemoryUsage()
        
        recordMetric(name: name, duration: duration, cpuStart: cpuStart, cpuEnd: cpuEnd, memStart: memStart, memEnd: memEnd)
    }
    
    /// Start timing an operation (useful for delegate callbacks)
    func startOperation(_ name: String) -> OperationTimer {
        return OperationTimer(name: name, profiler: self)
    }
    
    // MARK: - Internal methods (used by OperationTimer)
    
    internal func getCPUUsage() -> Double {
        return _getCPUUsage()
    }
    
    internal func getMemoryUsage() -> Double {
        return _getMemoryUsage()
    }
    
    internal func recordMetric(name: String, duration: TimeInterval, cpuStart: Double, cpuEnd: Double, memStart: Double, memEnd: Double) {
        let metric = Metric(
            name: name,
            duration: duration,
            timestamp: Date(),
            cpuAtStart: cpuStart,
            cpuAtEnd: cpuEnd,
            memoryAtStart: memStart,
            memoryAtEnd: memEnd
        )
        
        metrics.append(metric)
        
        if metrics.count > maxMetrics {
            metrics.removeFirst(metrics.count - maxMetrics)
        }
        
        // Log slow operations
        if duration > 0.016 { // More than 1 frame
            print("⚠️ SLOW: \(name) took \(metric.formattedDuration)")
            if cpuEnd - cpuStart > 10 {
                print("   CPU increased by \(String(format: "%.1f", cpuEnd - cpuStart))%")
            }
        }
    }
    
    // MARK: - System Metrics
    
    private func _getCPUUsage() -> Double {
        var totalUsage: Double = 0.0
        var threadsList: thread_act_array_t?
        var threadsCount = mach_msg_type_number_t(0)
        
        let result = withUnsafeMutablePointer(to: &threadsList) {
            task_threads(mach_task_self_, $0, &threadsCount)
        }
        
        guard result == KERN_SUCCESS, let threads = threadsList else {
            return 0.0
        }
        
        defer {
            vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: threads)), vm_size_t(Int(threadsCount) * MemoryLayout<thread_t>.stride))
        }
        
        for i in 0..<threadsCount {
            var threadInfo = thread_basic_info()
            var threadInfoCount = mach_msg_type_number_t(THREAD_INFO_MAX)
            
            let infoResult = withUnsafeMutablePointer(to: &threadInfo) {
                $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                    thread_info(threads[Int(i)], thread_flavor_t(THREAD_BASIC_INFO), $0, &threadInfoCount)
                }
            }
            
            guard infoResult == KERN_SUCCESS else { continue }
            
            let basicInfo = threadInfo
            if basicInfo.flags & TH_FLAGS_IDLE == 0 {
                totalUsage += (Double(basicInfo.cpu_usage) / Double(TH_USAGE_SCALE)) * 100.0
            }
        }
        
        return totalUsage
    }
    
    private func _getMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else { return 0.0 }
        
        return Double(info.resident_size) / 1024.0 / 1024.0
    }
    
    // MARK: - Export
    func exportCSV() -> String {
        var csv = "Timestamp,Name,Duration (s),Duration (ms),CPU Start,CPU End,CPU Delta,Memory Start (MB),Memory End (MB),Memory Delta (MB),Severity\n"
        
        for metric in metrics {
            let cpuDelta = metric.cpuAtEnd - metric.cpuAtStart
            let memDelta = metric.memoryAtEnd - metric.memoryAtStart
            
            csv += "\(metric.timestamp.ISO8601Format()),"
            csv += "\"\(metric.name)\","
            csv += "\(metric.duration),"
            csv += "\(metric.duration * 1000),"
            csv += "\(metric.cpuAtStart),"
            csv += "\(metric.cpuAtEnd),"
            csv += "\(cpuDelta),"
            csv += "\(metric.memoryAtStart),"
            csv += "\(metric.memoryAtEnd),"
            csv += "\(memDelta),"
            csv += "\(metric.severity)\n"
        }
        
        return csv
    }
    
    func exportJSON() -> Data {
        struct MetricExport: Codable {
            let timestamp: String
            let name: String
            let duration: TimeInterval
            let durationMs: Double
            let cpuStart: Double
            let cpuEnd: Double
            let cpuDelta: Double
            let memoryStartMB: Double
            let memoryEndMB: Double
            let memoryDeltaMB: Double
            let severity: String
        }
        
        struct PerformanceReport: Codable {
            let exportDate: String
            let totalMetrics: Int
            let currentFPS: Double
            let currentCPU: Double
            let currentMemoryMB: Double
            let metrics: [MetricExport]
        }
        
        let metricExports = metrics.map { metric in
            let cpuDelta = metric.cpuAtEnd - metric.cpuAtStart
            let memDelta = metric.memoryAtEnd - metric.memoryAtStart
            
            return MetricExport(
                timestamp: metric.timestamp.ISO8601Format(),
                name: metric.name,
                duration: metric.duration,
                durationMs: metric.duration * 1000,
                cpuStart: metric.cpuAtStart,
                cpuEnd: metric.cpuAtEnd,
                cpuDelta: cpuDelta,
                memoryStartMB: metric.memoryAtStart,
                memoryEndMB: metric.memoryAtEnd,
                memoryDeltaMB: memDelta,
                severity: "\(metric.severity)"
            )
        }
        
        let report = PerformanceReport(
            exportDate: Date().ISO8601Format(),
            totalMetrics: metrics.count,
            currentFPS: currentFPS,
            currentCPU: cpuUsage,
            currentMemoryMB: memoryUsageMB,
            metrics: metricExports
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        do {
            return try encoder.encode(report)
        } catch {
            print("Failed to encode JSON: \(error)")
            return Data()
        }
    }
    
    func exportSummaryReport() -> String {
        var report = "PERFORMANCE SUMMARY REPORT\n"
        report += "Generated: \(Date().formatted(date: .complete, time: .standard))\n"
        report += String(repeating: "=", count: 70) + "\n\n"
        
        // Current Metrics
        report += "📊 CURRENT METRICS\n"
        report += String(repeating: "-", count: 70) + "\n"
        report += String(format: "FPS:        %.1f fps\n", currentFPS)
        report += String(format: "CPU Usage:  %.1f%%\n", cpuUsage)
        report += String(format: "Memory:     %.1f MB\n\n", memoryUsageMB)
        
        // Statistics
        let totalOperations = metrics.count
        let slowOperations = metrics.filter { $0.severity != .normal }.count
        let criticalOperations = metrics.filter { $0.severity == .critical }.count
        
        report += "📈 STATISTICS\n"
        report += String(repeating: "-", count: 70) + "\n"
        report += "Total Operations:    \(totalOperations)\n"
        report += "Slow Operations:     \(slowOperations)\n"
        report += "Critical Operations: \(criticalOperations)\n\n"
        
        if !metrics.isEmpty {
            let avgDuration = metrics.map { $0.duration }.reduce(0, +) / Double(metrics.count)
            let maxDuration = metrics.map { $0.duration }.max() ?? 0
            let minDuration = metrics.map { $0.duration }.min() ?? 0
            
            report += String(format: "Average Duration:    %.2f ms\n", avgDuration * 1000)
            report += String(format: "Max Duration:        %.2f ms\n", maxDuration * 1000)
            report += String(format: "Min Duration:        %.2f ms\n\n", minDuration * 1000)
        }
        
        // Top 10 Slowest Operations
        let slowest = metrics.sorted { $0.duration > $1.duration }.prefix(10)
        if !slowest.isEmpty {
            report += "🐌 TOP 10 SLOWEST OPERATIONS\n"
            report += String(repeating: "-", count: 70) + "\n"
            for (index, metric) in slowest.enumerated() {
                let icon = metric.severity == .critical ? "🔴" : 
                          metric.severity == .warning ? "🟠" : 
                          metric.severity == .attention ? "🟡" : "🟢"
                report += String(format: "%2d. %@ %@ - %@\n", 
                    index + 1, 
                    icon,
                    metric.name.padding(toLength: 40, withPad: " ", startingAt: 0),
                    metric.formattedDuration
                )
            }
            report += "\n"
        }
        
        // Most Frequent Operations
        let operationCounts = Dictionary(grouping: metrics, by: { $0.name })
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
            .prefix(10)
        
        if !operationCounts.isEmpty {
            report += "🔁 MOST FREQUENT OPERATIONS\n"
            report += String(repeating: "-", count: 70) + "\n"
            for (index, (name, count)) in operationCounts.enumerated() {
                report += String(format: "%2d. %@ (×%d)\n", index + 1, name, count)
            }
            report += "\n"
        }
        
        // CPU Impact
        let highCPUOps = metrics.filter { ($0.cpuAtEnd - $0.cpuAtStart) > 10 }
            .sorted { ($0.cpuAtEnd - $0.cpuAtStart) > ($1.cpuAtEnd - $1.cpuAtStart) }
            .prefix(10)
        
        if !highCPUOps.isEmpty {
            report += "🔥 HIGHEST CPU IMPACT OPERATIONS\n"
            report += String(repeating: "-", count: 70) + "\n"
            for (index, metric) in highCPUOps.enumerated() {
                let cpuDelta = metric.cpuAtEnd - metric.cpuAtStart
                report += String(format: "%2d. %@ (+%.1f%% CPU)\n", 
                    index + 1,
                    metric.name.padding(toLength: 40, withPad: " ", startingAt: 0),
                    cpuDelta
                )
            }
            report += "\n"
        }
        
        // Recommendations
        report += "💡 RECOMMENDATIONS\n"
        report += String(repeating: "-", count: 70) + "\n"
        
        if currentFPS < 30 {
            report += "• CRITICAL: FPS is below 30. UI will feel very sluggish.\n"
        } else if currentFPS < 55 {
            report += "• WARNING: FPS is below 55. UI may feel slightly laggy.\n"
        }
        
        if cpuUsage > 100 {
            report += "• CRITICAL: CPU usage over 100%. Device will heat up and drain battery.\n"
        } else if cpuUsage > 50 {
            report += "• WARNING: CPU usage is high. Consider optimizing frequent operations.\n"
        }
        
        if criticalOperations > 0 {
            report += "• ATTENTION: \(criticalOperations) operations took over 500ms. These need optimization.\n"
        }
        
        if slowOperations > totalOperations / 2 {
            report += "• WARNING: Over 50% of operations are slow (>16ms). Review performance optimizations.\n"
        }
        
        report += "\n" + String(repeating: "=", count: 70) + "\n"
        report += "End of Report\n"
        
        return report
    }
    
    func clearMetrics() {
        metrics.removeAll()
    }
}

// MARK: - Operation Timer

struct OperationTimer {
    let name: String
    let profiler: PerformanceProfiler
    let startTime: CFAbsoluteTime
    let cpuStart: Double
    let memStart: Double
    
    init(name: String, profiler: PerformanceProfiler) {
        self.name = name
        self.profiler = profiler
        self.startTime = CFAbsoluteTimeGetCurrent()
        self.cpuStart = profiler.getCPUUsage()
        self.memStart = profiler.getMemoryUsage()
        profiler.activeOperations.append(name)
    }
    
    func stop() {
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        let cpuEnd = profiler.getCPUUsage()
        let memEnd = profiler.getMemoryUsage()
        
        profiler.activeOperations.removeAll { $0 == name }
        profiler.recordMetric(name: name, duration: duration, cpuStart: cpuStart, cpuEnd: cpuEnd, memStart: memStart, memEnd: memEnd)
    }
}




