# Plain Text Editor Migration Summary

## Overview
Transitioned the app from using RichTextEditor everywhere to using PlainTextEditor for most text entry, with RichTextEditor reserved only for specific note-taking fields that benefit from formatting.

## What Changed

### ✅ Files Modified

1. **PlainTextEditor.swift** (NEW)
   - Created a new plain text editor component with full undo/redo support
   - Based on UITextView like RichTextEditor but without rich text formatting
   - Includes smart typing features (autocorrection, smart quotes, etc.)
   - Maintains the same undo/redo architecture as RichTextEditor

2. **SetlistBuilderView.swift**
   - **Script Tab**: Now uses `PlainTextEditor` for all script blocks (freeform and bit assignments)
   - **Notes Tab**: Still uses `RichTextEditor` for auxiliary notes ✅
   - Updated `ScriptBlockRowView` to convert between plain text and RTF as needed
   - State variable changed from `editRTF: Data` to `editText: String`

3. **QuickBitEditor.swift**
   - Changed from `RichTextEditor` to `PlainTextEditor`
   - State variable changed from `rtfData: Data` to `text: String`
   - Simplified dictation integration (no RTF conversion needed)

4. **LooseBitsView.swift**
   - No changes needed - already using `UndoableTextEditor` (plain text with undo/redo)

5. **FinishedBitsView.swift**
   - No changes needed - already using `UndoableTextEditor` via `FinishedBitDetailView`

6. **Performance.swift**
   - Changed `notes: String` to `notesRTF: Data` to support rich text in Show Notes
   - Added `notesPlainText` computed property for migration/export
   - Updated `isReviewed` to check `notesRTF.isEmpty`

7. **ShowNotesView.swift**
   - Updated `PerformanceDetailView` to use `RichTextEditor` for notes field ✅
   - Added keyboard observation and undo/redo toolbar support
   - Notes now support full rich text formatting

## Where Rich Text is Used (ONLY 2 Places)

### ✅ 1. Setlist Builder - Notes Tab
- **Location**: `SetlistBuilderView.swift` → Notes tab
- **Why**: Auxiliary notes for delivery ideas, reminders, and performance planning
- **Component**: `RichTextEditor(rtfData: $setlist.notesRTF, undoManager: undoManager)`

### ✅ 2. Show Notes - Performance Notes
- **Location**: `ShowNotesView.swift` → `PerformanceDetailView` → Notes section
- **Why**: Post-performance reflections and detailed notes
- **Component**: `RichTextEditor(rtfData: $performance.notesRTF, undoManager: undoManager)`

## Where Plain Text is Used

### 1. Setlist Builder - Script Blocks
- **Freeform blocks**: Plain text entry with undo/redo
- **Bit assignments**: Plain text editing of performed content
- Stored as RTF internally for consistency, converted to/from plain text for editing

### 2. Bit Entry (All Types)
- **Quick Bit Editor**: Plain text with dictation
- **Loose Bits**: Plain text with `UndoableTextEditor`
- **Finished Bits**: Plain text with `UndoableTextEditor`

## Undo/Redo Support

### ✅ Maintained Everywhere
- **PlainTextEditor**: Full undo/redo via UndoManager (same pattern as RichTextEditor)
- **RichTextEditor**: Unchanged, continues to work as before
- **UndoableTextEditor**: Already had undo/redo support (used in bit editing)
- **Toolbar**: Undo/redo buttons appear when keyboard is visible across all views

## Technical Details

### PlainTextEditor Architecture
- UIKit-backed UITextView wrapped in SwiftUI
- Burst-grouped undo operations (same as RichTextEditor)
- Debounced commits (300ms default)
- Cursor stability with internal update guards
- Smart text features enabled (quotes, dashes, autocorrection)

### Data Flow for Script Blocks
```swift
// When editing starts:
editText = NSAttributedString.fromRTF(rtfData)?.string ?? ""

// When editing ends:
let rtf = TFRTFTheme.body(editText)
onEndEdit(rtf)
```

This maintains RTF storage for consistency while providing plain text editing experience.

## Migration Notes

### Performance Model Migration
- Old: `var notes: String`
- New: `var notesRTF: Data`
- **Action Required**: Existing performances with String notes will need migration
- Helper available: `notesPlainText` computed property

### No Other Migrations Needed
- Bit text is already plain String (no changes)
- Setlist scripts already use RTF (no changes to storage format)

## Benefits

1. **Simpler UX**: Users don't need to manage formatting for performance scripts
2. **Faster Performance**: Plain text editing is more lightweight
3. **Consistent Focus**: Rich formatting reserved for actual note-taking
4. **Maintained Undo/Redo**: Full undo/redo support across all text entry
5. **Clean Separation**: Clear distinction between performance content (plain) and notes (rich)

## Testing Checklist

- [ ] Setlist Builder Script editing with undo/redo
- [ ] Setlist Builder Notes with rich text formatting
- [ ] Quick Bit capture with dictation
- [ ] Loose Bit editing with undo/redo
- [ ] Finished Bit editing with undo/redo
- [ ] Show Notes performance notes with rich text
- [ ] Undo/redo toolbar appears correctly with keyboard
- [ ] Migration from old Performance string notes (if applicable)
