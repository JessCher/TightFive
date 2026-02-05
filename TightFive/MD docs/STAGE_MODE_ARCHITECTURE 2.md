# Stage Mode Architecture - Complete Overview

## View Hierarchy

```
SetlistBuilderView
    │
    ├─► StageModeView (Wrapper)
    │       │
    │       ├─► StageModeViewCueCard (for Modular mode)
    │       │       └─► CueCardEngine (records + recognizes)
    │       │
    │       └─► StageModeViewScript (for Traditional mode)
    │               └─► CueCardEngine (records + static script)
    │
    └─► RunModeView (Run Through)
            │
            ├─► StageRehearsalView ✨ NEW
            │       └─► StageRehearsalEngine (no recording, enhanced analytics)
            │
            ├─► Script View
            └─► Teleprompter View
```

## File Relationships

### Core Models
```
CueCard.swift
    ├─ extractCards(from: Setlist) → [CueCard]
    ├─ matchesAnchorPhrase(_:) → (matches: Bool, confidence: Double)
    └─ matchesExitPhrase(_:) → (matches: Bool, confidence: Double)

ScriptBlock (enum)
    ├─ .freeform(id, rtfData)
    └─ .bit(id, assignmentId)

Setlist
    ├─ scriptBlocks: [ScriptBlock]
    ├─ customCueCards: [CueCard]
    ├─ currentScriptMode: ScriptMode (.modular or .traditional)
    └─ hasScriptContent: Bool
```

### Engines

```
CueCardEngine.swift
    Purpose: Stage Mode performance (RECORDING)
    Features:
        ✅ Voice recognition
        ✅ Auto-advance
        ✅ Audio recording to file
        ✅ Basic analytics
        ✅ Creates Performance record
    Used by:
        - StageModeViewCueCard
        - StageModeViewScript

StageRehearsalEngine.swift ✨ NEW
    Purpose: Stage Mode practice (NO RECORDING)
    Features:
        ✅ Voice recognition
        ✅ Auto-advance
        ✅ Audio level monitoring
        ✅ Enhanced analytics
        ✅ Per-card tracking
        ✅ Smart recommendations
        ❌ No audio recording
        ❌ No Performance record
    Used by:
        - StageRehearsalView
```

### Views

```
StageModeViewCueCard.swift
    Purpose: Performance mode with cue cards
    Features:
        - One card at a time
        - Auto-advance on exit phrase
        - Manual swipe fallback
        - Records audio
        - Creates Performance
    Settings: CueCardSettingsStore

StageModeViewScript.swift
    Purpose: Performance mode with static script
    Features:
        - Scrollable full script
        - No cue cards
        - Records audio
        - Creates Performance
    Settings: StageModeScriptSettings

StageRehearsalView.swift ✨ NEW
    Purpose: Practice mode with enhanced feedback
    Features:
        - Same UI as Stage Mode
        - Large phrase detection cards
        - Real-time confidence scores
        - Audio level warnings
        - Detailed analytics on exit
        - No recording
        - No performance saved
    Settings: CueCardSettingsStore (respects all)
```

### Settings Stores

```
CueCardSettingsStore.swift
    Scope: Stage Mode (cue cards)
    Settings:
        - autoAdvanceEnabled
        - showPhraseRecognitionFeedback
        - fontSize (24-56)
        - lineSpacing (4-24)
        - textColor (.white/.yellow/.green)
        - exitSensitivity (0.3-0.9)
        - anchorSensitivity (0.3-0.9)
        - animationsEnabled
        - transitionStyle (.slide/.fade/.scale)
        - stageModeType (.cueCards/.script)
    Used by:
        - StageModeViewCueCard
        - StageRehearsalView ✨

StageModeScriptSettings.swift
    Scope: Stage Mode (script)
    Settings:
        - fontSize (24-56)
        - lineSpacing (4-24)
        - textColor (.white/.yellow/.green)
    Used by:
        - StageModeViewScript

RunModeSettingsStore.swift
    Scope: Run Through mode
    Settings:
        - defaultMode (.script/.teleprompter)
        - defaultFontSize
        - defaultSpeed
        - scriptFontColor
        - teleprompterFontColor
        - timerColor
        - timerSize
        - autoStartTimer
        - autoStartTeleprompter
        - contextWindowColor
    Used by:
        - RunModeView
```

## Data Flow

### Stage Mode Performance Flow

```
User taps "Stage Mode" in SetlistBuilderView
    ↓
StageModeView (wrapper) determines mode
    ↓
┌─────────────────────────┬──────────────────────────┐
│ Modular Mode            │ Traditional Mode         │
│ StageModeViewCueCard    │ StageModeViewScript      │
└─────────────────────────┴──────────────────────────┘
    ↓                          ↓
CueCardEngine starts       CueCardEngine starts
    ↓                          ↓
Extracts cards from        Displays full script
setlist.scriptBlocks           ↓
    ↓                      Listens (minimal use)
Displays one card              ↓
    ↓                      Records audio
Listens for phrases            ↓
    ↓                      Saves Performance
Auto-advances on exit          ↓
    ↓                      Shows save confirmation
Records audio                  ↓
    ↓                      Dismisses
Saves Performance
    ↓
Shows save confirmation
    ↓
Dismisses
```

