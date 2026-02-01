# Cue Card Mode Integration Guide

## Quick Start

You now have a complete cue card implementation ready to integrate into your app. Here's how to wire it up.

## Option 1: Replace Existing Stage Mode (Recommended)

This is the cleanest approach - simply swap the old teleprompter for the new cue card system.

### Step 1: Rename Old Implementation (Backup)

```swift
// Rename existing files for backup:
StageModeView.swift → StageModeViewTeleprompter.swift
StageTeleprompterEngine.swift → (keep as-is, not used by default)
```

### Step 2: Rename New Implementation

```swift
// Make cue card mode the default:
StageModeViewCueCard.swift → StageModeView.swift
CueCardEngine.swift → (keep name as-is)
```

### Step 3: Update Navigation

No changes needed! Any existing navigation to `StageModeView` will now use the cue card version.

```swift
// Existing code continues to work:
NavigationLink {
    StageModeView(setlist: mySetlist, venue: "Comedy Club")
}
```

## Option 2: Add Mode Selector (Advanced)

Keep both modes and let users choose via settings.

### Step 1: Add Setting Enum

In `RunModeSettingsStore.swift`:

```swift
enum StageModeType: String, CaseIterable, Identifiable {
    case teleprompter = "Teleprompter"
    case cueCard = "Cue Card"
    var id: String { rawValue }
}

// Add to RunModeSettingsStore:
@AppStorage("stage_modeType") var stageModeTypeRaw: String = StageModeType.cueCard.rawValue {
    willSet { objectWillChange.send() }
}

var stageModeType: StageModeType {
    get { StageModeType(rawValue: stageModeTypeRaw) ?? .cueCard }
    set { stageModeTypeRaw = newValue.rawValue }
}
```

### Step 2: Add Setting UI

In `RunModeSettingsView.swift`, add to General section:

```swift
// Stage Mode Type Picker Card
VStack(alignment: .leading, spacing: 10) {
    Text("Stage Mode Type")
        .appFont(.headline)
        .foregroundStyle(.white)
    
    Picker("Stage Mode Type", selection: $settings.stageModeType) {
        ForEach(StageModeType.allCases) { type in
            Text(type.rawValue).tag(type)
        }
    }
    .pickerStyle(.segmented)
    
    Text("Cue Card: One block at a time with auto-advance. Teleprompter: Continuous scroll.")
        .appFont(.caption)
        .foregroundStyle(.white.opacity(0.6))
}
.padding(16)
.tfDynamicCard(cornerRadius: 16)
```

### Step 3: Create Routing View

Create `StageModeRouter.swift`:

```swift
import SwiftUI

/// Routes to the appropriate Stage Mode implementation based on settings
struct StageModeRouter: View {
    let setlist: Setlist
    var venue: String = ""
    
    @ObservedObject private var settings = RunModeSettingsStore.shared
    
    var body: some View {
        Group {
            switch settings.stageModeType {
            case .teleprompter:
                StageModeViewTeleprompter(setlist: setlist, venue: venue)
            case .cueCard:
                StageModeViewCueCard(setlist: setlist, venue: venue)
            }
        }
    }
}
```

### Step 4: Update Navigation Points

Find all places that navigate to Stage Mode and update:

```swift
// OLD:
NavigationLink {
    StageModeView(setlist: mySetlist, venue: venue)
}

// NEW:
NavigationLink {
    StageModeRouter(setlist: mySetlist, venue: venue)
}
```

## Option 3: Side-by-Side Testing

Keep both modes accessible during testing phase.

### Implementation

Keep original `StageModeView.swift` and new `StageModeViewCueCard.swift` with their current names.

Add separate navigation links in your setlist detail view:

```swift
// In setlist detail/action sheet:
Button("Stage Mode (Teleprompter)") {
    showTeleprompterMode = true
}

Button("Stage Mode (Cue Card) - NEW") {
    showCueCardMode = true
}

// Sheets:
.sheet(isPresented: $showTeleprompterMode) {
    StageModeView(setlist: setlist, venue: venue)
}

.sheet(isPresented: $showCueCardMode) {
    StageModeViewCueCard(setlist: setlist, venue: venue)
}
```

## Required Files Checklist

Ensure these files are in your project:

- ✅ `CueCard.swift` - Card data model
- ✅ `CueCardEngine.swift` - Recognition engine
- ✅ `StageModeViewCueCard.swift` - SwiftUI view
- ✅ `RunModeSettingsStore.swift` - Updated with cue card settings
- ✅ `RunModeSettingsView.swift` - Updated with cue card UI
- ✅ `PerformanceAnalytics.swift` - Updated with convenience initializer

