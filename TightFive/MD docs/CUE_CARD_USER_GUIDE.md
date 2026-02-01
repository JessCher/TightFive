# Stage Mode: Cue Card User Guide

## What is Cue Card Mode?

**Cue Card Mode** displays your setlist one bit at a time, like a digital cue card. The app automatically advances to the next card when it detects you've finished the current one.

## How It Works

### The Basics

1. **One card shows at a time** with your full bit text
2. **Text auto-scales** to fit on screen (no scrolling needed)
3. **Speech recognition listens** as you perform
4. **Exit phrase detection** advances to next card automatically
5. **Manual controls** always available as backup

### Dual-Phrase Recognition

Each card has two special phrases:

- **Anchor Phrase** (first ~15 words)
  - What you say when starting this bit
  - Confirms you're in the right place
  
- **Exit Phrase** (last ~15 words)  
  - What you say at the end of this bit
  - Triggers transition to next card

### Typical Flow

```
Card 1 appears
↓
You speak Card 1 content
↓
System hears exit phrase
↓
Card 2 appears instantly
↓
You see Card 2's opening and begin
↓
Repeat until done
```

## Controls

### Touch Gestures

- **Swipe Left** → Next card
- **Swipe Right** → Previous card
- **Tap X** → End performance (saves recording)

### Buttons

- **Chevrons (< >)** → Navigate cards precisely
- **Auto/Manual Toggle** → Enable/disable auto-advance
- **Exit Button** → End session with confirmation

### Top Bar

- **Progress** → "3 / 10" shows card position
- **Timer** → Running performance time
- **Recording Indicator** → Red dot when capturing audio

### Phrase Feedback Bar (Optional)

Shows real-time recognition status:

- **Anchor** → Confidence you're in this card
- **Listening** → Microphone status  
- **Exit** → Confidence exit phrase is near

## Tips for Best Performance

### 1. Speak Clearly Through Endings

Don't trail off at the end of bits. The exit phrase needs to be heard clearly.

❌ **Bad**: "...and that's why I don't go to the gym anymore." *(mumbles, trails off)*

✅ **Good**: "...and that's why I don't go to the gym ANYMORE!" *(clear, confident)*

### 2. Trust the System

When auto-advance is working well, let it do its thing. You'll get into a rhythm.

### 3. Use Manual Controls When Needed

Improvising? Crowd work? Toggle to **Manual** mode and swipe when ready.

### 4. Adjust Sensitivity

Everyone speaks differently. Find your sweet spot:

- **Settings → Run Mode Settings → Cue Card Settings**
- **Exit Phrase Sensitivity** slider
- Try 60% first, adjust up/down based on results

### 5. Practice Makes Perfect

First few performances may feel different from continuous scroll. Give it 2-3 shows to adapt.

## Settings

### Cue Card Settings

**Path**: More → Run Mode Settings → Cue Card Settings

**Options**:

1. **Auto-advance on exit phrase**
   - ON: Cards advance automatically
   - OFF: Manual swiping only
   
2. **Show phrase recognition feedback**
   - ON: See confidence bars for anchor/exit
   - OFF: Cleaner interface
   
3. **Exit phrase sensitivity** (40%-90%)
   - **Lower** (40-50%): More sensitive, may advance early
   - **Medium** (60-70%): Balanced (recommended)
   - **Higher** (80-90%): Very precise, may miss detections

## Troubleshooting

### "Cards advancing too early"

**Cause**: Sensitivity too high, or similar phrases mid-bit.

**Solutions**:
- Increase exit phrase threshold (Settings)
- Toggle to Manual mode for that section
- Avoid repeating the same words you use at the end

### "Cards not advancing automatically"

**Cause**: Speaking unclear, threshold too strict, background noise.

**Solutions**:
- Lower exit phrase threshold (Settings)
- Speak exit phrase clearly and fully
- Use manual swipe as backup
- Check microphone isn't covered

### "Can't see all my text"

**Cause**: Very long bit on small screen.

**Solutions**:
- Text auto-scales, but may get small
- Consider splitting long bits into 2 cards
- Use manual scroll in script editor to check content
- Font size adjusts automatically based on word count:
  - Short bits: 48pt (huge)
  - Medium bits: 38pt (large)
  - Long bits: 32pt (readable)
  - Very long: 28pt (still legible)

