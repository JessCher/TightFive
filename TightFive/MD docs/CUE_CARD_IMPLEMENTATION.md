# Cue Card Mode Implementation Guide

## Overview

This document describes the **Cue Card Mode** architecture — a new Stage Mode implementation that replaces continuous teleprompter scrolling with a card-based system using dual-phrase speech recognition.

## Problem Statement

The original teleprompter-style Stage Mode had fundamental issues:
- **Low recognition confidence** across entire scripts (too much context)
- **Frequent desynchronization** between scroll position and actual speaking
- **Constant manual intervention** required during performance
- Recognition trying to solve "where in continuous text?" instead of "which block are we in?"

## Solution: Cue Card Architecture

### Core Concept

Display **ONE script block at a time** as a full-screen card, using bounded speech recognition to detect when the performer has finished that block and is ready for the next.

### Key Principles

1. **Discrete Blocks**: Each script block becomes an isolated cue card
2. **Dual-Phrase Recognition**: 
   - **Anchor phrase** (first ~10-20 words): Confirms performer is IN this block
   - **Exit phrase** (last ~10-20 words): Triggers transition to NEXT block
3. **Bounded Context**: Speech recognition only focuses on current card's phrases
4. **Natural Performance Flow**: Matches how comedians think in discrete bits
5. **Graceful Degradation**: Manual swipe/tap always works if recognition fails

## Architecture Components

### 1. CueCard (`CueCard.swift`)

**Purpose**: Represents a single script block with recognition metadata.

```swift
struct CueCard: Identifiable, Equatable {
    let id: UUID
    let blockId: UUID
    let blockIndex: Int
    let fullText: String          // Full content displayed on card
    let anchorPhrase: String      // First ~15 words
    let exitPhrase: String        // Last ~15 words
    let normalizedWords: [String] // For fuzzy matching
    let normalizedAnchor: [String]
    let normalizedExit: [String]
}
```

**Key Methods**:
- `extractCards(from setlist:)` → Extract all cards from setlist blocks
- `matchesExitPhrase(_:threshold:)` → Check if transcript matches exit phrase
- `matchesAnchorPhrase(_:threshold:)` → Check if transcript matches anchor phrase

**Recognition Algorithm**:
- Sliding window fuzzy matching
- Configurable confidence threshold (default 0.6 = 60%)
- Normalized text comparison (case/diacritics insensitive)

### 2. CueCardEngine (`CueCardEngine.swift`)

**Purpose**: Manages cue card state, audio recording, and speech recognition.

```swift
@MainActor
final class CueCardEngine: ObservableObject {
    @Published private(set) var cards: [CueCard]
    @Published private(set) var currentCardIndex: Int
    @Published private(set) var isRunning: Bool
    @Published private(set) var isListening: Bool
    @Published private(set) var partialTranscript: String
    @Published private(set) var exitPhraseConfidence: Double
    @Published private(set) var anchorPhraseConfidence: Double
}
```

**State Machine**:
1. Display card N
2. Listen for exit phrase of card N
3. When detected → advance to card N+1
4. Optionally validate anchor phrase of card N+1
5. Repeat until end

**Features**:
- High-quality audio recording (M4A AAC-LC, 48kHz, 96kbps)
- On-device speech recognition (when available)
- Contextual hints per card (improves recognition)
- Auto-advance with configurable debouncing
- Manual navigation fallback (swipe/tap)
- Analytics tracking (confidence, transitions, timing)

### 3. StageModeViewCueCard (`StageModeViewCueCard.swift`)

**Purpose**: SwiftUI interface for cue card performance mode.

**UI Features**:
- **Full-screen cards** with dynamic font scaling
- **Auto-scaling text**: Longer bits get smaller font to fit without scrolling
- **Swipe gestures**: Left = next, Right = previous
- **Progress indicator**: Shows "X / Y" cards and progress bar
- **Phrase feedback bar**: Real-time anchor/exit confidence (optional)
- **Auto/Manual toggle**: Enable/disable automatic advancement
- **Recording indicator**: Timer and audio level visualization

