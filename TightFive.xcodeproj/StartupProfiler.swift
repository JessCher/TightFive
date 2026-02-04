import Foundation
import SwiftUI
import SwiftData

/// Profiles app startup performance to identify bottlenecks
@MainActor
final class StartupProfiler {
    static let shared = StartupProfiler()
    
    private struct StartupMetric {
        let name: String
        let startTime: CFAbsoluteTime
        var endTime: CFAbsoluteTime?
        
        var duration: TimeInterval? {
            guard let endTime else { return nil }
            return endTime - startTime
        }
        
        var formattedDuration: String {
            guard let duration else { return "In Progress..." }
            return String(format: "%.2f ms", duration * 1000)
        }
    }
    
    private var metrics: [String: StartupMetric] = [:]
    private let appLaunchTime = CFAbsoluteTimeGetCurrent()
    
    private init() {
        print("📊 StartupProfiler initialized at T+0ms")
    }
    
    /// Start timing a startup operation
    func start(_ name: String) {
        let metric = StartupMetric(name: name, startTime: CFAbsoluteTimeGetCurrent(), endTime: nil)
        metrics[name] = metric
        
        let elapsed = (metric.startTime - appLaunchTime) * 1000
        print("📊 START: \(name) at T+\(String(format: "%.2f", elapsed))ms")
    }
    
    /// End timing a startup operation
    func end(_ name: String) {
        guard var metric = metrics[name] else {
            print("⚠️ END called for unknown metric: \(name)")
            return
        }
        
        metric.endTime = CFAbsoluteTimeGetCurrent()
        metrics[name] = metric
        
        if let duration = metric.duration {
            let elapsed = (metric.endTime! - appLaunchTime) * 1000
            print("📊 END: \(name) at T+\(String(format: "%.2f", elapsed))ms (took \(String(format: "%.2f", duration * 1000))ms)")
        }
    }
    
    /// Measure a synchronous operation
    func measure<T>(_ name: String, operation: () throws -> T) rethrows -> T {
        start(name)
        defer { end(name) }
        return try operation()
    }
    
    /// Measure an async operation
    func measureAsync<T>(_ name: String, operation: () async throws -> T) async rethrows -> T {
        start(name)
        defer { end(name) }
        return try await operation()
    }
    
    /// Print full startup report
    func printReport() {
        print("\n" + "=".repeating(60))
        print("📊 STARTUP PERFORMANCE REPORT")
        print("=".repeating(60))
        
        let sorted = metrics.values.sorted { ($0.endTime ?? .infinity) < ($1.endTime ?? .infinity) }
        
        var totalTime: TimeInterval = 0
        
        for metric in sorted {
            let status = metric.endTime == nil ? "⏳" : "✅"
            print("\(status) \(metric.name.padding(toLength: 40, withPad: " ", startingAt: 0)) \(metric.formattedDuration)")
            if let duration = metric.duration {
                totalTime += duration
            }
        }
        
        print("=".repeating(60))
        print("Total measured time: \(String(format: "%.2f", totalTime * 1000))ms")
        
        let timeSinceLaunch = (CFAbsoluteTimeGetCurrent() - appLaunchTime) * 1000
        print("Time since app launch: \(String(format: "%.2f", timeSinceLaunch))ms")
        print("=".repeating(60) + "\n")
    }
}

// MARK: - String Extension
private extension String {
    func repeating(_ count: Int) -> String {
        String(repeating: self, count: count)
    }
}

// MARK: - Instrumented App Entry Point

extension TightFiveApp {
    /// Call this in your app's init() to start profiling
    static func profileStartup() {
        StartupProfiler.shared.start("App Init")
    }
}

// MARK: - View Modifier for Startup Profiling

struct StartupProfilingModifier: ViewModifier {
    let checkpoint: String
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                StartupProfiler.shared.end(checkpoint)
            }
    }
}

extension View {
    /// Mark when a specific view appears during startup
    func startupCheckpoint(_ name: String) -> some View {
        modifier(StartupProfilingModifier(checkpoint: name))
    }
}
