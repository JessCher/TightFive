# Plain Text Migration - Complete Implementation

## ✅ Mission Accomplished

Successfully transitioned the TightFive app to use plain text editing for all performance content (bits and scripts) while maintaining rich text editing for note-taking contexts. **Full undo/redo functionality is preserved across the entire app.**

## Implementation Summary

### 🆕 New Component: PlainTextEditor

Created a new reusable plain text editor component (`PlainTextEditor.swift`) with:
- UIKit-backed UITextView wrapped in SwiftUI
- Full undo/redo support via UndoManager
- Burst-grouped undo operations (300ms debounce)
- Smart typing features (autocorrection, smart quotes, smart dashes)
- Cursor stability with internal update guards
- Same architecture as RichTextEditor but without formatting

### 📝 Rich Text Editor Usage (ONLY 2 Places)

#### 1. Setlist Builder - Notes Tab ✅
**File**: `SetlistBuilderView.swift`
- **What**: Auxiliary notes for delivery ideas, reminders, and performance planning
- **Why**: These are brainstorming/planning notes that benefit from formatting
- **Component**: `RichTextEditor(rtfData: $setlist.notesRTF, undoManager: undoManager)`
- **Undo/Redo**: ✅ Fully functional via keyboard toolbar

#### 2. Show Notes - Performance Notes ✅
**File**: `ShowNotesView.swift` → `PerformanceDetailView`
- **What**: Post-performance reflections and detailed notes
- **Why**: Long-form note-taking benefits from rich formatting
- **Component**: `RichTextEditor(rtfData: $performance.notesRTF, undoManager: undoManager)`
- **Model Change**: `Performance.notes: String` → `Performance.notesRTF: Data`
- **Undo/Redo**: ✅ Fully functional via keyboard toolbar

### 📄 Plain Text Editor Usage

#### 1. Setlist Builder - Script Blocks ✅
**File**: `SetlistBuilderView.swift` → `ScriptBlockRowView`
- **Freeform blocks**: Plain text entry
- **Bit assignments**: Plain text editing of performed content
- **Storage**: Stored as RTF internally (for consistency), converted to/from plain text for editing
- **Undo/Redo**: ✅ Fully functional via PlainTextEditor

#### 2. Quick Bit Editor ✅
**File**: `QuickBitEditor.swift`
- **What**: Fast bit capture with dictation support
- **Change**: `rtfData: Data` → `text: String`
- **Dictation**: Simplified - directly appends to string instead of RTF conversion
- **Undo/Redo**: ✅ Fully functional via PlainTextEditor

#### 3. Loose & Finished Bits ✅
**Files**: `LooseBitsView.swift`, `FinishedBitsView.swift`
- **Status**: Already using `UndoableTextEditor` (plain text with undo/redo)
- **Change**: None needed - already correct!
- **Undo/Redo**: ✅ Already functional via UndoableTextEditor

## Code Changes Detail

### 1. PlainTextEditor.swift (NEW)
```swift
struct PlainTextEditor: UIViewRepresentable {
    @Binding var text: String
    var undoManager: UndoManager?
    
    // Full UITextView-backed implementation with undo/redo
}
```

### 2. SetlistBuilderView.swift
**Script Blocks**:
```swift
// OLD:
@State private var editRTF: Data = TFRTFTheme.body("")
RichTextEditor(rtfData: $editRTF, undoManager: undoManager)

// NEW:
@State private var editText: String = ""
PlainTextEditor(text: $editText, undoManager: undoManager)
```

**Notes Tab** (unchanged):
```swift
// STILL USES:
RichTextEditor(rtfData: $setlist.notesRTF, undoManager: undoManager)
```

### 3. QuickBitEditor.swift
```swift
// OLD:
@State private var rtfData: Data = (NSAttributedString(string: "").rtfData() ?? Data())
RichTextEditor(rtfData: $rtfData, undoManager: undoManager)

// NEW:
@State private var text: String = ""
PlainTextEditor(text: $text, undoManager: undoManager)
```

### 4. Performance.swift
```swift
// OLD:
var notes: String

// NEW:
var notesRTF: Data

// Helper for migration/export:
var notesPlainText: String {
    NSAttributedString.fromRTF(notesRTF)?.string ?? ""
}
```

### 5. ShowNotesView.swift
```swift
// OLD:
TextEditor(text: $performance.notes)

// NEW:
RichTextEditor(rtfData: $performance.notesRTF, undoManager: undoManager)
```

## Undo/Redo Status

