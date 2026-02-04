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
            self?.updateSystemMetrics()
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
        cpuUsage = getCPUUsage()
        memoryUsageMB = getMemoryUsage()
    }
    
    // MARK: - Measurement
    
    /// Measure a synchronous operation
    func measureSync(_ name: String, operation: () -> Void) {
        let cpuStart = getCPUUsage()
        let memStart = getMemoryUsage()
        let start = CFAbsoluteTimeGetCurrent()
        
        activeOperations.append(name)
        operation()
        activeOperations.removeAll { $0 == name }
        
        let duration = CFAbsoluteTimeGetCurrent() - start
        let cpuEnd = getCPUUsage()
        let memEnd = getMemoryUsage()
        
        recordMetric(name: name, duration: duration, cpuStart: cpuStart, cpuEnd: cpuEnd, memStart: memStart, memEnd: memEnd)
    }
    
    /// Measure an async operation
    func measureAsync(_ name: String, operation: @escaping () async throws -> Void) async rethrows {
        let cpuStart = getCPUUsage()
        let memStart = getMemoryUsage()
        let start = CFAbsoluteTimeGetCurrent()
        
        activeOperations.append(name)
        try await operation()
        activeOperations.removeAll { $0 == name }
        
        let duration = CFAbsoluteTimeGetCurrent() - start
        let cpuEnd = getCPUUsage()
        let memEnd = getMemoryUsage()
        
        recordMetric(name: name, duration: duration, cpuStart: cpuStart, cpuEnd: cpuEnd, memStart: memStart, memEnd: memEnd)
    }
    
    /// Start timing an operation (useful for delegate callbacks)
    func startOperation(_ name: String) -> OperationTimer {
        return OperationTimer(name: name, profiler: self)
    }
    
    private func recordMetric(name: String, duration: TimeInterval, cpuStart: Double, cpuEnd: Double, memStart: Double, memEnd: Double) {
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
    
    private func getCPUUsage() -> Double {
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
    
    private func getMemoryUsage() -> Double {
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

// MARK: - UI Overlay

struct PerformanceProfilerOverlay: View {
    @StateObject private var profiler = PerformanceProfiler.shared
    
    var body: some View {
        VStack {
            HStack {
                Spacer()
                
                if !profiler.isOverlayVisible {
                    // Compact FPS badge
                    fpsCompactBadge
                } else {
                    // Detailed overlay
                    detailedOverlay
                }
            }
            .padding()
            
            Spacer()
        }
    }
    
    private var fpsCompactBadge: some View {
        Button {
            withAnimation(.spring(duration: 0.3)) {
                profiler.isOverlayVisible.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(fpsColor)
                    .frame(width: 8, height: 8)
                
                Text("\(Int(profiler.currentFPS)) FPS")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.2), radius: 4)
        }
    }
    
    private var detailedOverlay: some View {
        VStack(alignment: .trailing, spacing: 12) {
            // Header
            HStack {
                Text("Performance")
                    .font(.headline)
                
                Spacer()
                
                Button {
                    profiler.clearMetrics()
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                }
                .help("Clear metrics")
                
                Menu {
                    Button {
                        shareCSV()
                    } label: {
                        Label("Export CSV File", systemImage: "square.and.arrow.up")
                    }
                    
                    Button {
                        copyCSVToClipboard()
                    } label: {
                        Label("Copy CSV to Clipboard", systemImage: "doc.on.clipboard")
                    }
                    
                    Button {
                        shareJSON()
                    } label: {
                        Label("Export JSON File", systemImage: "curlybraces")
                    }
                    
                    Button {
                        shareSummaryReport()
                    } label: {
                        Label("Export Summary Report", systemImage: "doc.text")
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.caption)
                }
                .help("Export performance data")
                
                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        profiler.isOverlayVisible = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                }
            }
            
            // Metrics
            VStack(alignment: .leading, spacing: 8) {
                metricRow(label: "FPS", value: String(format: "%.1f", profiler.currentFPS), color: fpsColor)
                metricRow(label: "CPU", value: String(format: "%.1f%%", profiler.cpuUsage), color: cpuColor)
                metricRow(label: "Memory", value: String(format: "%.1f MB", profiler.memoryUsageMB), color: .blue)
                
                if !profiler.activeOperations.isEmpty {
                    Divider()
                    Text("Active:")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    ForEach(profiler.activeOperations, id: \.self) { op in
                        Text("• \(op)")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                }
            }
            
            // Recent slow operations
            if let slowOps = profiler.metrics.suffix(10).filter({ $0.severity != .normal }), !slowOps.isEmpty {
                Divider()
                
                Text("Recent Issues:")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(slowOps) { metric in
                            HStack {
                                Circle()
                                    .fill(metric.severity.color)
                                    .frame(width: 6, height: 6)
                                
                                Text(metric.name)
                                    .font(.caption2)
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                Text(metric.formattedDuration)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .frame(maxHeight: 150)
            }
        }
        .padding()
        .frame(width: 280)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.3), radius: 12)
    }
    
    private func metricRow(label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(color)
        }
    }
    
    private var fpsColor: Color {
        if profiler.currentFPS >= 55 {
            return .green
        } else if profiler.currentFPS >= 30 {
            return .orange
        } else {
            return .red
        }
    }
    
    private var cpuColor: Color {
        if profiler.cpuUsage < 50 {
            return .green
        } else if profiler.cpuUsage < 100 {
            return .orange
        } else {
            return .red
        }
    }
    
    private func shareCSV() {
        let csv = profiler.exportCSV()
        
        // Create a temporary file with timestamp
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        let fileName = "performance-\(timestamp).csv"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            // Write CSV to file
            try csv.write(to: tempURL, atomically: true, encoding: .utf8)
            
            // Create activity controller with file URL
            let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
            
            // Configure for iPad popover
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = scene.windows.first {
                
                if let popover = activityVC.popoverPresentationController {
                    popover.sourceView = window
                    popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
                    popover.permittedArrowDirections = []
                }
                
                // Find the top-most view controller
                var topController = window.rootViewController
                while let presented = topController?.presentedViewController {
                    topController = presented
                }
                
                topController?.present(activityVC, animated: true)
            }
        } catch {
            print("❌ Failed to export CSV: \(error.localizedDescription)")
        }
    }
    
    private func copyCSVToClipboard() {
        let csv = profiler.exportCSV()
        UIPasteboard.general.string = csv
        print("✅ CSV data copied to clipboard (\(profiler.metrics.count) metrics)")
        
        // Show a brief visual feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    private func shareJSON() {
        let jsonData = profiler.exportJSON()
        
        // Create a temporary file with timestamp
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        let fileName = "performance-\(timestamp).json"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            // Write JSON to file
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
            try jsonString.write(to: tempURL, atomically: true, encoding: .utf8)
            
            // Create activity controller with file URL
            let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
            
            // Configure for iPad popover
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = scene.windows.first {
                
                if let popover = activityVC.popoverPresentationController {
                    popover.sourceView = window
                    popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
                    popover.permittedArrowDirections = []
                }
                
                // Find the top-most view controller
                var topController = window.rootViewController
                while let presented = topController?.presentedViewController {
                    topController = presented
                }
                
                topController?.present(activityVC, animated: true)
            }
        } catch {
            print("❌ Failed to export JSON: \(error.localizedDescription)")
        }
    }
    
    private func shareSummaryReport() {
        let summary = profiler.exportSummaryReport()
        
        // Create a temporary file with timestamp
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        let fileName = "performance-summary-\(timestamp).txt"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            // Write summary to file
            try summary.write(to: tempURL, atomically: true, encoding: .utf8)
            
            // Create activity controller with file URL
            let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
            
            // Configure for iPad popover
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = scene.windows.first {
                
                if let popover = activityVC.popoverPresentationController {
                    popover.sourceView = window
                    popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
                    popover.permittedArrowDirections = []
                }
                
                // Find the top-most view controller
                var topController = window.rootViewController
                while let presented = topController?.presentedViewController {
                    topController = presented
                }
                
                topController?.present(activityVC, animated: true)
            }
        } catch {
            print("❌ Failed to export summary: \(error.localizedDescription)")
        }
    }
}

// MARK: - View Extension

extension View {
    /// Add performance monitoring overlay
    func performanceOverlay() -> some View {
        self.overlay(alignment: .top) {
            PerformanceProfilerOverlay()
        }
        .onAppear {
            PerformanceProfiler.shared.startMonitoring()
        }
        .onDisappear {
            PerformanceProfiler.shared.stopMonitoring()
        }
    }
}

// MARK: - UITextView Instrumentation

extension EditorCoordinator {
    /// Instrumented version of textViewDidChange for performance tracking
    func textViewDidChange_Instrumented(_ textView: UITextView) {
        let timer = PerformanceProfiler.shared.startOperation("textViewDidChange")
        defer { timer.stop() }
        
        // Your existing textViewDidChange logic
        captureUndoBurstStartIfNeeded()
        scheduleCommit()
        scheduleToolbarUpdate(for: textView)
    }
}