### Stage Rehearsal Flow ✨ NEW

```
User opens RunModeView
    ↓
Taps "Stage Rehearsal" floating button
    ↓
StageRehearsalView launches
    ↓
StageRehearsalEngine.start()
    ↓
Extracts cards from setlist.scriptBlocks
    ↓
Displays first card
    ↓
┌──────────────────────────────────────┐
│ REHEARSAL SESSION                    │
│                                      │
│ User performs material               │
│    ↓                                 │
│ Engine listens for phrases           │
│    ↓                                 │
│ Updates confidence scores            │
│    ↓                                 │
│ Shows large feedback cards           │
│    ↓                                 │
│ Monitors audio levels                │
│    ↓                                 │
│ Tracks per-card analytics            │
│    ↓                                 │
│ Auto-advances on exit phrase         │
│    ↓                                 │
│ Records transition (auto/manual)     │
│    ↓                                 │
│ Continues to next card...            │
└──────────────────────────────────────┘
    ↓
User taps X to exit
    ↓
Shows exit confirmation
    ↓
User taps "View Analytics"
    ↓
Engine.stop() returns RehearsalAnalytics
    ↓
Displays analytics overlay
    │
    ├─ Summary stats
    ├─ Audio quality
    ├─ Recognition performance
    ├─ Problem cards
    └─ Recommendations
    ↓
User taps "Done"
    ↓
Dismisses (no performance saved)
    ↓
Returns to RunModeView
```

## Use Cases

### When to use StageModeViewCueCard
- ✅ Performing with Modular setlist
- ✅ Want automatic cue card flipping
- ✅ Need anchor/exit phrase recognition
- ✅ Recording actual performance
- ✅ Creating Show Notes

### When to use StageModeViewScript
- ✅ Performing with Traditional setlist
- ✅ Prefer static script view
- ✅ Recording actual performance
- ✅ Creating Show Notes
- ✅ Don't need automatic advancement

### When to use StageRehearsalView ✨
- ✅ Testing new material
- ✅ Verifying phrase recognition
- ✅ Checking audio levels
- ✅ Building confidence before show
- ✅ Fine-tuning settings
- ✅ Practicing auto-advance
- ❌ NOT for actual performance
- ❌ Does NOT create recording

### When to use RunModeView
- ✅ Practicing material
- ✅ Running through script
- ✅ Using teleprompter
- ✅ Timing your set
- ❌ No voice recognition
- ❌ No recording

## Key Differences

### CueCardEngine vs StageRehearsalEngine

| Feature | CueCardEngine | StageRehearsalEngine |
|---------|--------------|---------------------|
| **Purpose** | Actual performance | Practice/testing |
| **Audio Recording** | ✅ Saves .m4a file | ❌ No file created |
| **Performance Model** | ✅ Creates & saves | ❌ Nothing saved |
| **Show Notes** | ✅ Generated | ❌ Not applicable |
| **Analytics** | Basic insights | ✨ Enhanced, detailed |
| **Audio Monitoring** | Level only | ✨ Quality warnings |
| **Per-Card Tracking** | Minimal | ✨ Comprehensive |
| **Recommendations** | None | ✨ Smart suggestions |
| **Memory Usage** | High (audio buffer) | Low (no recording) |
| **Disk Usage** | Grows (recording) | Zero |

### Stage Mode vs Stage Rehearsal

| Aspect | Stage Mode | Stage Rehearsal |
|--------|-----------|----------------|
| **When** | During show | Before show |
| **Goal** | Record performance | Test & prepare |
| **Output** | Audio file + Performance | Analytics report |
| **Feedback** | Minimal | ✨ Enhanced |
| **Confidence Display** | Small overlay | ✨ Large cards |
| **Audio Warnings** | None | ✨ Real-time |
| **Problem Detection** | After (in insights) | ✨ During session |
| **Navigation** | Same (swipe/auto) | Same (swipe/auto) |
| **Settings** | Same | Same |

## Analytics Comparison

### CueCardEngine Insights (Basic)
```swift
[
    "Automatic transitions: 8/12 (67%)",
    "Average recognition confidence: 73%"
]
```

### StageRehearsalEngine Analytics (Enhanced) ✨
```swift
RehearsalAnalytics {
    // Session
    sessionDuration: 324.5 seconds
    
    // Transitions
    automaticTransitions: 8
    manualTransitions: 4
    automaticTransitionPercentage: 67%
    
    // Recognition
    totalTranscriptionsReceived: 145
    recognitionErrors: 2
    averageConfidence: 0.73
    
    // Per-card data (for all 12 cards)
    cardAnalytics: [
        0: {
            anchorDetections: 1 (conf: 0.85)
            exitDetections: 1 (conf: 0.91)
            recognitionAttempts: 12
            averageConfidence: 0.78
        },
        1: { ... },
        // ... etc
    ]
    
    // Audio
    averageAudioLevel: 0.42
    peakAudioLevel: 0.68
    audioLevelSamples: [412 samples]
    
    // Problems
    cardsWithProblems: [
        (2, ["Anchor phrase not detected"]),
        (5, ["Exit phrase not detected", "Low confidence (48%)"]),
        (7, ["Low confidence (42%)"])
    ]
    
    // Recommendations
    recommendations: [
        "🎤 Audio levels are good",
        "🔄 Most transitions were manual. Consider refining phrases.",
        "📝 Card 3: Anchor phrase not detected",
        "📝 Card 6: Exit phrase not detected, Low confidence"
    ]
}
```