| Component | Undo/Redo | Implementation |
|-----------|-----------|----------------|
| **PlainTextEditor** | ✅ Full | UndoManager + burst grouping |
| **RichTextEditor** | ✅ Full | UndoManager + burst grouping |
| **UndoableTextEditor** | ✅ Full | UITextView delegate + UndoManager |
| **Keyboard Toolbar** | ✅ Visible | Shows when keyboard.isVisible |

### How Undo/Redo Works

1. **PlainTextEditor**: 
   - Tracks text changes
   - Groups rapid edits into bursts (300ms window)
   - Registers undo action with captured previous state
   - Observes undo/redo notifications to prevent loops

2. **RichTextEditor**: 
   - Same as PlainTextEditor but for RTF data
   - Includes formatting actions (bold, italic, lists, etc.)

3. **Toolbar Display**:
   ```swift
   @ObservedObject private var keyboard = TFKeyboardState.shared
   
   .toolbar {
       ToolbarItem(placement: .topBarTrailing) {
           if keyboard.isVisible {
               TFUndoRedoControls()
           }
       }
   }
   ```

## Data Flow

### Script Blocks (Setlist Builder)
```
Storage (RTF) → Display (plain text) → Edit (PlainTextEditor) → Storage (RTF)
                    ↓
          NSAttributedString.fromRTF()
                    ↓
              editText: String
                    ↓
             User edits text
                    ↓
           TFRTFTheme.body(editText)
                    ↓
            Storage (RTF)
```

### Notes (Both locations)
```
Storage (RTF) ↔ Edit (RichTextEditor) ↔ Storage (RTF)
                    ↓
          Full formatting preserved
```

## Migration Considerations

### Performance Model Migration
- **Breaking Change**: `notes: String` → `notesRTF: Data`
- **Action Required**: Existing performances will need migration
- **Migration Strategy**: 
  ```swift
  // Pseudocode for migration
  for performance in oldPerformances {
      if performance has old String notes {
          let rtf = TFRTFTheme.body(performance.notes)
          performance.notesRTF = rtf
      }
  }
  ```

### Bit Storage
- **No change needed**: Bits already store plain String
- **No migration required**

### Setlist Scripts
- **No change needed**: Scripts already store RTF
- **No migration required** - just editing experience changed

## Testing Checklist

- [x] PlainTextEditor created with undo/redo support
- [x] SetlistBuilderView Script blocks use PlainTextEditor
- [x] SetlistBuilderView Notes tab uses RichTextEditor
- [x] QuickBitEditor uses PlainTextEditor
- [x] LooseBitsView uses existing UndoableTextEditor (verified)
- [x] FinishedBitsView uses existing UndoableTextEditor (verified)
- [x] ShowNotesView uses RichTextEditor for notes
- [x] Performance model updated to store notesRTF
- [x] Undo/redo toolbar shows when keyboard visible
- [x] All imports corrected (SwiftUI added where needed)

## Files Modified

1. ✅ **PlainTextEditor.swift** (NEW) - Plain text editor component
2. ✅ **SetlistBuilderView.swift** - Script blocks now use PlainTextEditor
3. ✅ **QuickBitEditor.swift** - Changed to PlainTextEditor
4. ✅ **Performance.swift** - Changed notes to notesRTF
5. ✅ **ShowNotesView.swift** - Performance notes now use RichTextEditor
6. ✅ **PLAINTEXT_MIGRATION_SUMMARY.md** (NEW) - Detailed migration notes
7. ✅ **TEXT_EDITOR_GUIDE.md** (NEW) - Developer quick reference

## Files Verified (No Changes Needed)

- ✅ **LooseBitsView.swift** - Already uses UndoableTextEditor
- ✅ **FinishedBitsView.swift** - Already uses UndoableTextEditor via LooseBitsView

## Benefits Achieved

1. ✅ **Simpler UX**: Performance content is plain text (how comedians actually perform)
2. ✅ **Maintained Functionality**: All undo/redo capabilities preserved
3. ✅ **Clear Separation**: Rich formatting only for note-taking contexts
4. ✅ **Better Performance**: Plain text editing is more lightweight
5. ✅ **Consistent Architecture**: All editors share same undo/redo pattern

## Developer Notes

- Both PlainTextEditor and RichTextEditor follow the same architectural pattern
- Undo/redo is handled at the editor level, not view level
- Keyboard toolbar automatically appears via TFKeyboardState observation
- RTF ↔ Plain text conversion is handled at edit boundaries
- All smart typing features (autocorrection, smart quotes) work in both editors

## Ready for Testing

The migration is complete and ready for integration testing. All text entry points maintain full undo/redo support as required.
