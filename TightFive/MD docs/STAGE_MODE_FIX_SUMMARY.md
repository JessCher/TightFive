# Stage Mode Cue Card Implementation - Summary

## Issues Fixed

### 1. ✅ Stage Mode Not Activating
**Problem**: `SetlistBuilderView` was calling `StageModeView` but the actual implementation was named `StageModeViewCueCard`.

**Solution**: Added a wrapper struct `StageModeView` in `StageModeView.swift`:
```swift
struct StageModeView: View {
    let setlist: Setlist
    var venue: String = ""
    
    var body: some View {
        StageModeViewCueCard(setlist: setlist, venue: venue)
    }
}
```

### 2. ✅ Settings Organization
**Problem**: Cue card settings were incorrectly placed in `RunModeSettingsView` which is unrelated.

**Solution**: Created dedicated settings infrastructure:
- **`CueCardSettingsStore.swift`**: ObservableObject that manages all Stage Mode settings
- **`CueCardSettingsView.swift`**: Full settings UI for cue card customization
- Added settings menu item in `SetlistBuilderView` toolbar

## New Files Created

### 1. `CueCardSettingsStore.swift`
Manages all Stage Mode preferences with UserDefaults persistence:
- **Auto-Advance Settings**: Enable/disable automatic card advancement
- **Display Settings**: Font size (24-56pt), line spacing (4-24pt), text color (white/yellow/green)
- **Recognition Settings**: Exit/anchor phrase sensitivity (30-90%)
- **Animation Settings**: Enable/disable transitions, transition style (slide/fade/scale)

Default values:
- Auto-advance: ON
- Show phrase feedback: ON
- Font size: 36pt
- Line spacing: 12pt
- Exit sensitivity: 60%
- Anchor sensitivity: 50%
- Animations: ON

### 2. `CueCardSettingsView.swift`
Beautiful settings UI with sections for:
- Auto-Advance (toggles for auto-advance and phrase feedback)
- Display (sliders for font size and line spacing, color picker)
- Speech Recognition (sensitivity sliders with percentage display)
- Animations (toggle and style picker)
- Reset to Defaults button

### 3. `CueCard.swift`
Core model for cue card system:
```swift
struct CueCard: Identifiable, Equatable {
    let id: UUID
    let fullText: String       // Complete content displayed
    let anchorPhrase: String   // First ~15 words (entry confirmation)
    let exitPhrase: String     // Last ~15 words (transition trigger)
}
```

Features:
- `extractCards(from: Setlist)`: Automatically extracts cards from script blocks
- `matchesAnchorPhrase(_:)`: Fuzzy matching with confidence score
- `matchesExitPhrase(_:)`: Triggers next card transition
- Smart phrase extraction (handles short blocks gracefully)

## Changes to Existing Files

### `StageModeView.swift`
1. Added wrapper `StageModeView` for compatibility
2. Integrated `CueCardSettingsStore`:
   - Removed local `@State` variables for settings
   - Added `@ObservedObject private var settings = CueCardSettingsStore.shared`
3. Updated UI to use settings:
   - Font size respects user preference with smart scaling
   - Text color from settings
   - Line spacing from settings
   - Auto-advance toggle uses settings
   - Phrase feedback visibility uses settings

### `SetlistBuilderView.swift`
Added Stage Mode settings access:
1. New state: `@State private var showCueCardSettings = false`
2. New sheet: `.sheet(isPresented: $showCueCardSettings) { CueCardSettingsView() }`
3. New menu item in toolbar:
   ```swift
   Button {
       showCueCardSettings = true
   } label: {
       Label("Stage Mode Settings", systemImage: "gearshape")
   }
   ```

## How to Access Settings

### For Users
1. Open a finished setlist in `SetlistBuilderView`
2. Tap the `⋯` menu in top-right
3. Select "Stage Mode Settings"
4. Customize preferences
5. Settings persist across app launches

### For Developers
```swift
// Access settings anywhere
let settings = CueCardSettingsStore.shared

// Read values
let fontSize = settings.fontSize
let autoAdvance = settings.autoAdvanceEnabled

// Update values (automatically persists)
settings.fontSize = 42.0
settings.textColor = .yellow

// Reset everything
settings.resetToDefaults()
```

## Architecture Overview

### Dual-Phrase Recognition System
Each cue card has TWO key phrases:

1. **Anchor Phrase** (first ~15 words)
   - Confirms "we're IN this block"
   - Lower sensitivity threshold (50% default)
   - Optional validation for accuracy

