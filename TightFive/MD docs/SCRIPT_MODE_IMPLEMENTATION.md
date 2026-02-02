# Script Mode Implementation Guide

## Overview
This document describes the implementation of the Script Mode toggle feature for TightFive's Setlist Builder. This feature allows users to choose between **Modular** and **Traditional** script editing modes.

## Features Implemented

### 1. Script Mode Types

Two modes are now available:

#### Modular Mode (Default)
- Build scripts with insertable bits and freeform text blocks
- Drag and drop reordering
- Auto-generated cue cards from script blocks
- Anchor and exit phrase detection
- Full variation tracking for bits

#### Traditional Mode
- Single rich text editor (like the Notes tab)
- Full rich text formatting support
- Write script as a continuous document
- Cue Cards disabled by default
- Optional custom cue card configuration

### 2. Model Changes

**Setlist.swift:**
- Added `scriptMode: String` property (stores raw value of ScriptMode enum)
- Added `traditionalScriptRTF: Data` property for traditional mode content
- Added `hasCustomCueCards: Bool` flag for tracking custom cue card configuration
- Added `ScriptMode` enum with `.modular` and `.traditional` cases
- Added computed property `currentScriptMode` for type-safe access
- Added computed property `cueCardsAvailable` to check if cue cards can be used
- Updated `scriptPlainText` and `hasScriptContent` to work with both modes
- Added script block manipulation methods:
  - `insertBit(_:at:context:)`
  - `addFreeformBlock(rtfData:at:)`
  - `updateFreeformBlock(id:rtfData:)`
  - `moveBlocks(from:to:)`
  - `removeBlock(at:context:)`
  - `assignment(for:)`
  - `containsBit(withId:)`
  - `commitVariation(for:newRTF:note:context:)`

### 3. UI Changes

**SetlistBuilderView.swift:**
- Added script mode banner showing current mode
- Added mode-specific editors:
  - Modular: existing script block list
  - Traditional: RichTextEditor (same as Notes tab)
- Added "Script Mode" menu item in toolbar
- Updated Stage Mode menu options based on script mode:
  - Modular: "Configure Anchors" option
  - Traditional: "Configure Cue Cards" option
- Added state variables for new sheets:
  - `showScriptModeSettings`
  - `showCustomCueCardEditor`

**New Views:**
- `ScriptModeSettingsView`: Mode selection and explanation
- `CustomCueCardEditorView`: Custom cue card configuration (placeholder implementation)
- `CustomCueCardRow`: Display custom cue card in list

### 4. Stage Mode Integration

**CueCardSettingsStore.swift:**
- Added `isAvailable(for:)` method to `StageModeType`
- Cue Cards only available when:
  - Setlist is in Modular mode, OR
  - Setlist is in Traditional mode AND has custom cue cards configured

**CueCardSettingsView.swift:**
- Added optional `setlist` parameter
- Added warning when cue cards unavailable
- Added `cueCardsUnavailableView` for Traditional mode without custom cards
- Disabled cue card mode picker when unavailable

### 5. Mode Switching Logic

When switching from **Modular → Traditional**:
1. Script blocks content copied to `traditionalScriptRTF`
2. Cue Cards disabled (unless custom cards configured)
3. Stage Mode defaults to Script (unless user previously preferred Teleprompter)

When switching from **Traditional → Modular**:
1. Traditional script converted to single freeform block
2. Cue Cards re-enabled automatically
3. User can restructure into modular blocks

### 6. Custom Cue Cards Feature

**Purpose:** Allow Traditional mode users to manually create cue cards

**Components:**
- `CustomCueCard` struct with:
  - `id: UUID`
  - `content: String`
  - `anchorPhrase: String?`
  - `exitPhrase: String?`
  - `order: Int`
- `CustomCueCardEditorView`: Interface for creating/editing custom cards
- Enables Cue Card mode in Stage Mode when configured

## User Experience Flow

### Default Experience
1. User creates new setlist → Modular mode by default
2. Can insert bits and write freeform text
3. Cue Cards work automatically in Stage Mode

### Switching to Traditional
1. User opens "Script Mode" settings
2. Selects "Traditional" mode
3. Sees warning about cue cards being disabled
4. Confirms switch
5. Script blocks converted to continuous text
6. Can now use rich text formatting throughout

### Re-enabling Cue Cards in Traditional Mode
1. User in Traditional mode opens setlist menu
2. Selects "Configure Cue Cards"
3. Creates custom cue card entries
4. Saves configuration
5. Cue Cards now available in Stage Mode

### Preference Tracking
- System tracks if user prefers Teleprompter mode
- Stored in UserDefaults as `user_prefers_teleprompter`
- Used to determine default when switching modes

## Migration & Backwards Compatibility

- Existing setlists default to Modular mode
- `scriptMode` defaults to `"modular"` for existing setlists
- `traditionalScriptRTF` defaults to empty data
- `hasCustomCueCards` defaults to `false`
- No data loss when switching modes

## Testing Checklist

- [ ] Create new setlist → defaults to Modular
- [ ] Insert bits in Modular mode
- [ ] Add freeform blocks in Modular mode
- [ ] Switch to Traditional mode → content preserved
- [ ] Edit script in Traditional mode with rich text
- [ ] Switch back to Modular → content preserved as freeform block
- [ ] Configure custom cue cards in Traditional mode
- [ ] Verify Cue Cards disabled without custom cards
- [ ] Verify Cue Cards enabled with custom cards
- [ ] Verify Stage Mode defaults correctly based on mode
- [ ] Test Teleprompter preference tracking

## Future Enhancements

1. **Custom Cue Card Editor**: Full implementation with:
   - Visual card creator
   - Anchor/exit phrase extraction suggestions
   - Preview mode
   - Reordering interface

2. **AI-Assisted Cue Card Generation**: Analyze traditional script and suggest cue card breakpoints

3. **Hybrid Mode**: Allow mix of modular blocks and traditional sections

4. **Export Options**: Export with mode-specific formatting

5. **Templates**: Pre-configured mode templates for different performance styles

## API Reference

### ScriptMode Enum
```swift
enum ScriptMode: String, Codable, CaseIterable, Identifiable {
    case modular
    case traditional
    
    var displayName: String
    var description: String
}
```

### Setlist Extensions
```swift
// Script Mode
var currentScriptMode: ScriptMode { get set }
var cueCardsAvailable: Bool { get }

// Script Manipulation
func insertBit(_:at:context:)
func addFreeformBlock(rtfData:at:)
func updateFreeformBlock(id:rtfData:)
func moveBlocks(from:to:)
func removeBlock(at:context:)
func assignment(for:) -> SetlistAssignment?
func containsBit(withId:) -> Bool
func commitVariation(for:newRTF:note:context:)
```

### StageModeType Extension
```swift
func isAvailable(for setlist: Setlist?) -> Bool
```

## Notes

- Rich text formatting only available in Traditional mode and Notes tab
- Modular mode uses plain text for script blocks (themed RTF for display)
- Bit variations only tracked in Modular mode
- Custom cue cards stored as JSON in setlist model (future: separate model)
- Stage Mode behavior adapts based on current script mode

---

**Implementation Date:** February 1, 2026  
**Version:** 1.0  
**Status:** Complete (Custom Cue Card Editor is placeholder)
