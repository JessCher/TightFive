import Foundation
import SwiftUI
import Combine

/// Performance monitoring system for development and debugging
@Observable
class PerformanceMonitor {
    static let shared = PerformanceMonitor()
    
    // MARK: - Published Properties
    
    /// Whether the performance overlay is enabled
    var isOverlayEnabled: Bool = UserDefaults.standard.bool(forKey: "performanceOverlayEnabled") {
        didSet {
            UserDefaults.standard.set(isOverlayEnabled, forKey: "performanceOverlayEnabled")
            if isOverlayEnabled {
                startMonitoring()
            } else {
                stopMonitoring()
            }
        }
    }
    
    /// Current CPU usage percentage (0-100)
    var cpuUsage: Double = 0.0
    
    /// Current memory usage in MB
    var memoryUsageMB: Double = 0.0
    
    /// Current battery level (0-100)
    var batteryLevel: Double = 100.0
    
    /// Current battery state
    var batteryState: UIDevice.BatteryState = .unknown
    
    /// Current thermal state
    var thermalState: ProcessInfo.ThermalState = .nominal
    
    /// Frame rate (FPS)
    var currentFPS: Double = 60.0
    
    /// Active function/view tracker
    var activeFunction: String = "Idle"
    
    /// Performance events log
    var performanceEvents: [PerformanceEvent] = []
    
    /// Maximum number of events to keep in memory
    private let maxEvents = 100
    
    // MARK: - Private Properties
    
    private var timer: Timer?
    private var displayLink: CADisplayLink?
    private var frameCount: Int = 0
    private var lastTimestamp: CFTimeInterval = 0
    
    private init() {
        // Enable battery monitoring (lightweight)
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        // DO NOT start monitoring automatically - let the user explicitly enable it
        // This prevents performance impact on every app launch
        // Monitoring will start only when isOverlayEnabled is set to true
    }
    
    // MARK: - Public Methods
    
    /// Start monitoring performance metrics
    func startMonitoring() {
        stopMonitoring() // Stop any existing monitoring
        
        // Update metrics every 1.0 seconds (reduced from 0.1s to save 90% CPU!)
        // This is still responsive enough for a performance overlay
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateMetrics()
        }
        
