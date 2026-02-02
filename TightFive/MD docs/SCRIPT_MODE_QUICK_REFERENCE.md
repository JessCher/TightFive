# Script Mode - Quick Reference Guide

## For Developers

### Checking Script Mode

```swift
// In any view with access to a Setlist
if setlist.currentScriptMode == .modular {
    // Show modular-specific UI
} else {
    // Show traditional-specific UI
}
```

### Getting Script Content

```swift
// Works with both modes automatically
let plainText = setlist.scriptPlainText
let hasContent = setlist.hasScriptContent
```

### Checking Cue Card Availability

```swift
// Check if cue cards can be used
if setlist.cueCardsAvailable {
    // Enable cue card features
}

// Or check for specific mode
let mode = StageModeType.cueCards
if mode.isAvailable(for: setlist) {
    // Cue cards OK
}
```

### Switching Modes Programmatically

```swift
// Change mode
setlist.currentScriptMode = .traditional
setlist.updatedAt = Date()

// Handle content migration if needed
if setlist.currentScriptMode == .traditional {
    setlist.traditionalScriptRTF = TFRTFTheme.body(setlist.scriptPlainText)
}

try? modelContext.save()
```

### Working with Traditional Script

```swift
// Read traditional script
let rtfData = setlist.traditionalScriptRTF
let text = NSAttributedString.fromRTF(rtfData)?.string ?? ""

// Update traditional script
setlist.traditionalScriptRTF = TFRTFTheme.body(newText)
setlist.updatedAt = Date()
```

### Working with Modular Script

```swift
// Add a freeform block
setlist.addFreeformBlock(rtfData: TFRTFTheme.body("My text"), at: nil)

// Insert a bit
setlist.insertBit(bit, at: index, context: modelContext)

// Remove a block
setlist.removeBlock(at: index, context: modelContext)

// Move blocks
setlist.moveBlocks(from: sourceIndices, to: destination)
```

## For UI/UX

### Mode Selection UI

**Location:** Setlist Builder > Menu > Script Mode

**States:**
1. **Modular Selected**: Yellow border, checkmark visible
2. **Traditional Selected**: Yellow border, checkmark visible
3. **Switching**: Alert confirmation required

### Visual Indicators

**Script Mode Banner (Setlist Builder):**
- Icon: Grid (modular) or Document (traditional)
- Text: "[Mode] Mode"
- Action: "Change Mode" button

**Stage Mode Settings:**
- Cue Cards option grayed out if unavailable
- Warning icon + text when traditional mode without custom cards

### User Flows

#### Happy Path - Modular User
1. Create setlist → Modular by default
2. Insert bits, write transitions
3. Enter Stage Mode → Cue Cards work automatically

#### Happy Path - Traditional User
1. Create setlist → Modular by default
2. Open Script Mode settings
3. Switch to Traditional
4. Write full script with formatting
5. Enter Stage Mode → Use Script or Teleprompter

#### Edge Case - Traditional User Wants Cue Cards
1. In Traditional mode
2. Attempts to select Cue Cards in Stage Mode Settings
3. Sees "unavailable" message
4. Opens "Configure Cue Cards" from menu
5. Creates custom cards
6. Returns to Stage Mode Settings
7. Cue Cards now available

## Stage Mode Behavior

### Modular Mode
- **Cue Cards**: ✅ Auto-generated from script blocks
- **Script**: ✅ Shows full script, scrollable
- **Teleprompter**: ✅ Auto-scrolling script

### Traditional Mode (No Custom Cards)
- **Cue Cards**: ❌ Disabled
- **Script**: ✅ Shows full script, scrollable
- **Teleprompter**: ✅ Auto-scrolling script

### Traditional Mode (With Custom Cards)
- **Cue Cards**: ✅ Uses custom card definitions
- **Script**: ✅ Shows full script, scrollable
- **Teleprompter**: ✅ Auto-scrolling script

## Default Behavior

### New Setlists
- Mode: **Modular**
- Cue Cards: **Enabled**
- Stage Mode Default: **Cue Cards** (unless user prefers Teleprompter)

### Mode Switch → Traditional
- Cue Cards: **Disabled**
- Stage Mode Default: **Script** (unless user prefers Teleprompter)
- Content: **Preserved** (converted to continuous text)

### Mode Switch → Modular
- Cue Cards: **Enabled**
- Stage Mode Default: **Restored to user preference**
- Content: **Preserved** (converted to single freeform block)

## Testing Commands

### Check Current Mode
```swift
print("Mode:", setlist.currentScriptMode.displayName)
print("Cue Cards Available:", setlist.cueCardsAvailable)
print("Has Custom Cards:", setlist.hasCustomCueCards)
```

### Verify Content in Both Modes
```swift
// Should work regardless of mode
print("Script Text:", setlist.scriptPlainText)
print("Has Content:", setlist.hasScriptContent)
print("Estimated Duration:", setlist.formattedDuration)
```

### Force Mode Reset
```swift
setlist.currentScriptMode = .modular
setlist.hasCustomCueCards = false
try? modelContext.save()
```

## Common Issues

### Issue: Cue Cards Not Available
**Check:**
1. Is setlist in Traditional mode? → `setlist.currentScriptMode`
2. Are custom cards configured? → `setlist.hasCustomCueCards`

**Fix:**
- Switch to Modular mode, OR
- Configure custom cue cards

### Issue: Content Lost After Mode Switch
**Check:**
1. Did content copy properly? → Check `traditionalScriptRTF` or `scriptBlocks`

**Fix:**
- Mode switching preserves content automatically
- If lost, check migration code in `ScriptModeSettingsView.changeScriptMode()`

### Issue: Stage Mode Defaults Wrong
**Check:**
1. User's teleprompter preference → `UserDefaults.standard.bool(forKey: "user_prefers_teleprompter")`

**Fix:**
- Update preference tracking in `updateStageModeDefaults()`

## API Quick Reference

### Enums
- `ScriptMode`: `.modular`, `.traditional`
- `StageModeType`: `.cueCards`, `.script`, `.teleprompter`

### Setlist Properties
- `scriptMode: String` (raw storage)
- `currentScriptMode: ScriptMode` (computed)
- `traditionalScriptRTF: Data`
- `hasCustomCueCards: Bool`
- `cueCardsAvailable: Bool` (computed)

### Setlist Methods
- `insertBit(_:at:context:)`
- `addFreeformBlock(rtfData:at:)`
- `updateFreeformBlock(id:rtfData:)`
- `moveBlocks(from:to:)`
- `removeBlock(at:context:)`

### Helper Types
- `CustomCueCard`: Stores manual cue card definition
- `ScriptModeSettingsView`: Mode selection UI
- `CustomCueCardEditorView`: Custom card configuration UI

---

**Last Updated:** February 1, 2026  
**Component:** Script Mode System  
**Stability:** Stable (Custom Cue Cards = Beta)
