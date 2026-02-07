# Undo/Redo Keyboard Toolbar Buttons

## Summary

Added undo (↶) and redo (↷) buttons to the keyboard accessory toolbars for both `PlainTextEditor` and `RichTextEditor`. These buttons interact with UITextView's built-in undo/redo functionality and automatically update their enabled/disabled state.

---

## PlainTextEditor.swift

### Added:
- **`PlainTextToolbar`**: A new UIKit toolbar class specifically for plain text editing
  - Undo button (⎌) using SF Symbol `arrow.uturn.backward` - calls `textView.undoManager?.undo()`
  - Redo button (⎌) using SF Symbol `arrow.uturn.forward` - calls `textView.undoManager?.redo()`
  - Done button (styled in TFYellow)
  - Auto-layout with TFCard styling (rounded, shadowed, bordered)
  
- **`iconPill` method**: New button factory method for creating icon-based buttons using SF Symbols
  - Accepts system symbol name instead of text
  - Configures symbol size and weight (15pt, semibold)
  - Returns consistently-styled UIButton
  
- **Button State Management**:
  - Observes `NSUndoManagerDidUndoChange`, `NSUndoManagerDidRedoChange`, and `NSUndoManagerDidCloseUndoGroup` notifications
  - Automatically enables/disables buttons based on `undoManager.canUndo` and `undoManager.canRedo`
  - Reduces opacity to 0.3 when disabled for visual feedback
  
- **Integration**:
  - Added `inputAccessoryView` assignment in `configure(textView:)` method
  - Toolbar is instantiated with reference to the text view

---

## RichTextEditor.swift

### Modified:

#### EditorToolbarAction Enum:
**Added two new cases:**
```swift
case undo
case redo
```

#### EditorToolbar.populate():
**Added at the beginning of the toolbar:**
- Undo button using SF Symbol `arrow.uturn.backward`
- Redo button using SF Symbol `arrow.uturn.forward`

**Added helper method:**
- `iconPill(systemName:a11y:action:)` - Creates icon-based pill buttons with SF Symbols

These buttons appear before the existing typography controls (A−, A+).

#### EditorCoordinator.executeAction():
**Added handlers for new actions:**
```swift
case .undo:
    tv.undoManager?.undo()
    return  // No commit or toolbar update needed
    
case .redo:
    tv.undoManager?.redo()
    return  // No commit or toolbar update needed
```

These return early since undo/redo shouldn't trigger commits or toolbar updates.

---

## UI/UX Details

### Visual Design:
- **Button symbols**: SF Symbols `arrow.uturn.backward` (undo) and `arrow.uturn.forward` (redo) for a clean, native iOS appearance
- **Styling**: Matches existing toolbar pill buttons
  - Capsule shape
  - White symbols on semi-transparent background
  - 44pt × 36pt size for easy tapping
  - Semibold weight at 15pt

### Behavior:
- **PlainTextEditor**: Buttons appear on the left, "Done" on the right with spacer in between
- **RichTextEditor**: Buttons appear first in scrollable toolbar, followed by all formatting controls
- **State updates**: Buttons automatically dim when undo/redo stack is empty
- **Accessibility**: Proper labels ("Undo" and "Redo") for VoiceOver

---

## How It Works

### PlainTextEditor:
1. When the keyboard appears, `PlainTextToolbar` is shown as the `inputAccessoryView`
2. Toolbar observes the UITextView's `undoManager` for changes
3. When user taps ↶, calls `undoManager?.undo()`
4. When user taps ↷, calls `undoManager?.redo()`
5. Button states update automatically via notifications

### RichTextEditor:
1. Undo/redo buttons are part of the existing `EditorToolbar`
2. Buttons trigger `.undo` and `.redo` actions via the delegate pattern
3. Coordinator receives actions and calls `undoManager?.undo()` or `redo()`
4. Early return prevents unnecessary commits or toolbar updates

---

## Testing

Test the following scenarios:

### PlainTextEditor:
1. Type text → tap ↶ → text should undo
2. Undo text → tap ↷ → text should redo
3. With empty undo stack → ↶ should be dimmed/disabled
4. With empty redo stack → ↷ should be dimmed/disabled
5. Tap "Done" → keyboard should dismiss

### RichTextEditor:
1. Type text → tap ↶ → text should undo
2. Apply formatting → tap ↶ → formatting should undo
3. Undo multiple times → tap ↷ → should redo in sequence
4. Toggle list mode → tap ↶ → list should undo
5. Verify undo/redo works alongside all other toolbar features

---

## Implementation Notes

### Why separate toolbars?
- **PlainTextEditor** has minimal needs (undo/redo/done), so uses a simple dedicated toolbar
- **RichTextEditor** already had a rich toolbar, so undo/redo was integrated into existing infrastructure

### Performance:
- Notification observers are properly cleaned up in `deinit`
- State updates use lightweight property checks (`canUndo`, `canRedo`)
- No polling or timers needed

### Accessibility:
- All buttons have proper `accessibilityLabel` values
- Enabled/disabled state is communicated via alpha and `isEnabled`
- Toolbar follows system accessibility conventions

---

## Code Quality

### Follows existing patterns:
- Matches pill button styling from RichTextEditor
- Uses same TFCard/TFYellow design tokens
- Follows UIViewRepresentable coordinator pattern
- Proper memory management (weak references, observer cleanup)

### Clean separation of concerns:
- PlainTextToolbar is self-contained
- RichTextEditor undo/redo flows through existing action/delegate system
- No duplication of undo/redo logic (just calls system APIs)

---

## Future Enhancements

Potential improvements for later:

1. **Keyboard shortcuts**: Add ⌘Z (undo) and ⌘⇧Z (redo) for external keyboard users
2. **Undo labels**: Show "Undo Typing", "Undo Bold", etc. (requires custom undo registration)
3. **Gesture support**: Enable shake-to-undo on supported devices
4. **Toolbar state sync**: Update button enabled state in RichTextEditor like PlainTextEditor does
5. **Haptic feedback**: Add subtle haptics when undo/redo succeeds or fails

---

## Files Modified

- `PlainTextEditor.swift`: Added `PlainTextToolbar` class and toolbar integration
- `RichTextEditor.swift`: Added undo/redo actions and toolbar buttons

No breaking changes to public APIs.
