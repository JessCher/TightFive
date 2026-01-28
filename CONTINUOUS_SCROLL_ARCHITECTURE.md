# Continuous Scroll Architecture 🎭

## The Paradigm Shift

### Old Approach: "Voice-Driven Jumping" ❌
```
1. Wait for speech recognition
2. Match transcript to script line
3. Jump scroll to that line
4. Repeat

Result: Always lagging, feels reactive, "chasing" your speech
```

### New Approach: "Auto-Scroll with Voice Gating" ✅
```
1. Scroll continuously forward at speaking pace
2. Voice recognition confirms position
3. Pause when confidence drops (off-script/silent)
4. Gentle corrections when drift detected
5. Resume scrolling when back on track

Result: Proactive, smooth, feels like traditional teleprompter but smarter
```

## Architecture Overview

### Three-Layer Design

```
┌─────────────────────────────────────────────────────┐
│  StageModeView (UI Layer)                           │
│  - Displays current line                            │
│  - Handles user controls                            │
│  - Visualizes scroll state                          │
└─────────────────┬───────────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────────┐
│  VoiceAwareScrollController (Integration Layer)     │
│  - Bridges scroll engine and voice tracker          │
│  - Decides when to pause/resume/correct             │
└────────┬────────────────────────────┬────────────────┘
         │                            │
┌────────▼──────────────┐  ┌──────────▼────────────────┐
│ ContinuousScrollEngine│  │ TeleprompterScrollTracker │
│ - Auto-advances lines │  │ - Matches voice to script │
│ - Adapts to pace     │  │ - Calculates confidence   │
│ - Pauses on demand   │  │ - Finds current position  │
└───────────────────────┘  └───────────────────────────┘
```

## How It Works

### 1. Continuous Scrolling (Primary Motion)

The `ContinuousScrollEngine` continuously advances through your script:

- **Base Speed**: Calculated from average line length and target speaking rate (150 WPM)
- **Adaptive**: Speeds up if voice is consistently ahead, slows down if behind
- **Smooth**: Advances every ~2 seconds (configurable per line length)

**Philosophy**: We're a teleprompter first — always trying to move forward naturally.

### 2. Voice Recognition (Governor/Validator)

The `TeleprompterScrollTracker` analyzes your speech:

- **Matches** your words to script lines
- **Calculates confidence** (0.0 - 1.0) of the match
- **Reports position** where it thinks you are

**Philosophy**: Voice recognition validates and corrects, doesn't drive.

### 3. Integration Logic (Decision Maker)

The `VoiceAwareScrollController` combines both:

#### Auto Pause/Resume:
```swift
if voiceConfidence < 0.4 && scrolling {
    pause()  // You've gone off-script or silent
}

if voiceConfidence >= 0.5 && paused {
    resume()  // You're back on track
}
```

#### Speed Adaptation:
```swift
if voice consistently ahead by 1+ lines {
    speed up scroll by 20%
}

if voice consistently behind by 1+ lines {
    slow down scroll by 20%
}
```

#### Drift Correction:
```swift
if |drift| > 2 lines && confidence > 0.7 {
    hard correction: jump to voice position
}

if drift == 1 line && confidence > 0.6 {
    soft correction: nudge to voice position
}
```

## Key Features

### 🎯 Always Ahead of You (Barely)
The scroll tries to stay 0.5-1 line ahead, so you're always reading what comes next — like a traditional teleprompter.

### ⏸️ Automatic Pausing
- Confidence drops below 40% → scroll pauses
- Happens when:
  - You go off-script (crowd work, riffing)
  - You're silent (dramatic pause, listening)
  - Microphone issues

### ▶️ Automatic Resuming
- Confidence rises above 50% → scroll resumes
- No timeout, no manual intervention needed
- Picks up exactly where it left off

### 🐇🐢 Adaptive Speed
The system learns your pace in real-time:
- Speaking faster than expected? Scroll speeds up (max 2x)
- Speaking slower? Scroll slows down (min 0.5x)
- Tracks recent matches to detect trends
- Resets drift tracking after corrections

### 🎚️ Gentle Corrections
- Small drift (1 line): Gentle nudge, barely noticeable
- Large drift (2+ lines): Hard correction with haptic feedback
- High confidence required for corrections (prevents false positives)

### 🎪 Respects Anchor Phrases
Anchor phrases still work exactly as before:
- Instant jump to any section
- Bypasses normal scroll logic
- Scroll resumes from new position

## Visual Feedback

### New Indicators in Context Window:

**Confidence Dot:**
- 🟢 Green (75%+): Perfect voice match
- 🟡 Yellow (50-74%): Good match
- 🟠 Orange (32-49%): Searching
- ⚫ None (<32%): Off-script/silent

**Scroll State Icon:**
- 🔵 Cyan arrow down: Actively scrolling
- 🟠 Orange pause: Paused (low confidence)

**Border Glow:**
- Green: High confidence (70%+), locked on
- White: Normal operation

## Tuning Parameters

### In ContinuousScrollEngine.swift:

```swift
// Base speaking rate
private let baseWordsPerMinute: Double = 150

// Pause when confidence drops below this
private let pauseConfidenceThreshold: Double = 0.4

// Resume when confidence rises above this
private let resumeConfidenceThreshold: Double = 0.5

// Hard correction threshold
private let maxDriftLines: Int = 2

// Speed adaptation rate (0-1, higher = more responsive)
private let speedAdaptationRate: Double = 0.2
```

