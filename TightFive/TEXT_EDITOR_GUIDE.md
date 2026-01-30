# Text Editor Quick Reference

## When to Use Each Editor

### Use `PlainTextEditor` for:
- ✅ Script blocks in Setlist Builder (freeform and bits)
- ✅ Quick Bit capture
- ✅ Any performance content that doesn't need formatting
- ✅ Simple text entry with undo/redo support

```swift
import SwiftUI

PlainTextEditor(text: $myText, undoManager: undoManager)
    .frame(minHeight: 120)
```

### Use `RichTextEditor` for:
- ✅ Setlist Builder Notes tab (auxiliary notes, delivery ideas)
- ✅ Show Notes performance notes (post-show reflections)
- ✅ Any note-taking that benefits from formatting (bold, italic, lists, colors)

```swift
import SwiftUI

RichTextEditor(rtfData: $myRTFData, undoManager: undoManager)
    .frame(minHeight: 120)
```

### Use `UndoableTextEditor` for:
- ✅ Bit text editing (already in use for LooseBits and FinishedBits)
- ✅ Custom implementations where you need direct control

```swift
UndoableTextEditor(
    text: $bit.text,
    modelContext: modelContext,
    bit: bit,
    undoManager: undoManager
)
```

## Key Differences

| Feature | PlainTextEditor | RichTextEditor | UndoableTextEditor |
|---------|----------------|----------------|-------------------|
| **Formatting** | Plain text only | Full rich text | Plain text only |
| **Undo/Redo** | ✅ Full support | ✅ Full support | ✅ Full support |
| **Storage** | `String` | `Data` (RTF) | `String` |
| **Toolbar** | None | Rich formatting toolbar | None |
| **Smart typing** | ✅ Yes | ✅ Yes | ✅ Yes |
| **Use case** | Performance content | Note-taking | Custom bit editing |

## Data Conversion

### Plain Text ↔ RTF
```swift
// Plain to RTF
let rtf = TFRTFTheme.body(plainText)

// RTF to Plain
let plain = NSAttributedString.fromRTF(rtfData)?.string ?? ""
```

## Undo/Redo Toolbar

All editors support undo/redo. To show the toolbar when keyboard is visible:

```swift
.toolbar {
    ToolbarItem(placement: .topBarTrailing) {
        if keyboard.isVisible {
            TFUndoRedoControls()
        }
    }
}
```

Or use the convenience modifier:

```swift
.tfUndoRedoToolbar(isVisible: keyboard.isVisible)
```

## Best Practices

1. **Use plain text for performance content** - Comedians perform from plain text, not formatted documents
2. **Use rich text for notes** - Note-taking benefits from formatting for organization and emphasis
3. **Always pass undoManager** - Enables undo/redo support via toolbar or shake gesture
4. **Convert between formats carefully** - Always handle nil cases when converting RTF to plain text

## Common Patterns

### Editing Script Blocks
```swift
@State private var editText: String = ""
@Environment(\.undoManager) private var undoManager

// On edit start
editText = NSAttributedString.fromRTF(rtfData)?.string ?? ""

// Show editor
PlainTextEditor(text: $editText, undoManager: undoManager)

// On edit end
let rtf = TFRTFTheme.body(editText)
onEndEdit(rtf)
```

### Note-Taking
```swift
@Environment(\.undoManager) private var undoManager

RichTextEditor(rtfData: $notes, undoManager: undoManager)
    .onChange(of: notes) { _, _ in
        // Auto-save or mark as dirty
    }
```
