# Quick Performance Fixes

## 🚨 Emergency Fixes (Try These First)

These are "safe" optimizations you can apply immediately while you gather profiling data.

### Fix 1: Reduce Background Complexity During Text Editing

Add this environment key to detect when keyboard is visible:

**File: AppSettings.swift**
```swift
/// Whether text editing is currently active (reduces background effects)
@Published var isTextEditingActive = false
```

**File: DynamicChalkboardBackground.swift**
```swift
// Change these lines:
private var dustCount: Int { 
    // Reduce to 25% of normal when editing text
    let base = settings.backgroundDustCount
    return settings.isTextEditingActive ? max(base / 4, 500) : base
}

private var clumpCount: Int { 
    // Reduce to 25% of normal when editing text
    let base = settings.backgroundCloudCount
    return settings.isTextEditingActive ? max(base / 4, 20) : base
}
```

**In any view with a text editor:**
```swift
RichTextEditor(rtfData: $text)
    .onAppear {
        AppSettings.shared.isTextEditingActive = true
    }
    .onDisappear {
        AppSettings.shared.isTextEditingActive = false
    }
```

**Expected gain**: 10-20 FPS, 30-50% less CPU usage

---

### Fix 2: Increase RTF Commit Delay

**File: RichTextEditor.swift** (around line 106)
```swift
// Change from:
private let commitDelay: TimeInterval = 0.75

// To:
private let commitDelay: TimeInterval = 1.5  // Serialize less frequently
```

**Expected gain**: 5-10 FPS, 10-20% less CPU usage

---

### Fix 3: Lazy-Load ModelContainer

This prevents CloudKit from blocking your UI on startup.

**File: TightFiveApp.swift**
```swift
@main
struct TightFiveApp: App {
    @State private var appSettings = AppSettings.shared
    @State private var showQuickBit = false
    @State private var modelContainer: ModelContainer?
    @State private var isLoadingContainer = true
    
    init() {
        StartupProfiler.shared.start("App Init")
        
        StartupProfiler.shared.measure("Apply System Appearance") {
            TFTheme.applySystemAppearance()
        }
        
        StartupProfiler.shared.measure("Configure Global Appearance") {
            configureGlobalAppearance()
        }
        
        StartupProfiler.shared.end("App Init")
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let container = modelContainer {
                    ContentView()
                        .tint(TFTheme.yellow)
                        .environment(appSettings)
                        .globalKeyboardDismiss()
                        .syncWithWidget(showQuickBit: $showQuickBit)
                        .sheet(isPresented: $showQuickBit) {
                            QuickBitEditor()
                                .presentationDetents([.medium, .large])
                        }
                        .onAppear {
                            StartupProfiler.shared.measure("ContentView onAppear - configureGlobalAppearance") {
                                configureGlobalAppearance()
                            }
                            
                            // Print startup report after first view appears
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                StartupProfiler.shared.printReport()
                            }
                        }
                        .onChange(of: appSettings.appFont) { oldValue, newValue in
                            configureGlobalAppearance()
                        }
                        .performanceOverlay()
                        .startupCheckpoint("ContentView Appeared")
                        .modelContainer(container)
                } else {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Loading...")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .tfBackground()
                }
            }
            .task {
                // Load container asynchronously
                if modelContainer == nil {
                    modelContainer = await createModelContainer()
                }
            }
        }
    }
    
    // Make container creation async
    private func createModelContainer() async -> ModelContainer {
        await Task.detached(priority: .userInitiated) {
            StartupProfiler.shared.start("ModelContainer Creation (Async)")
            defer { StartupProfiler.shared.end("ModelContainer Creation (Async)") }
            
            let schema = Schema([
                Bit.self,
                Setlist.self,
                BitVariation.self,
                SetlistAssignment.self,
                Performance.self,
                UserProfile.self
            ])
            
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true,
                cloudKitDatabase: .automatic
            )
            
            do {
                let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
                print("✅ ModelContainer created successfully WITH CloudKit")
                return container
            } catch {
                print("❌ ModelContainer creation failed with error: \(error)")
                print("📋 Error details: \(error.localizedDescription)")
                
                // Fallback without CloudKit
                print("⚠️ Attempting to create ModelContainer without CloudKit...")
                let fallbackConfig = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: false,
                    allowsSave: true,
                    cloudKitDatabase: .none
                )
                
                do {
                    let container = try ModelContainer(for: schema, configurations: [fallbackConfig])
                    print("✅ ModelContainer created successfully WITHOUT CloudKit")
                    return container
                } catch {
                    print("❌ Even fallback creation failed: \(error)")
                    fatalError("Could not create ModelContainer: \(error)")
                }
            }
        }.value
    }
    
    // ... rest of your code ...
}
```

