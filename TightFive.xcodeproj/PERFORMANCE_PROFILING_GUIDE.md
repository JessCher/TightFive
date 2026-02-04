# Performance Profiling & Optimization Guide

## 🎯 Quick Start

### 1. Enable Performance Monitoring

The app now has a built-in performance overlay! When you run the app:

1. Look for a small FPS badge in the top-right corner
2. Tap it to expand and see detailed metrics
3. Watch for:
   - **FPS** (should be 60, acceptable is 30-60, bad is <30)
   - **CPU usage** (should be <50%, concerning if >100%)
   - **Memory usage** (track if it keeps growing)
   - **Recent slow operations** (highlighted in orange/red)

### 2. Check Startup Performance

On app launch, check your Xcode console for the **Startup Performance Report**. It will show you exactly which parts of app initialization are slow:

```
📊 STARTUP PERFORMANCE REPORT
============================================================
✅ App Init                                          45.23 ms
✅ Apply System Appearance                           12.45 ms
✅ Configure Global Appearance                       8.76 ms
✅ ModelContainer Creation                           234.56 ms  ⚠️ SLOW!
✅ ContentView onAppear - configureGlobalAppearance  3.21 ms
✅ ContentView Appeared                              0.45 ms
============================================================
Total measured time: 304.66 ms
Time since app launch: 456.78 ms
============================================================
```

## 🔍 What We've Instrumented

### App Launch
- `TightFiveApp.init()` - Measures overall app initialization
- System appearance setup
- Global font configuration
- **ModelContainer creation** (likely the biggest bottleneck with CloudKit)

### Widget Integration
- Theme sync to widget
- Processing pending bits from widget

### Text Editing
- You can add profiling to `RichTextEditor` by wrapping operations in:
  ```swift
  PerformanceProfiler.shared.measureSync("Operation Name") {
      // your code
  }
  ```

## 🐛 Known Performance Issues

### 1. CloudKit ModelContainer (MAJOR)
**Symptom**: App takes 200-500ms+ to launch
**Location**: `TightFiveApp.swift` - `sharedModelContainer`
**Cause**: CloudKit initialization is synchronous and can be slow, especially:
- First launch
- When network is slow
- When iCloud is syncing

**Solutions**:
- ✅ Already profiled - check console to confirm this is the issue
- ⚡️ Consider lazy initialization (create container after UI appears)
- ⚡️ Add loading screen during first launch
- ⚡️ Consider `.private` database instead of `.automatic` if you don't need shared data

### 2. Text Editing CPU Usage (MAJOR)
**Symptom**: 130% CPU while typing, 30 FPS app-wide
**Location**: `RichTextEditor.swift`
**Likely Causes**:
1. **RTF serialization on every keystroke** (debounced to 750ms but still heavy)
2. **Toolbar updates with list mode detection** (debounced to 200ms, uses regex)
3. **Undo manager notifications** (fires multiple times per keystroke)
4. **Background re-rendering** (Canvas with thousands of particles)

**Already Optimized**:
- ✅ Commit timer increased to 750ms
- ✅ Toolbar updates debounced to 200ms
- ✅ List mode caching (avoids regex on repeat)
- ✅ Background uses `.drawingGroup()` and `.allowsHitTesting(false)`

**Next Steps to Try**:
1. **Profile with the overlay** - Type in a text field and watch which operations appear as "slow"
2. **Test without background** - Temporarily disable `DynamicChalkboardBackground` to see if that's the issue
3. **Reduce RTF serialization** - Consider only serializing on focus loss, not on timer
4. **Simplify undo** - Current implementation may be too eager

### 3. CFPreferences Warning (MINOR)
**Symptom**: Console warning about `kCFPreferencesAnyUser`
**Cause**: iOS system bug, not your code
**Impact**: Possibly adds 10-50ms to app launch
**Solution**: Can't fix - it's an Apple bug. Ignore it.

## 🚀 Performance Optimization Checklist

### Quick Wins (Do First)
- [x] Add performance profiling
- [x] Instrument startup
- [x] Optimize DynamicChalkboardBackground with `.allowsHitTesting(false)`
- [ ] **Test typing performance** - Use the overlay to identify the exact bottleneck
- [ ] **Export metrics CSV** - Tap share button in overlay, analyze in spreadsheet

### Medium Effort
- [ ] Lazy-load ModelContainer (create after first view appears)
- [ ] Add loading screen for first launch
- [ ] Consider reducing background particle count (dust/clouds) during text editing
- [ ] Reduce RTF serialization frequency (only on focus loss?)
- [ ] Profile list mode detection regex - may need optimization

### Advanced
- [ ] Consider replacing RTF with lighter format for undo history
- [ ] Investigate moving text editor to Metal-backed rendering
- [ ] Profile memory allocations with Instruments
- [ ] Add performance budgets (alerts when operations exceed thresholds)

## 📊 How to Use the Profiling Tools

### Real-Time Overlay
```swift
// Already added to your ContentView
.performanceOverlay()
```

This shows:
- Live FPS counter
- CPU usage percentage
- Memory usage
- Active operations (what's running right now)
- Recent slow operations with color coding:
  - 🟢 Green: <16ms (good, less than 1 frame)
  - 🟡 Yellow: 16-100ms (attention needed)
  - 🟠 Orange: 100-500ms (warning)
  - 🔴 Red: >500ms (critical)

### Manual Profiling
```swift
// For synchronous operations
PerformanceProfiler.shared.measureSync("My Operation") {
    // Your code here
}

// For async operations
await PerformanceProfiler.shared.measureAsync("My Async Operation") {
    // Your async code here
}

// For delegate methods (start/stop timing)
let timer = PerformanceProfiler.shared.startOperation("My Operation")
// ... do work ...
timer.stop()
```

### Export Data
Tap the share button in the performance overlay to export a CSV with:
- Timestamp
- Operation name
- Duration (seconds and milliseconds)
- CPU before/after (and delta)
- Memory before/after (and delta)
- Severity level

Analyze this in Numbers or Excel to find patterns!

## 🎬 Next Steps

1. **Run the app and watch the console** for the startup report
2. **Navigate to a text editing screen** and watch the FPS badge
3. **Start typing** and see if FPS drops or CPU spikes
4. **Tap the FPS badge** to see which operations are slow
5. **Export the CSV** after a typing session to analyze

### Expected Results

**Good Performance**:
- FPS: 55-60
- CPU while typing: 30-50%
- Startup: <300ms
- No operations >100ms in the overlay

**Current (Based on your description)**:
- FPS: 30 (BAD - should be 60)
- CPU while typing: 130% (BAD - way too high)
- Startup: Slow (need to measure)

The profiling tools will tell us EXACTLY what's causing the slowdowns!

## 🔧 Emergency Performance Mode

If you need to ship and performance is still bad, consider adding a "Performance Mode" setting that:
- Reduces background particles to 25% of current
- Disables real-time toolbar updates (update only on selection change)
- Increases RTF commit delay to 2 seconds
- Disables blend modes on background

This can easily gain you 20-30 FPS and reduce CPU by 50%.

---

**Remember**: Profile first, optimize second! The tools are now in place. Run the app, gather data, then we can target the exact bottlenecks.
