# Exit Phrase Recency Fix - Change Summary

## Problem

Exit phrases were still triggering too early - even halfway through cards. The issue is that exit phrase words might naturally appear in the middle of your material, not just at the end.

**Example:**
```
Your exit phrase: "and that's my story"
Your card content: 
  "So I was thinking about my story the other day, 
   and that's when I realized... [more content]... 
   and that's my story."
```

When you say "and that's" in the middle, it was getting a decent match score and triggering early.

## Root Cause

The previous algorithm only checked **IF** the words matched, not **WHERE** in your speech they appeared. Exit phrases should only trigger when they appear **at the END** of what you're saying, not in the middle.

## Solution: Recency Checking

Added a new strategy specifically for exit phrases that checks **when** the match occurs in the transcript:

### New Strategy: `checkRecency()`

```swift
private func checkRecency(transcriptWords: [String], targetWords: [String]) -> Double {
    // Finds the best match position in the transcript
    // Returns 0.0-1.0 based on how close to the END it appears
    
    // Example:
    // If match is in last 20% of transcript: recency = 1.0 ✅
    // If match is in middle (50%): recency = 0.5 ⚠️
    // If match is at start (10%): recency = 0.1 ❌
}
```

### Exit Phrase Logic (NEW)

```swift
if isExitPhrase {
    // 1. Check recency first
    if recencyScore < 0.6 {
        // Match is NOT near the end
        // This is probably a mid-card false positive
        return 0.0  // Don't trigger!
    }
    
    // 2. Recency is good (>60% through transcript)
    // Now check quality of match
    let weightedScore = (sequenceScore * 0.5) + (substringScore * 0.3) + (bagScore * 0.2)
    
    // 3. Boost if at VERY end (>80%)
    let recencyBoost = recencyScore > 0.8 ? 1.15 : 1.0
    
    return min(weightedScore * recencyBoost, 1.0)
}
```

### How It Works

**Scenario 1: Exit phrase appears mid-card**
```
Transcript so far: "and that's when I realized something important..."
Exit phrase: "and that's my story"
Position in transcript: 15% through
Recency score: 0.15
Result: 0.0 (rejected immediately) ✅
```

**Scenario 2: Exit phrase appears at end**
```
Transcript so far: "...and that's my story"
Exit phrase: "and that's my story"
Position in transcript: 95% through
Recency score: 0.95
Match quality: 0.85
Recency boost: 1.15 (because >80%)
Final confidence: 0.85 * 1.15 = 0.98
Result: Triggers! ✅
```

**Scenario 3: Similar words mid-card**
```
Transcript so far: "so that's my problem with dating..."
Exit phrase: "and that's my story"
Position in transcript: 40% through
Recency score: 0.40
Result: 0.0 (rejected - recency too low) ✅
```

## Changes Made

### 1. Updated `fuzzyMatch()` Function

**Before:**
- Same logic for anchor and exit phrases
- Only checked IF words matched
- Didn't care WHERE they matched

**After:**
- Takes `isExitPhrase: Bool` parameter
- Exit phrases: Requires recency >60% + quality match
- Anchor phrases: Uses original logic (can match anywhere)

### 2. Updated Matching Weights for Exit Phrases

**For exit phrases only:**
- Sequential matching: 50% (was 40%)
- Substring matching: 30% (was 30%)
- Word bag matching: 20% (was 30%)

**Rationale:** 
- Sequential and substring care about order = more reliable
- Word bag doesn't care about order = less weight for exit

### 3. Raised Exit Threshold

**Default threshold:**
- Exit phrases: 0.60 (was 0.55)
- Anchor phrases: 0.45 (unchanged)

### 4. Added Recency Boost

If exit phrase appears in **last 20% of transcript** (recency >0.8):
- Apply 15% boost to confidence score
- Rewards phrases said right at the end
- Makes end-of-card detection more reliable

## Expected Behavior

### ❌ **Won't Trigger:**

1. **Mid-card word matches**
   ```
   You're at: 30% through card
   Exit phrase words appear
   → Recency too low → Confidence: 0.0
   ```

2. **Scattered words throughout**
   ```
   Exit words scattered in middle of material
   Position: 45% through
   → Recency check fails → Confidence: 0.0
   ```

3. **Similar but not at end**
   ```
   Exit phrase: "that's all folks"
   You say: "that's all I needed to know"
   Position: 60% through
   → Might pass recency, but match quality low
   ```

### ✅ **Will Trigger:**

1. **Actual exit phrase at end**
   ```
   You're at: 90% through card
   Say exit phrase clearly
   → Recency: 0.90, Match: 0.80
   → Final: ~0.92 → Triggers!
   ```

2. **Exit phrase with fillers**
   ```
   You're at: 85% through
   Say: "and um, that's my story"
   Exit: "that's my story"
   → Recency: 0.85, Match: 0.75
   → Final: ~0.86 → Triggers!
   ```

3. **Natural ending**
   ```
   You finish material naturally
   Exit phrase is the last thing you say
   → Recency: 1.0, Match quality good
   → Bonus boost applied → Triggers!
   ```