### "Recording not saving"

**Cause**: Permissions issue or storage full.

**Solutions**:
- Check Settings → Permissions → Microphone
- Check Settings → Permissions → Speech Recognition
- Free up device storage if needed

## Performance Recording

### What Gets Recorded

- ✅ **Audio**: High-quality M4A (96kbps)
- ✅ **Duration**: Total performance time
- ✅ **Analytics**: Recognition confidence, transitions
- ❌ **Video**: Audio only (lighter files)

### Where Recordings Go

Automatically saved to:
- **Show Notes** tab
- Organized by date and setlist
- Playback available immediately

### Storage Management

Check storage usage:
- **More → Storage** (if available)
- Delete old performances you don't need
- Recordings are ~1MB per minute

## Best Practices

### Setlist Preparation

1. **Write clear bit boundaries**: Each script block should be one complete bit
2. **Avoid tiny blocks**: Minimum ~30 words works best
3. **Test your setlist**: Run through once in Manual mode to verify cards make sense

### During Performance

1. **Start in Auto mode**: Give it a chance to work
2. **Keep Manual toggle accessible**: One tap to disable if needed
3. **Don't fight the system**: If it's advancing weirdly, go Manual
4. **Focus on performance**: Cards should fade into background

### After Performance

1. **Review analytics**: Check automatic transition rate
2. **Adjust sensitivity**: Fine-tune based on results
3. **Note problem spots**: Consider rewriting bits with low confidence
4. **Compare with rehearsals**: See improvement over time

## Advanced Tips

### For Clean Sets (Tight Material)

- **Use Auto mode** throughout
- **Higher sensitivity** (70-80%) for precision
- Text should match what you say exactly

### For Loose Sets (Crowd Work, Improv)

- **Start in Auto** for written material
- **Toggle to Manual** for crowd work sections
- **Return to Auto** when back on script

### For New Material

- **Manual mode** recommended
- Focus on performance, not technology
- Once material is tight, switch to Auto

### For Callbacks

If you reference earlier bits:
- **Manual mode** prevents confusion
- Or use higher sensitivity to avoid false triggers

## Frequently Asked Questions

### Q: Can I edit text during performance?

**A**: No. Edit your setlist before starting Stage Mode.

### Q: What if I skip a card by accident?

**A**: Swipe right to go back, or tap the left chevron.

### Q: Does it work without internet?

**A**: Yes! On-device speech recognition (iOS 15+) works offline.

### Q: What about other languages?

**A**: Currently optimized for English. Other languages may work but with lower accuracy.

### Q: Can I use Bluetooth mic?

**A**: Yes! Bluetooth audio is supported for both input and output.

### Q: Does it drain battery fast?

**A**: Moderate usage. Speech recognition uses CPU, but no more than original teleprompter mode.

### Q: Can I customize anchor/exit phrases?

**A**: Not yet. They're automatically extracted (first/last 15 words). Custom phrases may come in a future update.

## Getting Help

If you're having consistent issues:

1. Check this guide's Troubleshooting section
2. Try a simple 3-card test setlist
3. Verify permissions are granted
4. Try lowering exit phrase sensitivity to 50%
5. Use Manual mode as reliable fallback

Remember: **Manual controls always work**. Auto-advance is a convenience, not a requirement.

## Comparison: Teleprompter vs Cue Card

| Feature | Teleprompter | Cue Card |
|---------|-------------|----------|
| Display | Continuous scroll | One card at a time |
| Navigation | Auto-scroll with sync | Auto-advance on phrases |
| Context | Entire script visible | Current bit only |
| Recognition | Position in full text | Anchor + exit phrases |
| Confidence | Lower (lots of text) | Higher (focused context) |
| Manual control | Tap to pause/resume | Swipe to navigate |
| Best for | Reading prepared script | Glanceable prompts |

## Final Thoughts

Cue Card Mode is designed to **support** your performance, not dictate it. The goal is to:

- Keep you on track without constant screen-watching
- Provide confidence you won't forget your place
- Get out of your way and let you focus on the crowd

Give it a few shows. Adjust settings to your style. And always remember: if recognition isn't working, just swipe. 

Break a leg! 🎤
