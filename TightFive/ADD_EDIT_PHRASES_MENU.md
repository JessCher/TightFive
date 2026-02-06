# Quick Setup: "Edit Cue Card Phrases" Implementation

## ✅ Already Implemented!

The menu option has been integrated into SetlistBuilderView. It intelligently shows the appropriate option based on script mode:

- **Traditional Mode**: Shows "Configure Cue Cards" (opens CustomCueCardEditorView)
- **Modular Mode**: Shows "Edit Cue Card Phrases" (opens EditCueCardPhrasesView)

## What Was Changed

### 1. State Variable (Line ~42)
```swift
@State private var showEditCueCardPhrases = false
```

### 2. Sheet Presentation (Lines ~85-93)
```swift
.sheet(isPresented: $showEditCueCardPhrases) {
    // Show appropriate editor based on script mode
    if setlist.currentScriptMode == .traditional {
        CustomCueCardEditorView(setlist: setlist)
    } else {
        EditCueCardPhrasesView(setlist: setlist)
    }
}
```

### 3. Menu Item (Lines ~410-417)
```swift
Button {
    showEditCueCardPhrases = true
} label: {
    if setlist.currentScriptMode == .traditional {
        Label("Configure Cue Cards", systemImage: "rectangle.stack")
    } else {
        Label("Edit Cue Card Phrases", systemImage: "text.bubble")
    }
}
```

## User Experience

### Traditional Mode
1. Open setlist in Traditional mode
2. Tap the "•••" menu (top right)
3. See "Configure Cue Cards" option
4. Tap to open CustomCueCardEditorView

### Modular Mode
1. Open setlist in Modular mode
2. Tap the "•••" menu (top right)
3. See "Edit Cue Card Phrases" option
4. Tap to open EditCueCardPhrasesView

## Benefits

✅ **Single menu option** - no confusion about which to use
✅ **Context-aware** - automatically shows the right editor
✅ **Consistent UX** - always in the same menu location
✅ **Smart routing** - one state variable controls both flows

## How It Works

```
User taps menu option
    ↓
showEditCueCardPhrases = true
    ↓
Sheet checks setlist.currentScriptMode
    ↓
Traditional? → CustomCueCardEditorView
Modular? → EditCueCardPhrasesView
    ↓
Appropriate editor appears
```

## Testing

Test both modes:

1. **Traditional Mode**:
   - Set setlist to Traditional
   - Menu shows "Configure Cue Cards"
   - Opens CustomCueCardEditorView
   - Can create/edit custom cue cards

2. **Modular Mode**:
   - Set setlist to Modular
   - Menu shows "Edit Cue Card Phrases"
   - Opens EditCueCardPhrasesView
   - Can customize anchor/exit phrases
## Result

Comedians now have seamless access to cue card phrase editing regardless of which script mode they're using! The interface adapts intelligently to show the right option and open the right editor. 🎭✨


