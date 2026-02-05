# Stage Rehearsal Fixes - Change Summary

## Issues Fixed

### 1. ✅ Over-Sensitivity (Cards Flipping Too Early)

**Problem:** 
The improved matching algorithm was TOO lenient. Even with stricter settings, cards were advancing when only halfway through the material because scattered word matches were triggering false positives.

**Root Cause:**
The algorithm was using `max(bagScore, sequenceScore, substringScore)` which meant if ANY strategy scored high (even just word bag matching), it would trigger. Word bag matching doesn't care about word order, so it could match exit phrases from scattered words in the middle of the card.

**Solution - Weighted Scoring:**

Changed from "best of three" to weighted combination with validation:

```swift
// Old (too lenient):
return max(bagScore, sequenceScore, substringScore)

// New (balanced):
let weightedScore = (bagScore * 0.3) + (sequenceScore * 0.4) + (substringScore * 0.3)

if sequenceScore > 0.5 || substringScore > 0.5 {
    return max(weightedScore, bestScore)  // Sequential/substring is reliable
} else if bagScore > 0.7 {
    return bagScore * 0.85  // Penalize bag-only matches
} else {
    return weightedScore
}
```

**Logic:**
- **Sequential and substring matching** = more reliable (order matters)
- **Word bag matching alone** = less reliable (could be scattered words)
- If sequential/substring scored well → trust the result
- If only bag matching scored well → penalize by 15%
- This prevents mid-card false positives while keeping flexibility

**Additional Strictness:**
1. **Increased word length threshold** for partial matches: 4 → 5 characters
2. **Increased similarity threshold** for partial matches: 70% → 80%
3. **Reduced consecutive word bonus**: 15% → 5%
4. **Raised default thresholds**: 
   - Exit: 0.45 → 0.55
   - Anchor: 0.40 → 0.45

**Expected Behavior Now:**
- ✅ Won't advance until you're near the end of the card
- ✅ Exit phrase detection is more precise
- ✅ Settings adjustments now work properly
- ✅ Natural speech still recognized (not too strict)

---

### 2. ✅ Rehearsal Auto-Starts (Should Wait for Play Button)

**Problem:**
Rehearsal mode started immediately when switching to the Rehearsal tab, which was unexpected and didn't give users time to prepare.

**Solution:**

Added play/pause functionality:

**New State Variables:**
```swift
@State private var isRehearsalActive = false  // Track if rehearsal has started
@State private var elapsedTime: TimeInterval = 0
@State private var isTimerRunning = false
@State private var timer: Timer?
```

**New Functions:**
```swift
private func startRehearsal() {
    // Starts engine + timer
}

private func pauseRehearsal() {
    // Pauses timer (keeps engine running)
}

private func toggleRehearsal() {
    if isTimerRunning {
        pauseRehearsal()
    } else {
        if !isRehearsalActive {
            startRehearsal()  // First time
        } else {
            startTimer()  // Resume
        }
    }
}
```

**UI Changes:**
- Timer display is now a button
- Shows ▶️ (play) when paused
- Shows ⏸️ (pause) when running
- Color: Gray when paused, Yellow when running
- Tap to start/pause

**User Flow:**
1. Switch to Rehearsal tab → Paused state
2. Tap timer button → Starts engine and timer
3. Tap again → Pauses timer
4. Tap again → Resumes timer

---

### 3. ✅ Analytics Overlay Too Large (Blocking Cue Card)

**Problem:**
The recognition feedback overlay (with ANCHOR/EXIT cards) was taking up too much space at the bottom, making it hard to read the cue card text.

**Solutions:**

#### A. Made Overlay More Compact

