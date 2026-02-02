# Script Mode Implementation - Developer Checklist

## ✅ Completed Items

### Model Layer
- [x] Add `scriptMode: String` property to Setlist
- [x] Add `traditionalScriptRTF: Data` property to Setlist
- [x] Add `hasCustomCueCards: Bool` property to Setlist
- [x] Create `ScriptMode` enum with `.modular` and `.traditional`
- [x] Add `currentScriptMode` computed property
- [x] Add `cueCardsAvailable` computed property
- [x] Update `scriptPlainText` to work with both modes
- [x] Update `hasScriptContent` to work with both modes
- [x] Implement `insertBit(_:at:context:)` method
- [x] Implement `addFreeformBlock(rtfData:at:)` method
- [x] Implement `updateFreeformBlock(id:rtfData:)` method
- [x] Implement `moveBlocks(from:to:)` method
- [x] Implement `removeBlock(at:context:)` method
- [x] Implement `assignment(for:)` method
- [x] Implement `containsBit(withId:)` method
- [x] Implement `commitVariation(for:newRTF:note:context:)` method
- [x] Create `CustomCueCard` struct

### Stage Mode Integration
- [x] Add `isAvailable(for:)` method to `StageModeType`
- [x] Update cue card availability logic
- [x] Add `setlist` parameter to `CueCardSettingsView`
- [x] Add warning UI for unavailable cue cards
- [x] Create `cueCardsUnavailableView`

### UI Layer
- [x] Add script mode banner to SetlistBuilderView
- [x] Implement `modularScriptEditor` view
- [x] Implement `traditionalScriptEditor` view
- [x] Add "Script Mode" menu item in toolbar
- [x] Add mode-specific configuration menu items
- [x] Add `showScriptModeSettings` state variable
- [x] Add `showCustomCueCardEditor` state variable
- [x] Create `ScriptModeSettingsView`
- [x] Create `CustomCueCardEditorView` (placeholder)
- [x] Create `CustomCueCardRow` view
- [x] Implement mode switching confirmation alert
- [x] Implement content migration logic
- [x] Implement Stage Mode default logic

### Documentation
- [x] Create SCRIPT_MODE_IMPLEMENTATION.md
- [x] Create SCRIPT_MODE_QUICK_REFERENCE.md
- [x] Create STAGE_MODE_SCRIPT_INTEGRATION.md
- [x] Create SCRIPT_MODE_SUMMARY.md
- [x] Create SCRIPT_MODE_ARCHITECTURE.md
- [x] Create this checklist

## 🚧 Pending Items (For Full Release)

### Custom Cue Card Editor (Priority: High)
- [ ] Design card creation UI
- [ ] Implement card content editor
- [ ] Add anchor phrase input field
- [ ] Add exit phrase input field
- [ ] Implement card reordering (drag & drop)
- [ ] Add card deletion
- [ ] Implement card preview mode
- [ ] Save cards to setlist.customCueCardsData
- [ ] Load cards from setlist.customCueCardsData
- [ ] Validate card data before saving
- [ ] Handle empty/invalid card content
- [ ] Add "Extract Phrases" suggestion feature

### Testing (Priority: Critical)
- [ ] Unit tests for ScriptMode enum
- [ ] Unit tests for Setlist script mode methods
- [ ] Unit tests for StageModeType availability
- [ ] UI tests for mode switching
- [ ] UI tests for modular script editing
- [ ] UI tests for traditional script editing
- [ ] Integration tests for Stage Mode with both modes
- [ ] Test content preservation during mode switch
- [ ] Test cue card availability logic
- [ ] Test Stage Mode defaults
- [ ] Test preference tracking
- [ ] Test with empty setlists
- [ ] Test with large setlists (100+ blocks)
- [ ] Test with setlists containing special characters
- [ ] Test migration from old setlists

### Polish (Priority: Medium)
- [ ] Add animated transition when switching modes
- [ ] Improve empty state illustrations
- [ ] Add tutorial/onboarding for each mode
- [ ] Add tooltips for mode features
- [ ] Improve script mode banner design
- [ ] Add haptic feedback for mode switch
- [ ] Add confirmation before switching with unsaved changes
- [ ] Improve error messages
- [ ] Add success confirmation after mode switch

### Advanced Features (Priority: Low)
- [ ] AI-assisted cue card generation from traditional scripts
- [ ] Smart breakpoint detection in traditional scripts
- [ ] Anchor phrase extraction suggestions
- [ ] Export format options per mode
- [ ] Import scripts from other formats
- [ ] Script templates for each mode
- [ ] Performance metrics per mode
- [ ] Hybrid mode (mix of modular and traditional)

## 🐛 Known Issues / Edge Cases to Test

### Mode Switching
- [ ] What happens if user switches mode during Stage Mode?
- [ ] What happens if user switches mode during performance recording?
- [ ] Can user undo a mode switch?
- [ ] What if switch fails mid-operation?

### Custom Cue Cards
- [ ] What if customCueCardsData is corrupted?
- [ ] What if user deletes all custom cards?
- [ ] What if cards have no content?
- [ ] What if cards have duplicate anchor phrases?
- [ ] Maximum number of custom cards?

### Content Preservation
- [ ] Large scripts (10,000+ words) - performance?
- [ ] Special characters in RTF data
- [ ] Embedded images (if supported)
- [ ] Very long single blocks
- [ ] Empty blocks after mode switch

