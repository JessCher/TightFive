# Cue Card Mode: Quick Start Checklist

## ⚡ 5-Minute Integration (Recommended Path)

Follow these steps to replace the old teleprompter with the new cue card mode:

### Step 1: Verify Files ✓

Ensure these new files are in your Xcode project:

- [ ] `CueCard.swift`
- [ ] `CueCardEngine.swift`
- [ ] `StageModeViewCueCard.swift`

And these files were modified:

- [ ] `RunModeSettingsStore.swift` (added cue card settings)
- [ ] `RunModeSettingsView.swift` (added settings UI)
- [ ] `PerformanceAnalytics.swift` (added convenience initializer)

### Step 2: Backup Old Implementation

Rename your existing files for safety:

```bash
# In Xcode, rename these files:
StageModeView.swift → StageModeViewTeleprompter.swift

# Keep these unchanged:
StageTeleprompterEngine.swift (not used by new mode)
VoiceAwareScrollController.swift (not used by new mode)
ContinuousScrollEngine.swift (not used by new mode)
TeleprompterScrollTracker.swift (not used by new mode)
```

### Step 3: Activate Cue Card Mode

Rename the new implementation to be the default:

```bash
# In Xcode, rename:
StageModeViewCueCard.swift → StageModeView.swift
```

**That's it!** Any existing navigation to `StageModeView` will now use cue cards.

### Step 4: Build & Test

1. **Clean Build Folder**: Cmd+Shift+K
2. **Build**: Cmd+B
3. **Run**: Cmd+R

### Step 5: Smoke Test

1. Create a test setlist with 3 script blocks
2. Navigate to Stage Mode
3. Verify:
   - [ ] One card shows at a time
   - [ ] Can swipe left/right between cards
   - [ ] Progress shows "1 / 3", "2 / 3", "3 / 3"
   - [ ] Recording starts automatically
   - [ ] Exit button works
   - [ ] Performance saves

### Step 6: Check Settings

1. Go to More → Run Mode Settings
2. Verify "Cue Card Settings" section appears
3. Test toggles and sliders
4. Verify changes persist

---

## ✅ Verification Checklist

After integration, verify these work:

### Basic Functionality
- [ ] Stage Mode opens without errors
- [ ] Cards display full text (readable size)
- [ ] Text auto-scales based on content length
- [ ] Swipe left advances to next card
- [ ] Swipe right goes to previous card
- [ ] Progress indicator updates correctly
- [ ] Timer shows elapsed time
- [ ] Recording indicator shows red dot

### Speech Recognition
- [ ] Microphone permission requested
- [ ] Speech permission requested
- [ ] "Listening" status shows when active
- [ ] Phrase feedback bar appears (if enabled in settings)
- [ ] Speaking exit phrase advances card (auto mode)
- [ ] Manual toggle disables auto-advance

### Settings
- [ ] Cue Card Settings section visible
- [ ] Auto-advance toggle works
- [ ] Phrase feedback toggle works
- [ ] Exit phrase sensitivity slider works
- [ ] Settings persist after restart

### Recording
- [ ] Audio records during performance
- [ ] Exit confirmation dialog appears
- [ ] Performance saves to Show Notes
- [ ] Audio file plays back correctly
- [ ] Performance metadata correct (duration, etc)

---

## 🐛 Troubleshooting

### Build Errors

**"CueCard type not found"**
- Verify `CueCard.swift` is added to your app target
- Clean build folder (Cmd+Shift+K) and rebuild

**"CueCardEngine type not found"**
- Verify `CueCardEngine.swift` is added to your app target
- Check import statements are correct

**"Cannot find type 'StageModeView'"**
- You renamed the file but may need to rename the struct inside too
- Or rename `StageModeViewCueCard` struct to `StageModeView`

### Runtime Issues

**Cards show empty text**
- Verify setlist has `scriptBlocks` populated
- Check `setlist.assignments` are not empty
- Test with simple freeform text blocks first

