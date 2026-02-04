/*
 
 ╔════════════════════════════════════════════════════════════════╗
 ║         PERFORMANCE MONITORING - QUICK REFERENCE               ║
 ╚════════════════════════════════════════════════════════════════╝
 
 ENABLE:
 Settings → Developer Tools → Toggle "Performance Overlay"
 
 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 
 📍 QUICK ACTIONS
 
 Track Sync Function:
 ┌────────────────────────────────────────────────────────────┐
 │ PerformanceMonitor.shared.trackFunction("Name") {          │
 │     // your code                                            │
 │ }                                                           │
 └────────────────────────────────────────────────────────────┘
 
 Track Async Function:
 ┌────────────────────────────────────────────────────────────┐
 │ try await PerformanceMonitor.shared                         │
 │     .trackAsyncFunction("Name") {                           │
 │         // your async code                                  │
 │     }                                                       │
 └────────────────────────────────────────────────────────────┘
 
 Track View:
 ┌────────────────────────────────────────────────────────────┐
 │ var body: some View {                                       │
 │     Content()                                               │
 │         .trackPerformance("ViewName")                       │
 │ }                                                           │
 └────────────────────────────────────────────────────────────┘
 
 Manual Tracking:
 ┌────────────────────────────────────────────────────────────┐
 │ PerformanceMonitor.shared.startTracking("Name")             │
 │ // your code                                                │
 │ PerformanceMonitor.shared.endTracking("Name")               │
 └────────────────────────────────────────────────────────────┘
 
 Log Event:
 ┌────────────────────────────────────────────────────────────┐
 │ PerformanceMonitor.shared.logEvent(                         │
 │     type: .dataOperation,                                   │
 │     name: "EventName"                                       │
 │ )                                                           │
 └────────────────────────────────────────────────────────────┘
 
 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 
 🎯 EVENT TYPES
 
 .functionExecution   → Function/method calls
 .viewAppearance      → SwiftUI views
 .dataOperation       → Database ops
 .networkRequest      → API calls
 .custom              → Custom events
 
 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 
 🚦 PERFORMANCE THRESHOLDS
 
 CPU:        🟢 <30%   🟡 30-60%   🔴 >60%
 Memory:     🟢 <200MB  🟡 200-400  🔴 >400
 FPS:        🟢 >50     🟡 30-50    🔴 <30
 Duration:   🟢 <0.1s   🟡 0.1-0.5  🔴 >0.5s
 
 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 
 📊 OVERLAY CONTROLS
 
 • TAP compact view → Expand
 • TAP collapse button → Minimize
 • DRAG anywhere → Reposition
 • Auto-snaps to left/right edge
 
 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 
 ✅ WHAT TO TRACK
 
 ✓ Data loading
 ✓ Complex views
 ✓ Image processing
 ✓ Network calls
 ✓ Batch operations
 ✓ Search/filter
 ✓ Export ops
 
 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 
 ❌ DON'T TRACK
 
 ✗ Simple getters/setters
 ✗ Basic UI updates
 ✗ Loop iterations (track whole loop)
 ✗ Every function (be selective)
 
 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 
 💡 NAMING TIPS
 
 GOOD:    "LoadBitsForSetlist_123"
          "ExportPDF_5bits"  
          "SearchBits_comedy"
 
 BAD:     "LoadData"
          "Process"
          "Function1"
 
 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 
 📤 EXPORT & ANALYZE
 
 1. Settings → Developer Tools
 2. Tap "Export Performance Data"
 3. Share CSV file
 4. Open in Excel/Numbers
 
 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 
 🔍 COMMON PATTERNS
 
 Database Query:
 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 try await PerformanceMonitor.shared
     .trackAsyncFunction("FetchBits") {
         return try await database.fetch()
     }
 
 
 View with Data Loading:
 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 struct MyView: View {
     var body: some View {
         Content()
             .trackAsyncPerformance("LoadMyViewData") {
                 await loadData()
             }
     }
 }
 
 
 Batch Operation:
 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 PerformanceMonitor.shared.trackFunction("BatchDelete_\(count)") {
     items.forEach { database.delete($0) }
 }
 
 
 Complex Computation:
 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 PerformanceMonitor.shared.startTracking("ComplexCalc")
 
 // Phase 1
 let intermediate = calculatePhase1()
 PerformanceMonitor.shared.logEvent(type: .custom, name: "Phase1Complete")
 
 // Phase 2
 let result = calculatePhase2(intermediate)
 PerformanceMonitor.shared.logEvent(type: .custom, name: "Phase2Complete")
 
 PerformanceMonitor.shared.endTracking("ComplexCalc")
 
 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 
 📝 FILES REFERENCE
 
 PerformanceMonitor.swift              → Core system
 PerformanceOverlay.swift              → UI overlay
 DeveloperToolsSettingsView.swift      → Settings UI
 PerformanceTrackingExtensions.swift   → API docs
 PerformanceMonitoringExamples.swift   → Examples
 PERFORMANCE_MONITORING_README.md      → Full docs
 
 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 
 🐛 TROUBLESHOOTING
 
 Overlay not showing?
 → Check Settings → Developer Tools → Toggle ON
 → Try toggling off/on
 → Restart app
 
 Metrics showing zero?
 → Wait a few seconds for initialization
 → Interact with the app
 
 Events not recording?
 → Verify function is actually called
 → Check for typos in tracking code
 → Add print statement to confirm execution
 
 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 
 🎓 PERFORMANCE BUDGETS
 
 View render:        < 0.05s
 Database query:     < 0.1s
 Image processing:   < 0.5s
 Network request:    < 2.0s
 Batch operation:    < 1.0s
 
 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 
 💾 SAVED PREFERENCES
 
 UserDefaults Key:             Value:
 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 performanceOverlayEnabled     Bool (overlay on/off)
 
 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 
 🔗 QUICK ACCESS
 
 Singleton:
 PerformanceMonitor.shared
 
 Properties:
 .isOverlayEnabled    → Toggle overlay
 .cpuUsage            → Current CPU %
 .memoryUsageMB       → Current memory
 .currentFPS          → Frame rate
 .batteryLevel        → Battery %
 .activeFunction      → Current operation
 .performanceEvents   → Event history
 
 Methods:
 .startMonitoring()
 .stopMonitoring()
 .trackFunction(_:execute:)
 .trackAsyncFunction(_:execute:)
 .startTracking(_:)
 .endTracking(_:)
 .logEvent(type:name:duration:)
 .clearEvents()
 .exportPerformanceData()
 
 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 
 📊 CSV EXPORT FORMAT
 
 Timestamp             → ISO8601
 Type                  → Event type
 Name                  → Operation name
 Duration (s)          → Execution time
 CPU (%)               → CPU usage
 Memory (MB)           → Memory usage
 Battery (%)           → Battery level
 FPS                   → Frame rate
 
 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 
 ⚡️ PERFORMANCE IMPACT OF MONITORING
 
 CPU overhead:      ~0.1-0.5%
 Memory footprint:  ~1-2 MB
 FPS impact:        Negligible
 Battery impact:    Minimal (<1% over 1 hour)
 
 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 
 ⭐️ PRO TIPS
 
 1. Keep overlay enabled during development
 2. Export data before/after optimizations
 3. Track critical paths first
 4. Use descriptive, searchable names
 5. Review events regularly
 6. Share exports with team
 7. Set performance budgets
 8. Don't over-track (be selective)
 
 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 
 📚 MORE INFO
 
 See PERFORMANCE_MONITORING_README.md for:
 • Detailed integration guide
 • Architecture details
 • Advanced patterns
 • Best practices
 • Troubleshooting
 
 See PerformanceMonitoringExamples.swift for:
 • Real-world integration examples
 • Platform-specific patterns
 • Complex tracking scenarios
 
 ╔════════════════════════════════════════════════════════════════╗
 ║  Questions? Check the examples file or README for details.     ║
 ╚════════════════════════════════════════════════════════════════╝
 
 */

import Foundation

// This file is intentionally comment-only for quick reference.
// Import it anywhere you need a quick reminder of the API.