### Stage Mode
- [ ] Stage Mode with no script content
- [ ] Stage Mode with traditional mode and empty custom cards
- [ ] Voice recognition with custom anchor phrases
- [ ] Phrase detection accuracy with traditional text

### Preferences
- [ ] Conflicting preferences across devices (iCloud sync)
- [ ] Corrupted UserDefaults
- [ ] Preference not set (first launch)

## 📋 Pre-Release Testing Script

Run through this sequence before releasing:

### Test Case 1: New User - Modular Flow
1. [ ] Create new setlist
2. [ ] Verify defaults to Modular mode
3. [ ] Insert 3 bits
4. [ ] Add 2 freeform blocks
5. [ ] Reorder blocks
6. [ ] Enter Stage Mode
7. [ ] Verify Cue Cards work
8. [ ] Complete performance

### Test Case 2: New User - Traditional Flow
1. [ ] Create new setlist
2. [ ] Open Script Mode settings
3. [ ] Switch to Traditional mode
4. [ ] Confirm switch
5. [ ] Write script with formatting
6. [ ] Enter Stage Mode
7. [ ] Verify Cue Cards disabled
8. [ ] Use Script mode
9. [ ] Complete performance

### Test Case 3: Mode Switching
1. [ ] Start in Modular with 5 blocks
2. [ ] Switch to Traditional
3. [ ] Verify content preserved
4. [ ] Edit in Traditional mode
5. [ ] Switch back to Modular
6. [ ] Verify content in freeform block
7. [ ] Break into multiple blocks
8. [ ] Verify everything works

### Test Case 4: Custom Cue Cards
1. [ ] Create setlist in Traditional mode
2. [ ] Attempt Stage Mode
3. [ ] Verify Cue Cards unavailable
4. [ ] Open "Configure Cue Cards"
5. [ ] Create 3 custom cards
6. [ ] Save configuration
7. [ ] Enter Stage Mode
8. [ ] Verify Cue Cards now available
9. [ ] Test voice recognition with custom phrases

### Test Case 5: Existing Setlist Migration
1. [ ] Open existing setlist (pre-script-mode)
2. [ ] Verify defaults to Modular
3. [ ] Verify all content present
4. [ ] Switch to Traditional
5. [ ] Verify content preserved
6. [ ] Switch back to Modular
7. [ ] Verify still works

### Test Case 6: Edge Cases
1. [ ] Empty setlist in both modes
2. [ ] Very large setlist (50+ blocks)
3. [ ] Setlist with only freeform blocks
4. [ ] Setlist with only bit blocks
5. [ ] Special characters in script
6. [ ] Switching modes rapidly
7. [ ] Network interruption during save
8. [ ] Low memory conditions

## 🚀 Deployment Checklist

### Before Merging to Main
- [ ] All completed items verified
- [ ] All critical tests passed
- [ ] Documentation reviewed
- [ ] Code review completed
- [ ] No compiler warnings
- [ ] No SwiftData migration issues
- [ ] UserDefaults keys documented
- [ ] Backward compatibility verified

### Before App Store Submission
- [ ] Beta testing completed (TestFlight)
- [ ] User feedback incorporated
- [ ] Performance testing passed
- [ ] Accessibility testing passed
- [ ] All known issues documented
- [ ] Release notes written
- [ ] Support documentation updated
- [ ] Video tutorial recorded (optional)

### Post-Launch Monitoring
- [ ] Monitor crash reports
- [ ] Monitor user feedback
- [ ] Track mode adoption rates
- [ ] Track custom cue card usage
- [ ] Gather feature requests
- [ ] Plan next iteration

## 📊 Success Metrics

Track these after launch:

### Adoption Metrics
- [ ] % of users who try Traditional mode
- [ ] % of users who stick with Traditional mode
- [ ] % of users who switch between modes
- [ ] % of users who configure custom cue cards

### Usage Metrics
- [ ] Average setlist size per mode
- [ ] Performance completion rate per mode
- [ ] Stage Mode type preferences per mode
- [ ] Time spent in each mode

### Quality Metrics
- [ ] Crash rate related to script modes
- [ ] Bug reports per mode
- [ ] User satisfaction scores
- [ ] Feature request frequency

## 🎯 Next Sprint Planning

Based on metrics, prioritize:

### If Traditional Mode Popular:
- [ ] Prioritize Custom Cue Card Editor completion
- [ ] Add AI script analysis features
- [ ] Improve rich text editing experience

### If Modular Mode Dominant:
- [ ] Enhance bit variation system
- [ ] Improve drag & drop experience
- [ ] Add more bit library features

### If Hybrid Use Cases Emerge:
- [ ] Design Hybrid mode
- [ ] Allow mix of modular and traditional sections
- [ ] Create conversion tools

---

**Checklist Version:** 1.0  
**Last Updated:** February 1, 2026  
**Status:** Implementation Complete, Testing Pending  
**Ready for:** Code Review and Testing

## Quick Commands for Testing

```swift
// Check mode
print(setlist.currentScriptMode.displayName)

// Force mode
setlist.currentScriptMode = .traditional

// Check availability
print("Cue Cards:", setlist.cueCardsAvailable)
print("Custom Cards:", setlist.hasCustomCueCards)

// Get content
print("Content:", setlist.scriptPlainText)
```
