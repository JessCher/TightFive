# Edit Cue Card Phrases Feature - Implementation Guide

## Overview

Comedians can now fully customize the anchor and exit phrases used for voice-activated cue card transitions in Stage Mode. This works for both **Modular** and **Traditional** setlists, giving performers complete control over auto-advance triggers.

## Features Implemented

### 1. **EditCueCardPhrasesView**
A new dedicated editor for customizing cue card detection phrases:
- **Card-by-card editing**: Edit phrases for each cue card individually
- **Collapsible content preview**: See the full card content when needed
- **Default phrase display**: Shows auto-generated phrases with ability to override
- **Reset functionality**: Easily revert to default phrases per card
- **Unsaved changes tracking**: Warns before losing edits
- **Works for both modes**: Modular and Traditional setlists

### 2. **CueCard Model Updates**
Enhanced CueCard struct to support custom phrases:
- Added `customAnchorPhrase: String?` field
- Added `customExitPhrase: String?` field  
- Added `effectiveAnchorPhrase` computed property (uses custom if set, otherwise default)
- Added `effectiveExitPhrase` computed property
- Added `hasCustomPhrases` flag
- Updated factory method to load custom phrases from setlist

### 3. **Setlist Model Updates**
Added storage for custom phrase overrides:
- **For Modular**: `modularCustomPhrasesData: Data` field stores JSON-encoded dictionary mapping block UUIDs to custom phrases
- **For Traditional**: Existing `customCueCards` already supported custom phrases
- Added `CustomPhraseOverride` struct for type-safe phrase storage
- Added computed property `modularCustomPhrases` for easy access

### 4. **Data Flow**

#### Modular Setlists
```
Script Block (UUID) 
   ↓
Auto-generated anchor/exit phrases (default)
   ↓
Setlist.modularCustomPhrases[blockId] (optional overrides)
   ↓
CueCard with effective phrases
   ↓
CueCardEngine uses for voice recognition
```

#### Traditional Setlists
```
CustomCueCard
   ↓
Content + optional custom phrases
   ↓
CueCard with effective phrases
   ↓
CueCardEngine uses for voice recognition
```

## User Experience

### Accessing the Editor

**From SetlistBuilderView** (to be added):
1. Open a setlist
2. Tap the "Stage Mode" menu (•••)
3. Select "Edit Cue Card Phrases"

### Editing Phrases

1. **View all cards**: Scrollable list of all cue cards
2. **Expand card**: Tap header to see full content
3. **Edit phrases**:
   - **Anchor Phrase**: First ~15 words (what triggers "we're at this card")
   - **Exit Phrase**: Last ~15 words (what triggers "advance to next card")
4. **Customization indicators**:
   - "Custom phrases" badge when overrides exist
   - "Using default phrases" when no overrides
5. **Reset button**: Removes custom override, returns to default
6. **Save**: Persists changes to setlist

### Visual Design

- **Card number badges**: Yellow circles with card numbers
- **Phrase sections**: Clearly labeled with icons
  - Anchor: arrow.down.to.line (entry point)
  - Exit: arrow.right.to.line (exit point)
- **Text fields**: Multi-line with focus indicators
- **Preview**: Collapsible full content view
- **Instructions**: Helpful banner at top

## Technical Details

### Data Models

#### CustomPhraseOverride
```swift
struct CustomPhraseOverride: Codable {
    var anchorPhrase: String?  // nil = use default
    var exitPhrase: String?    // nil = use default
}
```

#### EditableCueCard
```swift
struct EditableCueCard: Identifiable {
    let id: UUID               // Block ID
    let content: String        // Full card text
    let anchorPhrase: String   // Default anchor
    let exitPhrase: String     // Default exit
    var customAnchorPhrase: String?  // Override
    var customExitPhrase: String?    // Override
    
    var effectiveAnchorPhrase: String  // What's actually used
    var effectiveExitPhrase: String    // What's actually used
    var hasCustomPhrases: Bool         // Any overrides?
}
```

### Storage

#### Modular Mode
- Stored in `Setlist.modularCustomPhrasesData` as JSON
- Maps `UUID` (block ID) → `CustomPhraseOverride`
- Survives script reordering (keyed by stable block ID)

#### Traditional Mode
- Stored in `CustomCueCard.anchorPhrase` and `exitPhrase`
- Already part of existing `Setlist.customCueCardsData`

### Persistence Flow

