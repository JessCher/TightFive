import SwiftUI

/// Performance tracking extensions for SwiftUI views
extension View {
    /// Track when this view appears with performance monitoring
    /// - Parameter name: Name of the view to track
    func trackPerformance(_ name: String) -> some View {
        self.onAppear {
            PerformanceMonitor.shared.logEvent(
                type: .viewAppearance,
                name: name
            )
        }
    }
    
    /// Track a timed operation when this view appears
    /// - Parameters:
    ///   - name: Name of the operation
    ///   - operation: Async operation to track
    func trackAsyncPerformance(_ name: String, operation: @escaping () async -> Void) -> some View {
        self.task {
            let startTime = CFAbsoluteTimeGetCurrent()
            PerformanceMonitor.shared.startTracking(name)
            
            await operation()
            
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            PerformanceMonitor.shared.endTracking(name)
            
            PerformanceMonitor.shared.logEvent(
                type: .viewAppearance,
                name: name,
                duration: duration
            )
        }
    }
}

// MARK: - Performance Tracking Examples

/*
 
 # Performance Monitoring API Usage Guide
 
 ## Overview
 The PerformanceMonitor tracks CPU usage, memory consumption, FPS, and battery drain
 across your app. Use it to identify performance bottlenecks and optimize critical paths.
 
 ## Basic Usage
 
 ### 1. Enable the Overlay
 Go to Settings → Developer Tools and toggle "Performance Overlay" on.
 The overlay will appear in the top corner showing real-time metrics.
 
 ### 2. Track Synchronous Functions
 
 ```swift
 PerformanceMonitor.shared.trackFunction("LoadBitsFromDatabase") {
     // Your synchronous code here
     let bits = database.fetchAllBits()
     processBits(bits)
 }
 ```
 
 ### 3. Track Async Functions
 
 ```swift
 try await PerformanceMonitor.shared.trackAsyncFunction("FetchFromAPI") {
     let data = try await api.fetchData()
     await processData(data)
 }
 ```
 
 ### 4. Manual Tracking (Start/End)
 
 ```swift
 PerformanceMonitor.shared.startTracking("ComplexOperation")
 
 // Your code here
 performComplexCalculation()
 
 PerformanceMonitor.shared.endTracking("ComplexOperation")
 ```
 
 ### 5. Track View Appearances
 
 ```swift
 struct MyView: View {
     var body: some View {
         VStack {
             // Your view code
         }
         .trackPerformance("MyView")
     }
 }
 ```
 
 ### 6. Track Async View Operations
 
 ```swift
 struct MyView: View {
     var body: some View {
         VStack {
             // Your view code
         }
         .trackAsyncPerformance("LoadMyViewData") {
             await loadData()
         }
     }
 }
 ```
 
 ### 7. Log Custom Events
 
 ```swift
 PerformanceMonitor.shared.logEvent(
     type: .dataOperation,
     name: "SaveBitToDatabase",
     duration: 0.123,
     cpuUsage: nil,  // Will use current value
     memoryUsage: nil // Will use current value
 )
 ```
 
 ## Event Types
 
 - `.functionExecution` - General function/method execution
 - `.viewAppearance` - SwiftUI view lifecycle events
 - `.dataOperation` - Database or data processing operations
 - `.networkRequest` - Network/API calls
 - `.custom` - Custom events for your specific needs
 
 ## Performance Overlay
 
 ### Compact Mode (Default)
 - Shows CPU, Memory, and FPS in a small widget
 - Tap to expand for detailed view
 - Drag to reposition anywhere on screen
 
 ### Expanded Mode
 - Shows all metrics with progress bars
 - Color-coded indicators (green/yellow/red)
 - Current active function display
 - Tap the collapse button to minimize
 
 ## Analyzing Results
 
 ### In-App
 - Go to Settings → Developer Tools
 - View real-time metrics and historical events
 - See duration, CPU, and memory for each tracked operation
 
 ### Export for Analysis
 - Tap "Export Performance Data" in Developer Tools
 - Share/save the CSV file
 - Analyze in Excel, Numbers, or your preferred tool
 
 ## Performance Thresholds
 
 ### CPU Usage
 - Green: < 30% (Excellent)
 - Yellow: 30-60% (Moderate)
 - Red: > 60% (High - Optimize!)
 
 ### Memory Usage
 - Green: < 200 MB (Excellent)
 - Yellow: 200-400 MB (Moderate)
 - Red: > 400 MB (High - Check for leaks!)
 
 ### Frame Rate (FPS)
 - Green: > 50 FPS (Smooth)
 - Yellow: 30-50 FPS (Acceptable)
 - Red: < 30 FPS (Choppy - Optimize rendering!)
 
 ### Function Duration
 - Green: < 0.1s (Fast)
 - Yellow: 0.1-0.5s (Moderate)
 - Red: > 0.5s (Slow - Consider async or optimization)
 
 ## Best Practices
 
 1. **Track Critical Paths**: Focus on user-facing operations like:
    - Loading data
    - Rendering complex views
    - Processing user input
    - Network requests
 
 2. **Use Meaningful Names**: Make tracking names descriptive:
    ✅ "LoadBitsForSetlist_123"
    ❌ "LoadData"
 
 3. **Don't Over-Track**: Tracking has minimal overhead, but don't track:
    - Simple property getters/setters
    - Basic UI updates
    - Loops with many iterations (track the whole loop instead)
 
 4. **Regular Monitoring**: 
    - Run with overlay enabled during development
    - Export and analyze data after major features
    - Compare before/after optimization attempts
 
 5. **Team Collaboration**:
    - Share exported CSV files with your team
    - Set performance budgets for critical operations
    - Review performance metrics in code reviews
 
 ## Example Integration
 
 ```swift
 struct BitsTabView: View {
     @State private var bits: [Bit] = []
     @State private var isLoading = false
     
     var body: some View {
         List(bits) { bit in
             BitRow(bit: bit)
         }
         .trackAsyncPerformance("LoadBitsView") {
             await loadBits()
         }
     }
     
     func loadBits() async {
         try? await PerformanceMonitor.shared.trackAsyncFunction("FetchBitsFromDatabase") {
             bits = await database.fetchAllBits()
         }
     }
 }
 ```
 
 ## Troubleshooting
 
 ### Overlay Not Appearing
 1. Check that it's enabled in Settings → Developer Tools
 2. Ensure you're on a debug build
 3. Try toggling it off and on again
 
 ### Metrics Show Zero
 - The monitor starts when enabled
 - Give it a few seconds to initialize
 - Interact with the app to generate activity
 
 ### Events Not Recording
 - Verify you're calling the tracking methods correctly
 - Check that the function name doesn't contain special characters
 - Make sure the operation is actually executing
 
 */