## Recency Thresholds

```
Position in Transcript    Recency Score    Exit Phrase Behavior
─────────────────────────────────────────────────────────────
0-20% (Beginning)         0.0 - 0.2       ❌ Auto-rejected
20-40% (Early-Mid)        0.2 - 0.4       ❌ Auto-rejected
40-60% (Mid)              0.4 - 0.6       ❌ Auto-rejected
60-70% (Late-Mid)         0.6 - 0.7       ⚠️  Requires high match
70-80% (Near End)         0.7 - 0.8       ✅ Triggers if match good
80-100% (End)             0.8 - 1.0       ✅ Triggers + 15% boost
```

## Testing Examples

### Test 1: Short Card (200 words)
**Material:** "Short bit here... and that's all."
**Exit phrase:** "and that's all"

Speaking pattern:
- 0-50%: Shouldn't trigger even if you mention "that's"
- 50-75%: Shouldn't trigger unless exact phrase
- 75-100%: Should trigger when you say "and that's all"

### Test 2: Long Card (800 words)
**Material:** Long comedy bit with exit phrase only at very end
**Exit phrase:** "thank you very much"

Speaking pattern:
- 0-60%: Can say "thank you" mid-card, won't trigger
- 60-80%: Saying "thank you" gets checked but needs context
- 80-100%: Saying "thank you very much" at end triggers

### Test 3: Common Words in Exit
**Exit phrase:** "and that's the story"

- Mid-card: "and that's when..." → Recency: 0.3 → Rejected ✅
- Near end: "and that's the story" → Recency: 0.9 → Triggers ✅

## Settings Adjustments

If you need to fine-tune:

### Exit Triggering Too Late
- **Lower** exit sensitivity: 0.60 → 0.55
- Effect: Requires lower match quality
- Trade-off: Might get some mid-card triggers

### Exit Triggering Too Early (Still)
- **Raise** exit sensitivity: 0.60 → 0.65 or 0.70
- Effect: Requires higher match quality
- Trade-off: Might miss some end-of-card triggers
- OR edit exit phrases to be more unique

### Perfect Balance (Most Users)
- Keep default: **0.60**
- Recency checking prevents mid-card triggers
- Threshold catches end-of-card phrases

## Technical Details

### Recency Calculation
```swift
for start in 0...transcriptWords.count - windowSize {
    let window = transcriptWords[start..<end]
    let matchScore = sequentialScore(window, target)
    
    if matchScore > 0.6 {
        // Found a good match!
        // Where is it in the transcript?
        let recency = (start + windowSize) / transcriptWords.count
        // recency = 0.0 (beginning) to 1.0 (end)
    }
}
```

### Confidence Calculation for Exit
```swift
// Step 1: Check position
if recency < 0.6:
    return 0.0  // Not at end - reject
    
// Step 2: Calculate match quality
let quality = (sequence*0.5) + (substring*0.3) + (bag*0.2)

// Step 3: Apply boost if very late
if recency > 0.8:
    quality *= 1.15

return quality
```

### Why 60% Recency Threshold?

**Too Low (e.g., 40%):**
- Matches in middle of card would pass
- More false positives

**Too High (e.g., 80%):**
- Only last 20% of card could trigger
- Might miss legitimate end-of-card phrases

**Sweet Spot (60%):**
- Last 40% of card can trigger
- Prevents mid-card false positives
- Catches natural endings

## File Changes

### CueCard.swift
```diff
✏️ fuzzyMatch()
   + Added isExitPhrase parameter
   + Exit phrases check recency first
   + Recency <0.6 = auto-reject (0.0 confidence)
   + Recency >0.8 = 15% boost
   + Changed weights for exit (sequential 50%, bag 20%)

➕ checkRecency()
   + New function to find match position
   + Returns 0.0-1.0 based on where match occurs
   + Only considers good matches (>60% quality)

✏️ matchesExitPhrase()
   + Now passes isExitPhrase: true
   + Threshold: 0.55 → 0.60

✏️ matchesAnchorPhrase()
   + Now passes isExitPhrase: false
   + Threshold: 0.45 (unchanged)
```

### CueCardSettingsStore.swift
```diff
✏️ exitPhraseSensitivity
   + Default: 0.55 → 0.60
   + Added comment about recency checking
```

## Summary

**What Changed:**
- Exit phrases now check **WHERE** they appear (recency)
- Must appear in last 40% of what you're saying
- Mid-card matches auto-rejected (confidence = 0.0)
- End-of-card matches boosted by 15%

**Expected Results:**
- ✅ No more mid-card false triggers
- ✅ Reliable end-of-card detection
- ✅ Natural speech patterns still work
- ✅ Settings adjustments still effective

**The Tightrope:**
- **Too sensitive:** Would trigger on scattered words mid-card
- **Too loose:** Would miss actual end-of-card phrases
- **Just right:** Recency + quality + threshold = triggers only at end

Try it now! Exit phrases should only trigger when you're actually finishing the card, not halfway through. 🎯
