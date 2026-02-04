

/*
 
 PERFORMANCE MONITORING INTEGRATION EXAMPLES
 
 This file demonstrates how to integrate performance monitoring into your existing views
 and functions. Copy and adapt these patterns to track performance across your app.
 
 */

// MARK: - How to Apply to Your Code

/*
 
 QUICK INTEGRATION GUIDE
 ========================
 
 EXAMPLE 1: Track a View
 ------------------------
 struct BitsView: View {
     var body: some View {
         List { ... }
             .trackPerformance("BitsView")
     }
 }
 
 
 EXAMPLE 2: Track Async View Loading
 ------------------------------------
 struct SetlistView: View {
     var body: some View {
         Content()
             .trackAsyncPerformance("LoadSetlist") {
                 await loadData()
             }
     }
 }
 
 
 EXAMPLE 3: Track Synchronous Function
 --------------------------------------
 func saveBit(_ bit: Bit) {
     PerformanceMonitor.shared.trackFunction("SaveBit") {
         database.save(bit)
     }
 }
 
 
 EXAMPLE 4: Track Async Function
 --------------------------------
 func fetchBits() async throws -> [Bit] {
     try await PerformanceMonitor.shared.trackAsyncFunction("FetchBits") {
         return try await database.fetch()
     }
 }
 
 
 EXAMPLE 5: Manual Start/End Tracking
 -------------------------------------
 func complexOperation() {
     PerformanceMonitor.shared.startTracking("ComplexOp")
     
     // Your code here
     doWork()
     
     PerformanceMonitor.shared.endTracking("ComplexOp")
 }
 
 
 EXAMPLE 6: Log Custom Event
 ----------------------------
 PerformanceMonitor.shared.logEvent(
     type: .dataOperation,
     name: "MigrationComplete"
 )
 
 
 PRIORITY AREAS TO TRACK:
 -------------------------
 ✅ Data loading (SwiftData queries)
 ✅ View appearances (especially complex views)
 ✅ Image processing/rendering
 ✅ Export operations (PDF, images)
 ✅ Network requests
 ✅ Batch operations
 ✅ Search/filter operations
 ✅ Animation-heavy views
 
 */