## Entry Points Summary

```
SetlistBuilderView
    ├─ "Stage Mode" button → StageModeView
    │   └─ Actual performance, creates recording
    │
    ├─ "Run Through" button → RunModeView
    │   ├─ Script/Teleprompter practice
    │   └─ "Stage Rehearsal" button → StageRehearsalView ✨
    │       └─ Voice recognition practice, no recording
    │
    └─ "Stage Mode Settings" → CueCardSettingsView
        └─ Configure all stage mode preferences
```

## Settings Flow

```
CueCardSettingsStore (Singleton)
    ├─ Used by: StageModeViewCueCard
    ├─ Used by: StageRehearsalView ✨
    └─ Configured in: CueCardSettingsView
        (accessed from SetlistBuilderView menu)

User changes setting
    ↓
CueCardSettingsStore.shared updates
    ↓
UserDefaults persists automatically
    ↓
Both Stage Mode and Rehearsal see changes
```

## Permission Flow

```
User launches Stage Mode or Rehearsal
    ↓
Engine checks permissions
    ├─ Microphone (AVFoundation)
    └─ Speech Recognition (Speech framework)
    ↓
If needed, requests via Permissions helper
    ↓
User grants/denies
    ↓
Engine starts or shows error
```

## File System

### Stage Mode (Creates Files)
```
Documents/Recordings/
    └─ SetlistName_2024-01-15_14-30-00.m4a
        (48kHz, AAC, ~96kbps, grows during session)
```

### Stage Rehearsal (No Files)
```
(No files created)
Analytics exist only in memory during session
```

## Database

### Stage Mode (Creates Records)
```swift
Performance {
    id: UUID
    setlistId: UUID
    setlistTitle: String
    venue: String
    performedAt: Date
    audioFilename: String
    duration: TimeInterval
    fileSize: Int64
    insights: [PerformanceAnalytics.Insight]
}
```

### Stage Rehearsal (No Records)
```
(No Performance model created)
(No SwiftData persistence)
```

## UI Components

### Shared Between Stage Mode & Rehearsal
- Cue card text display
- Progress indicator
- Swipe gestures
- Timer display
- Settings integration

### Unique to Stage Rehearsal ✨
- Large phrase detection cards
- Audio level meter with percentage
- Audio quality warnings
- Analytics overlay
- Recommendations list
- Per-card problem breakdown

### Unique to Stage Mode
- Recording indicator (red dot)
- Save/Discard confirmation
- Performance save confirmation
- File size display

## Testing Strategy

### Unit Tests
```
CueCard_Tests
    - extractCards() produces correct count
    - matchesAnchorPhrase() returns valid confidence
    - matchesExitPhrase() returns valid confidence

CueCardEngine_Tests
    - configure() sets cards correctly
    - advanceToNextCard() updates index
    - stop() returns valid analytics

StageRehearsalEngine_Tests ✨
    - configure() initializes analytics
    - stop() returns RehearsalAnalytics
    - recordTransition() tracks correctly
    - recommendations generated appropriately
```

### Integration Tests
```
StageModeFlow_Tests
    - Full performance creates recording
    - Performance saved to SwiftData
    - Audio file exists on disk

RehearsalFlow_Tests ✨
    - No recording created
    - No performance saved
    - Analytics populated correctly
    - Recommendations relevant
```

### UI Tests
```
StageMode_UITests
    - Swipe advances cards
    - Auto-advance works
    - Exit saves performance

Rehearsal_UITests ✨
    - Button launches view
    - Phrase cards update
    - Audio warnings appear
    - Analytics display correctly
```

## Summary

The Stage Mode ecosystem now consists of:

1. **StageModeViewCueCard** - Performance with cue cards
2. **StageModeViewScript** - Performance with static script
3. **StageRehearsalView** ✨ - Practice/testing mode
4. **RunModeView** - Script practice (no voice)

All powered by:
- **CueCardEngine** - Recording + recognition
- **StageRehearsalEngine** ✨ - Recognition + analytics only

Configured by:
- **CueCardSettingsStore** - Stage Mode preferences
- **StageModeScriptSettings** - Script Mode preferences
- **RunModeSettingsStore** - Run Through preferences

This architecture provides comedians with:
- ✅ Multiple ways to practice material
- ✅ Comprehensive performance recording
- ✅ ✨ Risk-free testing environment
- ✅ Detailed analytics for improvement
- ✅ Flexible configuration options

**New addition (Stage Rehearsal)** fills the gap between "casual practice" (Run Through) and "actual performance" (Stage Mode), providing confidence-building preparation with actionable feedback.