**Size Reductions:**
- Progress bar font: 14pt → 12pt
- Progress bar height: 6px → 5px
- Phrase card padding: 16px → 12px
- Phrase card font: 24pt → 20pt
- Phrase card border: 16px radius → 12px radius
- Phrase card stroke: 2px → 1.5px
- Phrase card scale animation: 1.05 → 1.03
- Confidence bar height: 4px → 3px
- Icon size: 8px → 6px
- Label font: 12pt → 10pt
- Swipe hint font: 12pt → 10pt
- Overall spacing: 16px → 12px

**Result:** ~40% smaller overlay

#### B. Added Solid Background

```swift
.background(
    LinearGradient(
        colors: [Color.black.opacity(0.95), Color.black],
        startPoint: .top,
        endPoint: .bottom
    )
)
```

This creates a dark gradient that:
- Clearly separates overlay from content
- Makes text readable against any background
- Subtle gradient looks better than flat color

#### C. Scaled Down Cue Card Text in Rehearsal

```swift
private func calculateFontSize(for card: CueCard) -> CGFloat {
    let baseSize = CGFloat(settings.fontSize)
    let textLength = card.fullText.count
    
    // More aggressive scaling for rehearsal mode
    if textLength < 200 {
        return baseSize * 1.0    // Was 1.2
    } else if textLength > 800 {
        return baseSize * 0.6    // Was 0.7
    } else {
        return baseSize * 0.85   // Was 1.0
    }
}
```

**Rationale:**
- Rehearsal mode needs more screen space for feedback
- Actual Stage Mode can use larger text
- 85% of base size still very readable
- Longer content scales down more aggressively

#### D. Increased Bottom Spacing

```swift
// In cue card content:
Spacer(minLength: 350)  // Was 200
```

This ensures the cue card text scrolls well above the overlay, preventing any overlap.

#### E. Removed Extra Bottom Padding

```swift
// Old:
recognitionFeedbackOverlay
    .padding(.bottom, 40)  // ❌ Removed

// New:
recognitionFeedbackOverlay  // Sits at bottom naturally
```

The overlay now sits flush at the bottom with internal padding only.

---

## Visual Comparison

### Before:
```
┌─────────────────────────────┐
│  [X]    5:24     REHEARSAL  │ ← Top bar
├─────────────────────────────┤
│                             │
│   Cue card text here        │
│   (normal size)             │ ← Cue card (blocked)
│                             │
│ ╔═══════════════════════╗  │
│ ║ Progress: 5/12        ║  │
│ ║                       ║  │
│ ║ ┌──────────────────┐ ║  │
│ ║ │  ANCHOR    EXIT  │ ║  │ ← Large overlay
│ ║ │  85%       92%   │ ║  │   (blocking text)
│ ║ └──────────────────┘ ║  │
│ ╚═══════════════════════╝  │
└─────────────────────────────┘
```

### After:
```
┌─────────────────────────────┐
│  [X]  ▶️ 0:00    REHEARSAL  │ ← Top bar (play button)
├─────────────────────────────┤
│                             │
│   Cue card text here        │
│   (scaled to 85%)           │
│                             │ ← Cue card (visible)
│                             │
│                             │
│                             │
│▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│ ← Solid gradient
│ 5/12 ███████░░░░░░        │   background
│ ┌──────────┬──────────┐   │
│ │ ANCHOR   │  EXIT    │   │ ← Compact overlay
│ │   85%    │   92%    │   │   (more space)
│ └──────────┴──────────┘   │
└─────────────────────────────┘
```

---

## Testing Recommendations

### 1. Test Sensitivity
- Go to Rehearsal mode
- Click play button
- Speak your material naturally
- Should NOT advance until you're near the end
- If advancing too early: Increase exit sensitivity in settings
- If not advancing: Decrease exit sensitivity in settings

### 2. Test Play/Pause
- Switch to Rehearsal tab → Should be paused
- Click timer → Should start (yellow, playing)
- Click timer → Should pause (gray, paused)
- Click timer → Should resume (yellow, playing)