**Font Scaling Logic**:
```swift
- < 30 words:  48pt (very large)
- 30-60 words: 38pt (large)  
- 60-100 words: 32pt (medium)
- > 100 words:  28pt (readable but fits)
```

### 4. Settings Integration

**RunModeSettingsStore** additions:
```swift
@AppStorage("cueCard_autoAdvance") var cueCardAutoAdvance: Bool = true
@AppStorage("cueCard_showPhraseFeedback") var cueCardShowPhraseFeedback: Bool = true
@AppStorage("cueCard_exitPhraseThreshold") var cueCardExitPhraseThreshold: Double = 0.6
```

**RunModeSettingsView** additions:
- "Cue Card Settings" section
- Auto-advance toggle
- Phrase feedback visibility toggle
- Exit phrase sensitivity slider (40%-90%)

## Performance Flow

### Typical Performance Session

```
1. Performer enters Stage Mode → Cue Card mode
2. Card 1 appears (full text visible)
3. Performer begins speaking Card 1
4. System confirms: "Anchor phrase detected" (optional validation)
5. Performer continues through Card 1
6. Performer speaks exit phrase (last 15 words of Card 1)
7. System detects exit phrase → Card 2 appears instantly
8. Performer sees Card 2's anchor phrase and begins speaking it
9. System confirms: "Anchor phrase detected"
10. Repeat until final card
```

### Recognition Timing

**Why Exit Phrase Triggers Next Card**:
- Comedian reads entire current block
- Exit phrase = end of current material
- New card appears immediately
- Comedian sees next card's anchor phrase (what to say next)
- No lag, no guessing, natural flow

### Fallback Controls

Always available regardless of recognition:
- **Swipe left/right**: Navigate cards manually
- **Tap chevrons**: Precise navigation
- **Auto toggle**: Disable auto-advance entirely

## Integration with Existing System

### Compatibility

The cue card system integrates cleanly with existing architecture:

1. **Uses same Setlist/ScriptBlock model**: No schema changes
2. **Same Performance recording**: Compatible audio recording format
3. **Same PerformanceAnalytics**: Generates insights like teleprompter mode
4. **Same permissions flow**: Speech + microphone permissions

### Migration Path

Old Stage Mode (`StageModeView.swift`) remains intact. New mode is:
- Separate file: `StageModeViewCueCard.swift`
- Separate engine: `CueCardEngine.swift`
- Additive settings in existing store

To switch between modes:
```swift
// Option 1: Replace StageModeView entirely
// Rename StageModeView → StageModeViewTeleprompter
// Rename StageModeViewCueCard → StageModeView

// Option 2: Mode selector in settings
enum StageModeType {
    case teleprompter  // Original scroll mode
    case cueCard       // New card mode
}
```

## Tuning & Configuration

### Phrase Length

Current: **15 words** for both anchor and exit phrases.

**Adjustment considerations**:
- Shorter (8-10 words): More sensitive, may trigger early
- Longer (20-25 words): More precise, but harder to match perfectly

**Location in code**: `CueCard.extractPhrases(from:)` → `targetWords` constant

### Recognition Threshold

Current: **0.6 (60% match required)**

**User-configurable** via Settings → Cue Card Settings → Exit Phrase Sensitivity

- Lower (0.4-0.5): More sensitive, may advance too early
- Higher (0.7-0.9): More precise, may require perfect delivery

### Debounce Period

Current: **1.5 seconds** between exit phrase detections

Prevents accidental double-triggers when reviewing the same material.

**Location in code**: `CueCardEngine.exitPhraseDebounce`

## Analytics & Insights

### Tracked Metrics