### Tuning Tips:

**If scrolling too fast:**
- Decrease `baseWordsPerMinute` (try 130-140)
- Increase `speedAdaptationRate` (try 0.3)

**If pausing too often:**
- Decrease `pauseConfidenceThreshold` (try 0.3)
- Decrease `resumeConfidenceThreshold` (try 0.4)

**If corrections too aggressive:**
- Increase `maxDriftLines` (try 3)
- Decrease `speedAdaptationRate` (try 0.1)

**If not correcting enough:**
- Decrease `maxDriftLines` (try 1)
- Increase `speedAdaptationRate` (try 0.3)

## Behavioral Scenarios

### Scenario 1: Normal Performance
```
You: "So I was at the store the other day..."
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Scroll: Smoothly advances through script
Voice:  🟢 85% confidence
State:  🔵 Scrolling
```

### Scenario 2: Crowd Work
```
You: "What's your name? Where are you from?..."
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Scroll: ⏸️ PAUSED (stays on line before crowd work)
Voice:  ⚫ 10% confidence (off-script)
State:  🟠 Paused

[30 seconds of ad-libbing...]

You: "Anyway, so like I was saying about airplanes..."
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Scroll: ▶️ RESUMED (instantly picks up)
Voice:  🟢 78% confidence (locked back on)
State:  🔵 Scrolling
```

### Scenario 3: Speaking Faster Than Expected
```
You: [Speaking quickly, staying on script]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Voice:  Consistently 1.5 lines ahead of scroll
System: 🐇 Detected! Speeding up scroll by 20%
Result: Scroll catches up, drift reduces to 0.5 lines
```

### Scenario 4: Lost Your Place
```
You: [Jump ahead 5 lines accidentally]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Voice:  🟢 85% confidence, 5 lines ahead
System: ⚠️ Large drift! Hard correction
Scroll: JUMPS to voice position
Result: [Haptic feedback] Back on track
```

## Advantages Over Old System

| Aspect | Old (Jump) | New (Continuous) |
|--------|------------|------------------|
| Feel | Reactive, chasing | Proactive, leading |
| Motion | Jumpy, jarring | Smooth, natural |
| Latency | 200-400ms perception | Near-instant (scroll already there) |
| Off-script | Keeps jumping around | Pauses cleanly |
| Return to script | Delays, hunts | Instant recognition |
| Visual | Distracting jumps | Calm, predictable |
| Cognitive load | "Where am I?" | "It's always right" |

## Implementation Notes

### Why @Observable for ContinuousScrollEngine?
Using `@Observable` macro (Swift 5.9+) for fine-grained reactivity:
- SwiftUI only re-renders when specific properties change
- More efficient than `@Published` for high-frequency updates
- Cleaner syntax, better performance

### Why Separate Tracker and Engine?
- **Separation of concerns**: Voice matching ≠ scroll control
- **Testability**: Can test each independently
- **Flexibility**: Can swap algorithms without breaking UI
- **Reusability**: Voice tracker can be used elsewhere

### Timer vs CADisplayLink?
Using `Timer` for scroll tick (0.1s intervals):
- ✅ Simpler, MainActor-friendly
- ✅ Doesn't need screen refresh rate
- ✅ Works when app backgrounded (recording continues)
- ❌ Less precise than CADisplayLink
- ❌ Not frame-synced

For this use case, Timer is sufficient (we're advancing every ~2 seconds, not 60fps).

## Testing Checklist

### Before Show:
- [ ] Verify auto-scroll starts after audio begins
- [ ] Speak first line, confirm scroll pauses on match
- [ ] Stay silent for 5 seconds, verify scroll pauses
- [ ] Resume speaking, verify scroll resumes
- [ ] Try anchor phrase, verify instant jump
- [ ] Toggle Auto/Manual mode, verify scroll stops/starts

### During Rehearsal:
- [ ] Watch confidence dot during normal flow (should be green)
- [ ] Watch scroll icon (should be cyan arrow most of the time)
- [ ] Do 30s of crowd work, verify orange pause icon
- [ ] Return to script, verify instant green + cyan resume
- [ ] Speak faster/slower, watch for speed adaptation logs

### Fine-Tuning:
- [ ] Check Xcode console for adaptation messages:
  - "🐇 Speeding up scroll" = you're outpacing it
  - "🐢 Slowing down scroll" = it's outpacing you
- [ ] Adjust `baseWordsPerMinute` to match your natural pace
- [ ] Adjust pause thresholds if too sensitive/insensitive

## Future Enhancements

### Phase 2 Ideas:
1. **Learn your specific pace** from recordings (ML model)
2. **Predict pauses** based on script punctuation
3. **Smooth acceleration/deceleration** instead of instant speed changes
4. **Pre-scroll sections** based on estimated section duration
5. **Multi-person support** (detect which performer is speaking)

### Advanced Features:
- Export performance metrics (pace, confidence over time)
- Replay mode (watch recording with scroll overlay)
- Practice mode (alerts when you deviate from script)
- Confidence heatmap (which lines had low confidence)

---

## Quick Start

1. **Load your setlist** in Stage Mode
2. **Start performance** — scroll begins automatically
3. **Speak naturally** — system adapts to your pace
4. **Look down anytime** — you'll see exactly where you are
5. **Go off-script freely** — scroll pauses, waits patiently
6. **Return to script** — scroll resumes instantly

**The teleprompter now works for you, not the other way around.** 🎭✨
