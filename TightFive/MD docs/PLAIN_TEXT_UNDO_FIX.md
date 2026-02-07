# Plain Text Editor Undo/Redo Fix

## Problem
Undo/redo was working perfectly in `RichTextEditor` but not activating at all in `PlainTextEditor`.

## Root Causes

### 1. Missing Input Accessory View
**Issue:** UITextView requires an `inputAccessoryView` to properly establish its undo manager chain with the keyboard and responder system.

**Solution:** Added an empty UIToolbar as the inputAccessoryView:
```swift
let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 100, height: 44))
toolbar.items = []  // Empty toolbar, just here to activate undo
textView.inputAccessoryView = toolbar
```

### 2. UITextView's Automatic Undo Interference
**Issue:** UITextView has built-in automatic undo registration through its text storage that was conflicting with our custom undo system.

**Solution:** Disabled the automatic undo by clearing the text storage delegate:
```swift
textView.textStorage.delegate = nil  // Prevent automatic undo from text storage
```

### 3. Missing Input Views Reload
**Issue:** After setting up the undo manager and input accessory view, the system needs to be notified to refresh.

**Solution:** Added `reloadInputViews()` call after setup:
```swift
textView.reloadInputViews()
```

### 4. Undo Manager Not Cleared on Setup
**Issue:** When switching undo managers, old actions could linger.

**Solution:** Clear any existing undo actions when observing a new undo manager:
```swift
if let tv = textView {
    tv.undoManager?.removeAllActions()  // Clear any default actions
}
```

## Changes Made

### PlainTextEditor.swift

1. **configure(textView:)** - Added text storage delegate clearing
2. **attach(to:undoManager:)** - Added:
   - Empty UIToolbar as inputAccessoryView
   - Call to reloadInputViews()
3. **observeUndoManager(_:)** - Added clearing of existing undo actions

## Why RichTextEditor Worked

RichTextEditor was already working because:
1. ✅ It had a toolbar set as `inputAccessoryView`
2. ✅ It called `reloadInputViews()` after setup
3. ✅ The toolbar provided the necessary responder chain connection

## Testing Checklist

- [ ] Type text in plain text editor
- [ ] Wait ~350ms for undo grouping
- [ ] Shake device or three-finger swipe to trigger undo
- [ ] Verify text reverts to previous state
- [ ] Shake again to trigger redo
- [ ] Verify text returns to current state
- [ ] Test rapid typing with multiple undo/redo cycles
- [ ] Verify undo groups burst typing correctly
- [ ] Verify no keyboard lag or typing interference

## Technical Details

### Undo Manager Chain
```
SwiftUI Environment UndoManager
    ↓
PlainTextEditor undoManager param
    ↓
Coordinator externalUndoManager
    ↓
UITextView.undoManager (activated via inputAccessoryView)
    ↓
Responder Chain → Shake gesture/System undo UI
```

### Timing
- **Commit Delay:** 350ms (same as RichTextEditor)
- **Burst Grouping:** Captures text at burst start, commits on pause
- **Timer Mode:** `.default` (doesn't block scrolling)

## Performance Notes

All fixes maintain the existing performance optimizations:
- ✅ Non-contiguous layout for large text
- ✅ Disabled expensive text checking
- ✅ Immediate lightweight updates in `textViewDidChange`
- ✅ Deferred undo registration until typing pauses
- ✅ Proper timer cleanup in deinit

## Related Files
- `PlainTextEditor.swift` - Main implementation
- `RichTextEditor.swift` - Working reference implementation
- `KEYBOARD_PERFORMANCE_FIXES.md` - Related performance optimizations