        // Setup display link for FPS monitoring
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkCallback))
        // Use .default mode instead of .common to reduce interference with scrolling/gestures
        displayLink?.add(to: .main, forMode: .default)
        // Reduce FPS monitoring to 30fps instead of 60fps to save CPU
        if #available(iOS 15.0, *) {
            displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 30, preferred: 30)
        }
        
        // Listen for thermal state changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(thermalStateChanged),
            name: ProcessInfo.thermalStateDidChangeNotification,
            object: nil
        )
        
        // Initial thermal state
        thermalState = ProcessInfo.processInfo.thermalState
    }
    
    /// Stop monitoring performance metrics
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        displayLink?.invalidate()
        displayLink = nil
        NotificationCenter.default.removeObserver(self, name: ProcessInfo.thermalStateDidChangeNotification, object: nil)
    }
    
    /// Track a function execution
    func trackFunction(_ name: String, execute: () -> Void) {
        let startTime = CFAbsoluteTimeGetCurrent()
        activeFunction = name
        
        execute()
        
        let executionTime = CFAbsoluteTimeGetCurrent() - startTime
        activeFunction = "Idle"
        
        logEvent(
            type: .functionExecution,
            name: name,
            duration: executionTime,
            cpuUsage: cpuUsage,
            memoryUsage: memoryUsageMB
        )
    }
    
    /// Track an async function execution
    func trackAsyncFunction(_ name: String, execute: @escaping () async throws -> Void) async throws {
        let startTime = CFAbsoluteTimeGetCurrent()
        activeFunction = name
        
        try await execute()
        
        let executionTime = CFAbsoluteTimeGetCurrent() - startTime
        activeFunction = "Idle"
        
        logEvent(
            type: .functionExecution,
            name: name,
            duration: executionTime,
            cpuUsage: cpuUsage,
            memoryUsage: memoryUsageMB
        )
    }
    
    /// Mark the start of a tracked operation
    func startTracking(_ name: String) {
        activeFunction = name
    }
    
    /// Mark the end of a tracked operation
    func endTracking(_ name: String) {
        if activeFunction == name {
            activeFunction = "Idle"
        }
    }
    
    /// Log a custom performance event
    func logEvent(type: PerformanceEventType, name: String, duration: TimeInterval? = nil, cpuUsage: Double? = nil, memoryUsage: Double? = nil) {
        let event = PerformanceEvent(
            timestamp: Date(),
            type: type,
            name: name,
            duration: duration,
            cpuUsage: cpuUsage ?? self.cpuUsage,
            memoryUsage: memoryUsage ?? self.memoryUsageMB,
            batteryLevel: batteryLevel
        )
        
        performanceEvents.append(event)
        
        // Keep only the last N events
        if performanceEvents.count > maxEvents {
            performanceEvents.removeFirst(performanceEvents.count - maxEvents)
        }
    }
    
    /// Clear all performance events
    func clearEvents() {
        performanceEvents.removeAll()
    }
    
    /// Export performance data as CSV
    func exportPerformanceData() -> String {
        var csv = "Timestamp,Type,Name,Duration (s),CPU (%),Memory (MB),Battery (%),FPS\n"
        
        for event in performanceEvents {
            csv += "\(event.timestamp.ISO8601Format()),"
            csv += "\(event.type.rawValue),"
            csv += "\"\(event.name)\","
            csv += "\(event.duration?.formatted() ?? "N/A"),"
            csv += "\(String(format: "%.2f", event.cpuUsage)),"
            csv += "\(String(format: "%.2f", event.memoryUsage)),"
            csv += "\(String(format: "%.2f", event.batteryLevel)),"
            csv += "\(String(format: "%.1f", currentFPS))\n"
        }
        
        return csv
    }
    
    // MARK: - Private Methods
    
    @objc private func thermalStateChanged() {
        thermalState = ProcessInfo.processInfo.thermalState
    }
    
    @objc private func displayLinkCallback() {
        guard let displayLink = displayLink else { return }
        
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
    
    private func updateMetrics() {
        cpuUsage = getCPUUsage()
        memoryUsageMB = getMemoryUsage()
        batteryLevel = Double(UIDevice.current.batteryLevel * 100)
        batteryState = UIDevice.current.batteryState
        thermalState = ProcessInfo.processInfo.thermalState
    }
    
    private func getCPUUsage() -> Double {
        var totalUsageOfCPU: Double = 0.0
        var threadsList: thread_act_array_t?
        var threadsCount = mach_msg_type_number_t(0)
        let threadsResult = withUnsafeMutablePointer(to: &threadsList) {
            task_threads(mach_task_self_, $0, &threadsCount)
        }
        
        if threadsResult == KERN_SUCCESS, let threadsList = threadsList {
            for index in 0..<threadsCount {
                var threadInfo = thread_basic_info()
                var threadInfoCount = mach_msg_type_number_t(THREAD_INFO_MAX)
                let infoResult = withUnsafeMutablePointer(to: &threadInfo) {
                    $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                        thread_info(threadsList[Int(index)], thread_flavor_t(THREAD_BASIC_INFO), $0, &threadInfoCount)
                    }
                }
                
                guard infoResult == KERN_SUCCESS else {
                    continue
                }
                
                let threadBasicInfo = threadInfo as thread_basic_info
                if threadBasicInfo.flags & TH_FLAGS_IDLE == 0 {
                    totalUsageOfCPU = totalUsageOfCPU + (Double(threadBasicInfo.cpu_usage) / Double(TH_USAGE_SCALE)) * 100.0
                }
            }
            vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: threadsList)), vm_size_t(Int(threadsCount) * MemoryLayout<thread_t>.stride))
        }
        
        return totalUsageOfCPU
    }
    
    private func getMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / 1024.0 / 1024.0 // Convert to MB
        }
        
        return 0.0
    }
}

// MARK: - Performance Event

struct PerformanceEvent: Identifiable {
    let id = UUID()
    let timestamp: Date
    let type: PerformanceEventType
    let name: String
    let duration: TimeInterval?
    let cpuUsage: Double
    let memoryUsage: Double
    let batteryLevel: Double
}

enum PerformanceEventType: String, CaseIterable {
    case functionExecution = "Function"
    case viewAppearance = "View"
    case dataOperation = "Data"
    case networkRequest = "Network"
    case custom = "Custom"
}

// MARK: - Performance Metric Type

enum PerformanceMetricType: String, CaseIterable, Identifiable {
    case cpu = "CPU"
    case memory = "Memory"
    case battery = "Battery"
    case fps = "FPS"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .cpu: return "cpu"
        case .memory: return "memorychip"
        case .battery: return "battery.100"
        case .fps: return "speedometer"
        }
    }
}