**No audio recording**
- Check microphone permissions in Settings app
- Verify AVFoundation framework is linked
- Check device storage isn't full

**Settings not appearing**
- Verify `RunModeSettingsStore.swift` has new properties
- Clean build folder and rebuild
- Check you're looking in "Run Mode Settings" (not general settings)

### Recognition Issues

**Cards not advancing automatically**
- Lower exit phrase threshold in settings
- Speak clearly through end of bits
- Check microphone isn't covered
- Use Manual mode as fallback

**Cards advancing too early**
- Raise exit phrase threshold in settings
- Avoid repeating end phrases mid-bit
- Toggle to Manual mode for improv sections

---

## 🔄 Rollback Plan

If you need to revert:

### Quick Rollback (5 minutes)

```bash
# In Xcode, rename:
StageModeView.swift → StageModeViewCueCard.swift
StageModeViewTeleprompter.swift → StageModeView.swift
```

Clean build (Cmd+Shift+K) and rebuild. Original teleprompter mode restored.

---

## 📚 Next Steps

After successful integration:

1. **Read User Guide**: Share `CUE_CARD_USER_GUIDE.md` with team
2. **Test Real Setlist**: Use actual performance material
3. **Tune Settings**: Adjust exit phrase threshold for your speaking style
4. **Gather Feedback**: Note what works and what doesn't
5. **Review Analytics**: Check automatic transition rates

---

## 💡 Quick Tips

### For Best Results

1. **Start Simple**: Test with 3-5 card setlist first
2. **Use Auto Mode**: Give recognition a chance to work
3. **Clear Speech**: Speak exit phrases clearly
4. **Adjust Sensitivity**: Find your sweet spot (60% is good starting point)
5. **Manual Fallback**: Toggle off auto-advance if needed

### Performance Tips

1. **Prepare Setlist**: Ensure clear bit boundaries
2. **Avoid Tiny Blocks**: Minimum ~30 words per card
3. **Practice Once**: Run through in Manual mode first
4. **Trust the System**: Let auto-advance work when it's working
5. **Stay Flexible**: Use Manual mode for crowd work

---

## 🎯 Success Criteria

You'll know it's working when:

- ✅ Build succeeds without errors
- ✅ Cards display one at a time
- ✅ Swipe navigation works smoothly
- ✅ Auto-advance triggers on speech
- ✅ Manual controls always work
- ✅ Recordings save successfully
- ✅ Settings persist between launches

---

## 📞 Support

**Common Questions**:
- Technical architecture → `CUE_CARD_IMPLEMENTATION.md`
- Integration options → `CUE_CARD_INTEGRATION.md`
- User instructions → `CUE_CARD_USER_GUIDE.md`
- Overview → `CUE_CARD_SUMMARY.md`

**Quick Checks**:
1. All files added to Xcode target? ✓
2. Clean build performed? ✓
3. Permissions granted? ✓
4. Settings showing correctly? ✓

If all checks pass and issues persist, review the full implementation guide.

---

## ⏱️ Estimated Times

- **File verification**: 2 minutes
- **Renaming/integration**: 3 minutes
- **Build & run**: 2 minutes
- **Basic testing**: 5 minutes
- **Settings verification**: 3 minutes

**Total: ~15 minutes** for complete integration and verification

---

## ✨ Final Check

Before considering the integration complete:

- [ ] Code builds without errors
- [ ] Stage Mode opens successfully
- [ ] Cards navigate correctly
- [ ] Speech recognition active
- [ ] Settings visible and functional
- [ ] Recordings save properly
- [ ] Team knows where to find user guide

**All checked?** You're done! 🎉

The cue card mode is now live and ready for testing. Run a few test performances, tune the settings, and enjoy higher recognition confidence!

---

**Remember**: The old teleprompter mode is safely backed up as `StageModeViewTeleprompter.swift`. You can always switch back if needed.

Good luck! 🎤