## Existing Dependencies

The cue card mode uses existing components:

- `Setlist` - No changes needed
- `ScriptBlock` - No changes needed
- `SetlistAssignment` - No changes needed
- `Performance` - No changes needed
- `Permissions` - Reused for mic/speech access
- `TFTheme` - Reused for colors
- `.tfBackground()` - Reused for styling
- `.tfDynamicCard()` - Reused for card styling
- `.appFont()` - Reused for text styling

## Testing Your Integration

### 1. Basic Smoke Test

```swift
// Create a test setlist with 3-5 script blocks
let testSetlist = Setlist(title: "Cue Card Test")

// Add some script blocks (freeform or bits)
testSetlist.scriptBlocks = [
    .newFreeform(text: "First bit content here with enough words to make a meaningful anchor and exit phrase for testing purposes."),
    .newFreeform(text: "Second bit content here with different words to ensure phrases don't overlap with first bit content."),
    .newFreeform(text: "Third bit wrapping up the test setlist with final words that will serve as the exit phrase.")
]

// Navigate to cue card mode
// Verify: 3 cards display correctly
// Verify: Can swipe between cards
// Verify: Progress shows "1 / 3", "2 / 3", "3 / 3"
```

### 2. Recognition Test

```swift
// Start Stage Mode with test setlist
// Speak the content of first card clearly
// Verify: Exit phrase confidence increases
// Verify: Card auto-advances to second card
// Verify: Manual swipe works as fallback
```

### 3. Settings Test

```swift
// Go to More → Run Mode Settings
// Verify: "Cue Card Settings" section appears
// Verify: All toggles and sliders work
// Verify: Changes persist after app restart
```

## Common Integration Issues

### Issue: "CueCard type not found"

**Solution**: Ensure `CueCard.swift` is added to your Xcode target.

### Issue: "CueCardEngine type not found"

**Solution**: Ensure `CueCardEngine.swift` is added to your Xcode target.

### Issue: "Performance.insights type mismatch"

**Solution**: You may need to clean build folder (Shift+Cmd+K) and rebuild.

### Issue: "Settings toggles not appearing"

**Solution**: Verify `RunModeSettingsStore.swift` has the new cue card properties.

### Issue: Cards showing empty content

**Solution**: Verify your setlist has `scriptBlocks` populated (not just `assignments`).

## Rollback Plan

If you need to revert to the old system:

### If using Option 1 (Replace):

```bash
# Restore original names:
mv StageModeViewTeleprompter.swift StageModeView.swift
mv StageModeViewCueCard.swift StageModeViewCueCard.swift.backup
```

### If using Option 2 (Selector):

```swift
// In RunModeSettingsStore.swift:
@AppStorage("stage_modeType") var stageModeTypeRaw: String = StageModeType.teleprompter.rawValue
// Change default to .teleprompter
```

### If using Option 3 (Side-by-side):

No rollback needed - just keep using the teleprompter navigation.

## Performance Considerations

### Memory

- Each `CueCard` is lightweight (~500 bytes)
- 50-card setlist = ~25KB total
- Minimal memory footprint compared to scroll tracking

### Battery

- Speech recognition is already running in both modes
- Cue card mode may be slightly **more efficient** due to:
  - No continuous scroll calculations
  - Bounded recognition context
  - Less UI updates

### Storage

- Audio recording format identical to old mode
- No additional storage required
- Performance records store the same way

## Next Steps

1. Choose your integration option (1, 2, or 3)
2. Follow the steps for that option
3. Test with a simple setlist
4. Gather feedback from real performances
5. Tune phrase thresholds based on usage
6. Consider adding custom phrase markers in future

## Support

If you encounter issues:

1. Check this guide's "Common Integration Issues"
2. Review `CUE_CARD_IMPLEMENTATION.md` for architecture details
3. Verify all files are properly added to Xcode target
4. Check console logs for recognition debug prints
5. Test with a simple 2-3 card setlist first

## Success Criteria

You'll know the integration is successful when:

- ✅ Stage Mode shows one card at a time
- ✅ Swipe gestures navigate between cards
- ✅ Progress indicator shows current position
- ✅ Speech recognition triggers card transitions
- ✅ Manual controls always work
- ✅ Recordings save successfully
- ✅ Settings persist between sessions

Good luck! The cue card mode should provide a much more reliable performance experience.