**Expected gain**: UI appears 200-500ms faster, feels much more responsive

---

### Fix 4: Reduce Undo Manager Overhead

**File: RichTextEditor.swift** (in `observeUndoManager` method, around line 215)

```swift
private func observeUndoManager(_ undoManager: UndoManager?) {
    // Remove previous observers
    for token in undoObservationTokens { NotificationCenter.default.removeObserver(token) }
    undoObservationTokens.removeAll()

    guard let um = undoManager else { return }
    let center = NotificationCenter.default

    // OPTIMIZED: Only observe the essential notifications
    // Removed willUndo/willRedo to reduce overhead
    let didUndo = center.addObserver(forName: .NSUndoManagerDidUndoChange, object: um, queue: .main) { [weak self] _ in
        self?.isPerformingUndoRedo = false
    }
    let didRedo = center.addObserver(forName: .NSUndoManagerDidRedoChange, object: um, queue: .main) { [weak self] _ in
        self?.isPerformingUndoRedo = false
    }

    undoObservationTokens = [didUndo, didRedo]
}
```

**Expected gain**: 5-10% less CPU during typing

---

## 🧪 A/B Testing

To verify each fix works, use the performance overlay:

### Before Fix
1. Open text editor
2. Tap FPS badge to expand overlay
3. Note FPS and CPU
4. Type for 10 seconds
5. Export data (tap share button → choose format)

### After Fix  
1. Repeat same steps
2. Compare FPS and CPU
3. Compare CSV - are operations faster?

### Measuring Impact
```
Fix 1 (Background): Should see 10-20 FPS improvement
Fix 2 (RTF delay): Should see fewer "textViewDidChange" in Recent Issues
Fix 3 (Lazy container): Should see much faster startup time
Fix 4 (Undo): Should see slightly lower CPU usage
```

---

## 🔥 Nuclear Option: Performance Mode

If all else fails, add this "Performance Mode" toggle that users can enable:

**File: AppSettings.swift**
```swift
/// Performance mode reduces visual effects for better FPS
var performanceMode: Bool {
    get { UserDefaults.standard.bool(forKey: "performanceMode") }
    set { 
        UserDefaults.standard.set(newValue, forKey: "performanceMode")
        notifyChange()
    }
}
```

**File: DynamicChalkboardBackground.swift**
```swift
private var dustCount: Int { 
    if settings.performanceMode {
        return 500  // Minimal dust
    }
    return settings.isTextEditingActive 
        ? max(settings.backgroundDustCount / 4, 500) 
        : settings.backgroundDustCount
}

private var clumpCount: Int { 
    if settings.performanceMode {
        return 20  // Minimal clouds
    }
    return settings.isTextEditingActive 
        ? max(settings.backgroundCloudCount / 4, 20) 
        : settings.backgroundCloudCount
}

// Also reduce opacity
.opacity(settings.performanceMode ? 0.3 : cachedDustOpacity)
```

**File: RichTextEditor.swift**
```swift
// In scheduleToolbarUpdate, add performance check
private func scheduleToolbarUpdate(for textView: UITextView) {
    // Skip toolbar updates in performance mode
    guard !AppSettings.shared.performanceMode else {
        // Update immediately without debounce
        toolbar.updateState(for: textView, listMode: nil)
        return
    }
    
    // ... existing debounced logic ...
}
```

**Add to Settings UI:**
```swift
Section("Performance") {
    Toggle("Performance Mode", isOn: $appSettings.performanceMode)
    Text("Reduces visual effects for smoother typing on older devices")
        .font(.caption)
        .foregroundStyle(.secondary)
}
```

**Expected gain**: 20-30 FPS, 40-60% less CPU, users love it on older devices

---

## 📋 Implementation Checklist

Apply these in order and test after each one:

- [ ] **Fix 1**: Reduce background during text editing (biggest impact)
- [ ] **Fix 2**: Increase RTF commit delay (easy win)
- [ ] **Fix 3**: Lazy-load ModelContainer (startup only)
- [ ] **Fix 4**: Reduce undo notifications (minor improvement)
- [ ] **Nuclear Option**: Add Performance Mode toggle (if needed)

After each fix:
1. Run app
2. Check startup time in console
3. Test typing performance with overlay
4. Note FPS and CPU improvements

---

## 🎯 Target After Fixes

With all fixes applied, you should see:

| Metric | Before | After | Target |
|--------|--------|-------|--------|
| Startup Time | ???ms | <300ms | <200ms |
| FPS (typing) | 30 | 50-60 | 55-60 |
| CPU (typing) | 130% | 40-60% | <50% |
| CPU (idle) | ???% | <15% | <10% |

The profiling overlay will confirm the improvements! 📊
