# Text Editor Architecture Visual Guide

```
┌─────────────────────────────────────────────────────────────────────┐
│                         TIGHTFIVE TEXT EDITORS                      │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                      PERFORMANCE CONTENT                             │
│                      (Plain Text Only)                               │
└─────────────────────────────────────────────────────────────────────┘

    ┌───────────────────────────────────────────────────────────┐
    │  SETLIST BUILDER - SCRIPT TAB                             │
    │  ────────────────────────────────────────────────────     │
    │                                                            │
    │  Freeform Blocks:           Bit Assignments:              │
    │  ┌────────────────┐         ┌────────────────┐            │
    │  │ PlainTextEditor│         │ PlainTextEditor│            │
    │  │   (Undo/Redo)  │         │   (Undo/Redo)  │            │
    │  └────────────────┘         └────────────────┘            │
    │                                                            │
    │  Storage: RTF → Display: Plain → Edit: Plain → Save: RTF  │
    └───────────────────────────────────────────────────────────┘

    ┌───────────────────────────────────────────────────────────┐
    │  QUICK BIT EDITOR                                          │
    │  ────────────────────────────────────────────────────     │
    │                                                            │
    │  ┌────────────────────────────────┐                       │
    │  │     PlainTextEditor            │                       │
    │  │     with Dictation             │                       │
    │  │     (Undo/Redo)                │                       │
    │  └────────────────────────────────┘                       │
    │                                                            │
    │  Storage: String → Edit: String → Save: String            │
    └───────────────────────────────────────────────────────────┘

    ┌───────────────────────────────────────────────────────────┐
    │  LOOSE & FINISHED BITS                                     │
    │  ────────────────────────────────────────────────────     │
    │                                                            │
    │  ┌────────────────────────────────┐                       │
    │  │   UndoableTextEditor           │                       │
    │  │   (Plain Text)                 │                       │
    │  │   (Undo/Redo)                  │                       │
    │  └────────────────────────────────┘                       │
    │                                                            │
    │  Storage: String → Edit: String → Save: String            │
    └───────────────────────────────────────────────────────────┘


┌─────────────────────────────────────────────────────────────────────┐
│                        NOTE-TAKING CONTENT                           │
│                    (Rich Text Formatting)                            │
└─────────────────────────────────────────────────────────────────────┘

    ┌───────────────────────────────────────────────────────────┐
    │  SETLIST BUILDER - NOTES TAB                               │
    │  ────────────────────────────────────────────────────     │
    │                                                            │
    │  Auxiliary Notes (delivery ideas, reminders):             │
    │  ┌────────────────────────────────┐                       │
    │  │    RichTextEditor              │                       │
    │  │    ┌─────────────────────┐     │                       │
    │  │    │ B I U S • 1. ☐      │     │                       │
    │  │    │ Color   A+ A-       │     │                       │
    │  │    └─────────────────────┘     │                       │
    │  │    (Full Formatting Toolbar)   │                       │
    │  │    (Undo/Redo)                 │                       │
    │  └────────────────────────────────┘                       │
    │                                                            │
    │  Storage: RTF → Edit: RTF → Save: RTF                     │
    └───────────────────────────────────────────────────────────┘

    ┌───────────────────────────────────────────────────────────┐
    │  SHOW NOTES - PERFORMANCE NOTES                            │
    │  ────────────────────────────────────────────────────     │
    │                                                            │
    │  Post-show reflections and detailed notes:                │
    │  ┌────────────────────────────────┐                       │
    │  │    RichTextEditor              │                       │
    │  │    ┌─────────────────────┐     │                       │
    │  │    │ B I U S • 1. ☐      │     │                       │
    │  │    │ Color   A+ A-       │     │                       │
    │  │    └─────────────────────┘     │                       │
    │  │    (Full Formatting Toolbar)   │                       │
    │  │    (Undo/Redo)                 │                       │
    │  └────────────────────────────────┘                       │
    │                                                            │
    │  Storage: RTF → Edit: RTF → Save: RTF                     │
    └───────────────────────────────────────────────────────────┘


┌─────────────────────────────────────────────────────────────────────┐
│                    UNDO/REDO IMPLEMENTATION                          │
└─────────────────────────────────────────────────────────────────────┘

    All Editors Share Same Architecture:
    
    ┌────────────────────────────────────────────────┐
    │  User Types                                    │
    │      ↓                                         │
    │  Burst Detection (300ms window)                │
    │      ↓                                         │
    │  Capture Previous State                        │
    │      ↓                                         │
    │  Register Undo Action                          │
    │      ↓                                         │
    │  Update SwiftUI Binding                        │
    │      ↓                                         │
    │  Keyboard Toolbar Shows Undo/Redo Buttons      │
    └────────────────────────────────────────────────┘

    Toolbar Visibility:
    ┌────────────────────────────────────────────────┐
    │  @ObservedObject var keyboard = TFKeyboardState│
    │                                                 │
    │  .toolbar {                                    │
    │      if keyboard.isVisible {                   │
    │          TFUndoRedoControls() ✓                │
    │      }                                         │
    │  }                                             │
    └────────────────────────────────────────────────┘


┌─────────────────────────────────────────────────────────────────────┐
│                    DATA TYPE COMPARISON                              │
└─────────────────────────────────────────────────────────────────────┘

    PlainTextEditor              RichTextEditor
    ───────────────             ───────────────
    @Binding text: String       @Binding rtfData: Data
    No formatting toolbar       Full formatting toolbar
    Smart typing ✓              Smart typing ✓
    Undo/redo ✓                 Undo/redo ✓
    Autocorrection ✓            Autocorrection ✓
    
    Use for:                    Use for:
    - Scripts                   - Notes
    - Bits                      - Reflections
    - Performance content       - Planning docs


┌─────────────────────────────────────────────────────────────────────┐
│                      CONVERSION HELPERS                              │
└─────────────────────────────────────────────────────────────────────┘

    Plain Text → RTF:
    ─────────────────
    let rtf = TFRTFTheme.body(plainText)
    
    RTF → Plain Text:
    ────────────────
    let plain = NSAttributedString.fromRTF(rtfData)?.string ?? ""
    
    Used when:
    - Script blocks: Store RTF, edit plain
    - Export/share: Convert RTF to plain for sharing
```

## Summary

**Performance Content (Plain):**
- Setlist Builder Script blocks
- Quick Bit Editor
- Loose & Finished Bits
- ✅ Undo/Redo: Full support

**Note-Taking Content (Rich):**
- Setlist Builder Notes tab
- Show Notes Performance notes
- ✅ Undo/Redo: Full support

**Result:** Clean separation between performance content and note-taking, with undo/redo preserved everywhere.
