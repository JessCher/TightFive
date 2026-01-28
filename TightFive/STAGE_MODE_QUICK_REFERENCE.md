# Stage Mode Quick Reference Card 🎭

## Visual Indicators While Performing

### Confidence Indicator (next to "Listening")
- 🟢 **Green dot** = Locked on perfectly (75%+ confidence)
- 🟡 **Yellow dot** = Tracking well (50-74% confidence)
- 🟠 **Orange dot** = Searching (32-49% confidence)
- ⚫ **No dot** = Lost/off-script (confidence fading)

### Overlay Border
- **Green glow** = System is locked onto your speech (70%+ confidence)
- **White/dim** = Normal operation

### What This Means:
- **Green dot + green border** = Keep going, everything is perfect
- **Yellow dot** = Still good, might scroll in ~80ms
- **Fading to orange** = You're ad-libbing (expected during crowd work)
- **Dot disappears** = System is patiently waiting for you to return to script

## If You Ever Get Lost

### Quick Recovery Methods:
1. **Speak a configured Anchor Phrase** ⚡ **FASTEST**
   - Say any anchor phrase you've configured (e.g., "Now let me tell you about...")
   - System **instantly jumps** to that section (even if far away)
   - Triggers haptic feedback so you know it worked
   - Best for: Big skips, recovering after long ad-libs, section changes

2. **Speak the first 2-3 words of your current line clearly**
   - System will snap to you instantly (usually <100ms)
   - Works for nearby lines within ~12 lines forward
   - Best for: Getting back on track during normal flow
   
3. **Use the chevron buttons** (bottom of screen)
   - Tap up/down to manually jump lines
   - System will resume auto-tracking from new position
   - Best for: Precise control during rehearsal

4. **Look at the confidence dot**
   - If it's green = system knows where you are
   - If it's gone = speak louder or clearer for 2-3 words

## During Performance

### Auto Mode (sparkles icon - default):
- **Continuous scrolling** tracks your speech line-by-line
- **Anchor phrases** instantly jump to configured sections
- Pauses when you go off-script
- Resumes immediately when back on script

### Manual Mode (hand icon):
- Disables automatic scrolling (but anchors still work!)
- Use chevron buttons to control scrolling
- Good for rehearsal or non-verbal sections
- Switch back to Auto anytime

## Advanced: Anchor Phrases vs Continuous Scrolling

### Two Systems Working Together:

**Continuous Scrolling** (Line-by-line tracking):
- Handles normal performance flow
- Tracks you word-by-word, scrolls smoothly
- Works within ~12 lines forward of current position
- Real-time, responsive, natural feel

**Anchor Phrases** (Jump points):
- Configured in your setlist settings
- Instant jump to any section, any distance
- Triggers when you speak the exact phrase
- Gives haptic feedback when activated

### When to Use Each:

| Situation | Use This | Why |
|-----------|----------|-----|
| Normal script flow | Continuous scrolling (automatic) | Natural, hands-free |
| Skip ahead 10+ lines | Anchor phrase | Faster than scrolling |
| After long crowd work | Anchor phrase | Instant repositioning |
| Non-linear performance | Anchor phrase | Jump anywhere |
| Small corrections | Continuous (speak first words) | Already in position |
| Lost your place | Both (try anchor first) | Fastest recovery |

### Example Anchor Setup:
```
Section 1: "Welcome to the show everyone"
Section 2: "Now let me tell you about my childhood"  
Section 3: "And that's when things got weird"
Section 4: "So in conclusion"
```

During performance:
- Normal flow: Continuous scrolling handles everything
- Need to skip? Just say "Now let me tell you about my childhood"
- System instantly jumps to Section 2
- Continuous scrolling resumes from there

## Tuning for Your Venue/Style

### If scrolling feels TOO FAST (false positives):
Edit `TeleprompterScrollTracker.swift`:
```swift
private static let profile = TuningProfile.conservative
```

### If scrolling feels TOO SLOW (lagging behind):
Edit `TeleprompterScrollTracker.swift`:
```swift
private static let profile = TuningProfile.aggressive
```

### Default (recommended starting point):
```swift
private static let profile = TuningProfile.balanced
```

## Performance Tips

### For Best Results:
- ✅ **Speak naturally** - the system adapts to your pace
- ✅ **First words matter** - each line's opening triggers recognition
- ✅ **Confidence is key** - clear enunciation = instant scrolling
- ✅ **Pause freely** - system waits patiently, no timeout

### During Crowd Work:
- System automatically pauses when you go off-script
- Confidence dot will fade (normal behavior)
- When you resume, speak your current line's first 2-3 words
- Green dot returns instantly = you're locked back in

### In Noisy Venues:
- System uses on-device recognition (very robust)
- Speak slightly louder than usual
- If confidence stays low, switch to Manual mode temporarily
- Consider using `conservative` profile preset

## Troubleshooting

### "System keeps jumping ahead"
→ Switch to `conservative` profile
→ Check if anchor phrases are too similar to regular script lines

### "System lags behind my speech"
→ Switch to `aggressive` profile

### "Confidence never goes green"
→ Check microphone isn't covered
→ Verify on-device recognition is enabled (Settings → Siri)
→ Speak opening words of each line more clearly

### "System stuck on one line"
→ Speak an anchor phrase to jump forward
→ Or tap chevron down to advance manually
→ Continue speaking (will auto-track from new position)

### "Anchor phrase not triggering"
→ Speak the phrase exactly as configured
→ Ensure anchor is enabled in setlist settings
→ Check that phrase is unique (not in your regular script)
→ Try speaking slightly slower/clearer

## Technical Stats (For Nerds)

### Latency (Balanced Profile):
- High confidence (75%+): **~145ms** total
- Medium confidence: **~225ms** total
- *(Previous version was ~360-425ms)*

### What Changed:
- ⚡ 3x faster instant acceptance
- ⚡ 67% faster confirmation window
- ⚡ 52% faster scroll animation
- ⚡ 33% shorter look-behind window
- ⚡ Removed all artificial throttling
- ✅ **Anchor phrases unchanged** (still instant jumps)

### What Was NOT Changed:
The optimization focused on **continuous scrolling performance**. These remain exactly the same:
- ✅ Anchor phrase detection (still instant)
- ✅ Anchor phrase accuracy (still 100% when configured properly)
- ✅ Manual chevron controls
- ✅ Auto/Manual mode switching
- ✅ Recording quality
- ✅ Audio level monitoring

---

**Remember**: If you ever look down at the screen, you should see exactly what you need to be speaking. That's the promise of this system. 🎯
