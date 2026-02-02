# Rollback to Original Voice Recognition

## What Was Rolled Back

All voice recognition changes made after the initial Rehearsal Mode implementation have been reverted to the original simple algorithm.

## Changes Made

### CueCard.swift - Restored Original Algorithm

**Removed:**
- ❌ Multi-strategy matching (word bag, sequential, substring)
- ❌ Recency checking for exit phrases
- ❌ Graduated penalties based on position
- ❌ Weighted scoring systems
- ❌ All the helper functions (wordBagMatch, sequentialMatch, substringMatch, checkRecency, hasConsecutiveMatches, sequentialScore)

**Restored:**
- ✅ Simple sliding window fuzzy matching
- ✅ Direct word-for-word comparison
- ✅ Settings-based thresholds (reads from CueCardSettingsStore)

**Original Matching Logic:**
```swift
private func fuzzyMatch(transcriptWords: [String], targetWords: [String]) -> Double {
    // Try all windows in transcript
    for each window:
        count exact word matches
        return matches / target.count
    
    return best score found
}
```

This is simple and predictable - it looks for the target words in order within the transcript.

### CueCardSettingsStore.swift - Restored Original Defaults

**Changed:**
- Exit sensitivity: 0.55 → **0.6** (original)
- Anchor sensitivity: 0.45 → **0.5** (original)

### What Stayed the Same

**✅ Rehearsal Mode Still Works:**
- StageRehearsalView.swift - unchanged
- StageRehearsalEngine.swift - unchanged
- RunModeView.swift - Rehearsal tab still present
- All UI, timer controls, analytics - all unchanged

**✅ Play/Pause Functionality:**
- Timer must be started manually
- Click to play/pause
- All that functionality remains

**✅ UI Improvements:**
- Compact overlay
- Solid gradient background
- Smaller phrase detection cards
- All UI tweaks remain

## Current State

### Voice Recognition
- **Algorithm:** Original simple sliding window
- **Exit threshold:** 0.6 (60%)
- **Anchor threshold:** 0.5 (50%)
- **Behavior:** Looks for exact word matches in order

### Rehearsal Mode
- **Exists:** Yes ✅
- **Location:** Run Through → Rehearsal tab
- **Features:** All present (timer, analytics, feedback)
- **UI:** All improvements kept

## What This Means

### Strengths of Original Algorithm
- ✅ Simple and predictable
- ✅ No complex recency calculations
- ✅ Proven to work (used before improvements)
- ✅ Settings adjustments work directly

### Weaknesses of Original Algorithm
- ⚠️ Requires close word-for-word matches
- ⚠️ Doesn't handle filler words well ("um", "like")
- ⚠️ Doesn't check position (can trigger mid-card if words match)
- ⚠️ Less forgiving of natural speech

### How to Get Best Results

**1. Write Clear Exit Phrases**
- Use exact words you'll say
- Avoid common words
- 10-15 words is good length
- Make them distinctive

**2. Speak Clearly**
- Say phrases as written
- Minimize filler words
- Consistent pacing
- Clear enunciation

**3. Adjust Settings**
- If triggering too early: Increase exit sensitivity (0.6 → 0.7)
- If not triggering: Decrease exit sensitivity (0.6 → 0.5)
- Found in: Setlist → ⋯ → Stage Mode Settings

## Files Modified

```
✏️ CueCard.swift
   - Removed all improved matching algorithms
   - Restored original fuzzyMatch() and matchScore()
   - Uses CueCardSettingsStore thresholds

✏️ CueCardSettingsStore.swift
   - exitPhraseSensitivity: 0.55 → 0.6
   - anchorPhraseSensitivity: 0.45 → 0.5
   - Removed comments about recency
```

## Files Unchanged

```
✅ StageRehearsalView.swift - All features intact
✅ StageRehearsalEngine.swift - All features intact
✅ RunModeView.swift - Rehearsal tab intact
✅ StageModeViewCueCard.swift - Unchanged
✅ CueCardEngine.swift - Uses CueCard matching (now original)
```

## Testing the Rollback

### In Rehearsal Mode
1. Go to Run Through → Rehearsal
2. Press play
3. Speak your material
4. Confidence scores will be based on exact word matches
5. Exit phrases trigger when words match in order

### Expected Behavior
- **Good match:** Say exit phrase exactly → High confidence (70-90%)
- **Okay match:** Say exit phrase with slight variation → Medium confidence (50-70%)
- **Poor match:** Different words or order → Low confidence (0-50%)

## Troubleshooting

### "Triggering too early still"
- Your exit phrase words appear mid-card
- **Solution:** Edit exit phrase to use more unique words
- OR increase threshold: Settings → Exit Sensitivity → 0.7 or 0.8

### "Not triggering at all"
- Words don't match exactly
- **Solution:** Say exit phrase exactly as written
- OR decrease threshold: Settings → Exit Sensitivity → 0.5 or 0.4

### "Confidence always low"
- Natural speech has too many variations
- **Solution:** 
  - Speak more clearly
  - Use simpler, more consistent phrases
  - Practice saying phrases exactly

## Going Forward

This is the **baseline** - the original system that worked before improvements.

If you want to try improvements again in the future, we can:
1. Start with this clean base
2. Make targeted, small changes
3. Test each change individually
4. Only keep what actually helps

But for now, you have:
- ✅ Working Rehearsal Mode
- ✅ Original voice recognition (simple, predictable)
- ✅ All UI improvements
- ✅ Settings-based control

## Summary

**Rolled Back:**
- All complex matching algorithms
- Recency checking
- Position-based penalties
- Multi-strategy scoring

**Kept:**
- Rehearsal Mode (complete)
- UI improvements
- Play/pause functionality
- All analytics

**Result:**
- Back to original, simple algorithm
- Rehearsal Mode fully functional
- Settings work as before
- Clean slate for future improvements

You're now on the proven, original voice recognition system with all the Rehearsal Mode features intact! 🎯