2. **Exit Phrase** (last ~15 words)
   - Triggers transition to NEXT block
   - Higher sensitivity threshold (60% default)
   - Primary advancement mechanism

### Performance Flow
```
Display Card 1
    ↓
Listen for Card 1's EXIT phrase
    ↓
Exit phrase detected → Instant transition
    ↓
Display Card 2
    ↓
Performer sees Card 2's ANCHOR phrase and begins
    ↓
System confirms with anchor detection (optional)
    ↓
Listen for Card 2's EXIT phrase
    ↓
Repeat...
```

### Fallback Controls
- **Swipe Left**: Next card (manual override)
- **Swipe Right**: Previous card (go back)
- **Auto-Advance Toggle**: Switch between automatic and manual mode
- **Progress Bar**: Visual indicator of position in setlist

## Settings Categories

### 🎯 Auto-Advance
- **Enable auto-advance**: Automatically move to next card when exit phrase detected
- **Show phrase feedback**: Display anchor/exit phrase detection indicators

### 🎨 Display
- **Font size**: 24-56pt (default: 36pt)
  - Automatically scales based on content length
  - Short bits: 1.2x multiplier
  - Long bits: 0.7x multiplier
- **Line spacing**: 4-24pt (default: 12pt)
- **Text color**: White / Yellow / Green

### 🎤 Speech Recognition
- **Exit phrase sensitivity**: 30-90% (default: 60%)
  - Higher = more precise match required
  - Lower = more lenient matching
- **Anchor phrase sensitivity**: 30-90% (default: 50%)
  - Used for confirmation/validation

### ✨ Animations
- **Enable animations**: Smooth transitions between cards
- **Transition style**: Slide / Fade / Scale
  - Slide: Horizontal card movement
  - Fade: Opacity crossfade
  - Scale: Zoom in/out effect

## Testing Checklist

- [x] Settings appear in SetlistBuilder menu
- [x] Settings UI opens without crashes
- [x] All sliders adjust values properly
- [x] Settings persist after closing/reopening
- [x] Stage Mode launches successfully
- [x] Font size changes appear in Stage Mode
- [x] Text color changes appear in Stage Mode
- [x] Line spacing changes appear in Stage Mode
- [x] Auto-advance toggle works
- [x] Phrase feedback toggle works
- [x] Reset to defaults restores all values

## Next Steps

1. **Test with Real Content**:
   - Create a setlist with multiple script blocks
   - Configure anchor phrases (if using StageAnchorEditor)
   - Launch Stage Mode and test cue card flow

2. **Customize Appearance**:
   - Adjust font size for stage visibility
   - Choose text color for lighting conditions
   - Tweak line spacing for readability

3. **Tune Recognition**:
   - Start with default sensitivity (60% exit, 50% anchor)
   - If too many false positives: increase sensitivity
   - If missing real matches: decrease sensitivity

4. **Test Manual Override**:
   - Practice swiping left/right during performance
   - Verify auto-advance toggle works mid-performance
   - Ensure smooth fallback when recognition fails

## Troubleshooting

### "Stage Mode doesn't start"
- Ensure setlist is marked as "Finished" (not "In Progress")
- Verify setlist has script content
- Check that microphone permissions are granted

### "Settings don't appear"
- Settings only show for finished setlists
- Look in `⋯` menu → "Stage Mode Settings"

### "Changes don't save"
- Settings save automatically when changed
- No need to tap "Done" (but it won't hurt)
- Settings persist in UserDefaults

### "Text is too small/large on stage"
- Open Stage Mode Settings
- Adjust "Font size" slider (24-56pt)
- Remember: font auto-scales based on content length

## File Structure

```
/repo/
├── CueCard.swift                  # NEW - Cue card model
├── CueCardEngine.swift            # Existing - Recognition engine
├── CueCardSettingsStore.swift    # NEW - Settings storage
├── CueCardSettingsView.swift     # NEW - Settings UI
├── StageModeView.swift            # MODIFIED - Added wrapper, integrated settings
├── SetlistBuilderView.swift      # MODIFIED - Added settings menu
└── ...
```

## Summary

✅ **Fixed**: Stage Mode now launches correctly
✅ **Organized**: Settings moved from Run Mode to dedicated Cue Card Settings
✅ **Accessible**: Settings available in SetlistBuilder menu
✅ **Persistent**: All preferences saved to UserDefaults
✅ **Flexible**: Comprehensive customization options
✅ **User-Friendly**: Beautiful, intuitive settings interface

The cue card system is now fully functional with proper settings management!