### 3. Test Overlay Size
- Check that cue card text is clearly visible
- Overlay should not block important text
- Background should be solid dark gradient
- Confidence cards should be compact but readable

### 4. Test Font Scaling
- Try short cards (<200 chars) → Should be base size
- Try long cards (>800 chars) → Should be smaller
- Try medium cards → Should be 85% of base

---

## File Changes Summary

### CueCard.swift
```diff
✏️ fuzzyMatch()
   - Changed to weighted scoring
   - Penalizes bag-only matches by 15%
   - Validates sequential/substring scores

✏️ wordBagMatch()
   - Stricter partial matching (5+ chars, 80% similarity)
   - Reduced consecutive bonus (15% → 5%)

✏️ matchesExitPhrase()
   - Threshold: 0.45 → 0.55

✏️ matchesAnchorPhrase()
   - Threshold: 0.40 → 0.45
```

### CueCardSettingsStore.swift
```diff
✏️ exitPhraseSensitivity
   - Default: 0.45 → 0.55

✏️ anchorPhraseSensitivity
   - Default: 0.40 → 0.45
```

### StageRehearsalView.swift
```diff
➕ Added timer state variables
➕ Added startRehearsal()
➕ Added pauseRehearsal()
➕ Added toggleRehearsal()
➕ Added formatTime()
➕ Added startTimer()
➕ Added stopTimer()

✏️ startRehearsalIfNeeded()
   - Removed automatic start
   - Now just configures engine

✏️ Timer display in topBar()
   - Now a button (not static display)
   - Shows play/pause icon
   - Yellow when running, gray when paused

✏️ calculateFontSize()
   - More aggressive scaling (85% base)
   - Smaller multipliers for short/long content

✏️ cueCardContent
   - Bottom spacing: 200 → 350

✏️ recognitionFeedbackOverlay
   - Added solid gradient background
   - Removed .padding(.bottom, 40)
   - Reduced spacing: 16 → 12
   - Smaller padding: 24px horizontal

✏️ phraseDetectionCard()
   - Reduced font sizes (24pt → 20pt, 12pt → 10pt)
   - Smaller padding (16 → 12)
   - Smaller border radius (16 → 12)
   - Thinner stroke (2px → 1.5px)
   - Smaller scale effect (1.05 → 1.03)
   - Smaller confidence bar (4px → 3px)
```

---

## Expected Behavior

### Sensitivity
- **Old:** Cards flip halfway through (45% threshold, lenient matching)
- **New:** Cards flip near the end (55% threshold, balanced matching)

### Starting
- **Old:** Auto-starts immediately on tab switch
- **New:** Waits for play button press

### Overlay
- **Old:** Large overlay blocking ~35% of screen
- **New:** Compact overlay using ~20% of screen, solid background

### Font Sizing
- **Old:** Same size as Stage Mode
- **New:** Slightly smaller (85%) to fit better with overlay

---

## Troubleshooting

### "Still flipping too early"
→ Increase exit sensitivity: 0.55 → 0.65
→ Make exit phrase more unique/distinctive
→ Check that exit phrase is actually at END of material

### "Not flipping at all"
→ Decrease exit sensitivity: 0.55 → 0.50
→ Speak exit phrase more clearly
→ Check that you're saying the exact phrase

### "Play button doesn't work"
→ Make sure you're tapping the timer (center top)
→ Should see play → pause → play

### "Overlay still too big"
→ Disable phrase feedback in settings (shows only progress bar)
→ Or adjust overlay code to be even smaller

### "Text too small"
→ Increase base font size in Stage Mode Settings
→ This is 85% of that setting

---

## Summary

✅ **Fixed over-sensitivity** - Weighted scoring prevents mid-card false positives  
✅ **Added play/pause** - Rehearsal waits for user to start  
✅ **Compact overlay** - More cue card space, solid background  
✅ **Better UX** - More control, less distraction, clearer feedback  

The rehearsal mode should now feel much more controlled and professional!