1. **Automatic transition rate**: % of card transitions triggered by speech
2. **Recognition confidence**: Average confidence per card
3. **Transition timestamps**: When each card change occurred
4. **Manual vs automatic**: Fallback usage patterns

### Post-Performance Insights

Stored in `Performance.insights` as `[PerformanceAnalytics.Insight]`:

```swift
[
    "Automatic transitions: 8/10 (80%)",
    "Average recognition confidence: 72%"
]
```

These can be enhanced with structured analytics later.

## Best Practices

### For Performers

1. **Speak clearly through exit phrases**: Don't trail off at the end of bits
2. **Trust the system**: Let it auto-advance when working well
3. **Use manual controls as needed**: No shame in swiping during improv
4. **Adjust sensitivity**: Find your sweet spot in settings

### For Developers

1. **Keep phrase extraction simple**: Resist over-engineering
2. **Prioritize graceful degradation**: Manual controls must always work
3. **Log recognition events**: Debug with real performance data
4. **Respect battery life**: Recognize efficiently, record responsibly

## Testing Recommendations

### Unit Tests

1. `CueCard.extractPhrases()` with various text lengths
2. `CueCard.matchesExitPhrase()` with partial/full matches
3. Phrase normalization edge cases

### Integration Tests

1. Setlist with mixed block types → card extraction
2. Empty/single-word blocks → graceful handling
3. Very long blocks → font scaling verification

### Performance Tests

1. 20+ card setlist → smooth transitions
2. Recognition confidence under various noise conditions
3. Battery impact during 30+ minute performance

## Future Enhancements

### Potential Improvements

1. **Visual cues for upcoming transitions**: Subtle highlight when exit phrase approaches
2. **Mid-card checkpoints**: Optional anchor phrases in middle of long bits
3. **Confidence-based font adjustments**: Dim text that wasn't spoken yet
4. **Rehearsal mode**: Practice transitions without recording
5. **Custom phrase markers**: Let users define anchor/exit phrases manually
6. **Multi-language support**: Recognition in languages besides English

### Advanced Features

1. **Crowd response detection**: Pause auto-advance on laughter
2. **Pace adaptation**: Adjust timing based on delivery speed
3. **Smart reordering**: Suggest different card order based on performance data
4. **Setlist branching**: "If crowd is hot, go to card X, else skip"

## Troubleshooting

### "Exit phrase not detecting"

**Causes**:
- Speaking too fast/unclear at end of bit
- Threshold too high
- Background noise interference

**Solutions**:
- Lower sensitivity in settings
- Speak exit phrase more clearly
- Use manual swipe as fallback

### "Advancing too early"

**Causes**:
- Threshold too low
- Repeating similar phrases mid-bit

**Solutions**:
- Raise sensitivity threshold
- Increase debounce period
- Toggle auto-advance off during improv sections

### "Cards showing blank text"

**Causes**:
- Empty script blocks
- RTF decoding issues

**Solutions**:
- Verify script content in setlist editor
- Check that assignments are not empty

## Files Changed/Created

### New Files

- `CueCard.swift` - Card data model with recognition
- `CueCardEngine.swift` - State management and speech engine
- `StageModeViewCueCard.swift` - SwiftUI interface

### Modified Files

- `RunModeSettingsStore.swift` - Added cue card settings
- `RunModeSettingsView.swift` - Added cue card settings UI
- `PerformanceAnalytics.swift` - Added convenience Insight initializer

### Unchanged Files

- `StageModeView.swift` - Original teleprompter mode intact
- `Setlist.swift` - No schema changes
- `ScriptBlock.swift` - No schema changes
- `Performance.swift` - Compatible with existing structure

## Conclusion

The Cue Card architecture provides:
- **Higher recognition confidence** through bounded context
- **Natural performance flow** matching comedian thinking
- **Reliable fallbacks** when recognition struggles
- **Clean integration** with existing system

This approach transforms Stage Mode from a synchronization battle into a glanceable performance aid that stays out of the way until you need it.