1. **Load**: EditCueCardPhrasesView reads from setlist on appear
2. **Edit**: User modifies phrases in UI
3. **Track changes**: `hasUnsavedChanges` flag updates
4. **Save**: Updates setlist model, saves to SwiftData
5. **Use**: CueCardEngine reads effective phrases when starting Stage Mode

### Key Methods

#### EditCueCardPhrasesView
- `loadEditableCards()`: Initializes editor state from setlist
- `loadFromModularSetlist()`: Loads modular blocks with custom phrases
- `loadFromTraditionalSetlist()`: Loads traditional cue cards
- `saveChanges()`: Persists edits to setlist
- `saveToModularSetlist()`: Updates modular custom phrases map
- `saveToTraditionalSetlist()`: Updates custom cue cards

#### CueCard Factory
- `extractCards(from:)`: Creates CueCards with custom phrase support
- `loadCustomPhrases(from:)`: Loads overrides from setlist
- Uses effective phrases for normalization

## Benefits

### For Comedians

1. **Precision Control**: Set exact trigger phrases for reliable auto-advance
2. **Adapt to Performance Style**: Customize phrases to match how YOU actually say the material
3. **Handle Variations**: Account for ad-libs, different phrasings, regional dialects
4. **Fix Recognition Issues**: Override problematic default phrases
5. **Works Everywhere**: Both modular and traditional setlists supported

### For Stage Mode

1. **Higher Accuracy**: Custom phrases can be more distinctive than defaults
2. **Fewer False Positives**: Tailor phrases to avoid accidental triggers
3. **Performer Confidence**: Knowing exactly what words trigger transitions
4. **Flexible Recognition**: Can lengthen/shorten phrases as needed
5. **Future-Proof**: Easy to update phrases after performing shows

## Example Use Cases

### Case 1: Short Default Phrase
**Problem**: Default phrase is only 5 words, not distinctive enough
**Solution**: Extend to 20 words for better recognition

### Case 2: Similar Phrasing
**Problem**: Two bits end with similar phrases, causing cross-triggering
**Solution**: Customize exit phrases to be more distinct

### Case 3: Ad-Lib Heavy
**Problem**: Comedian ad-libs differently each show
**Solution**: Set custom phrases to the consistent parts of the material

### Case 4: Accent/Dialect
**Problem**: Speech recognition struggles with certain words
**Solution**: Replace problematic words with phonetically clearer alternatives

### Case 5: Callback Bit
**Problem**: Callback phrase triggers wrong card
**Solution**: Customize anchor to focus on unique setup, not callback phrase

## Future Enhancements

Potential improvements:
1. **Bulk Edit**: Edit multiple cards at once
2. **Import from Performance**: Auto-generate phrases from actual recorded show transcript
3. **Phrase Testing**: Preview recognition before performing
4. **Phrase Suggestions**: ML-suggested optimal phrases based on transcript analysis
5. **Share Phrases**: Export/import custom phrase sets between setlists

## Integration Points

### Required Menu Addition

Add to SetlistBuilderView's Stage Mode menu:

```swift
Menu {
    // ... existing options ...
    
    Section {
        Button {
            showEditCueCardPhrases = true
        } label: {
            Label("Edit Cue Card Phrases", systemImage: "text.bubble")
        }
    }
}
```

And add the sheet:

```swift
.sheet(isPresented: $showEditCueCardPhrases) {
    EditCueCardPhrasesView(setlist: setlist)
}
```

### State Variable

```swift
@State private var showEditCueCardPhrases = false
```

## Testing Checklist

- [ ] Open editor for modular setlist
- [ ] View all generated cue cards
- [ ] Customize anchor phrase on first card
- [ ] Customize exit phrase on last card
- [ ] Reset a custom phrase
- [ ] Save changes
- [ ] Re-open editor, verify changes persisted
- [ ] Start Stage Mode, verify custom phrases used
- [ ] Test voice recognition with custom phrases
- [ ] Open editor for traditional setlist
- [ ] Customize phrases on traditional cue cards
- [ ] Save and verify traditional changes
- [ ] Test with empty setlist (shows empty state)

## Summary

This feature gives comedians **complete control** over voice-activated cue card transitions. By allowing custom anchor and exit phrases, performers can:

✅ Optimize recognition accuracy for their unique delivery style
✅ Work around speech recognition quirks
✅ Handle ad-libs and variations confidently
✅ Fix problematic default phrases
✅ Perform with greater confidence in auto-advance reliability

The implementation is **clean, persistent, and works seamlessly** with both modular and traditional setlists!
