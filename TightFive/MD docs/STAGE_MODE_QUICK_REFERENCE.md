# Stage Mode Cue Card - Quick Reference

## 🎯 What Was Fixed

### Issue 1: Stage Mode Wouldn't Launch
**Before:** Tapping "Stage Mode" did nothing
**After:** ✅ Launches cue card interface immediately

**Fix:** Added `StageModeView` wrapper in `StageModeView.swift`

### Issue 2: Settings in Wrong Place
**Before:** Cue card settings mixed with Run Mode (teleprompter) settings
**After:** ✅ Dedicated "Stage Mode Settings" in setlist menu

**Fix:** Created `CueCardSettingsStore` and `CueCardSettingsView`

---

## 📂 New Files You Need

```
✅ CueCard.swift                    # Cue card model (may already exist)
✅ CueCardSettingsStore.swift       # Settings management
✅ CueCardSettingsView.swift        # Settings UI
```

---

## 🔧 Modified Files

```
✅ StageModeView.swift              # Added wrapper + settings integration
✅ SetlistBuilderView.swift         # Added settings menu item
```

---

## 🎨 How to Use

### Access Settings
```
Set lists → Finished → [Setlist] → ⋯ Menu → Stage Mode Settings
```

### Launch Stage Mode
```
Set lists → Finished → [Setlist] → ⋯ Menu → Stage Mode
```

---

## ⚙️ Available Settings

| Setting | Range | Default | Purpose |
|---------|-------|---------|---------|
| **Auto-advance** | ON/OFF | ON | Cards advance automatically |
| **Phrase feedback** | ON/OFF | ON | Show recognition bars |
| **Font size** | 24-56pt | 36pt | Card text size |
| **Line spacing** | 4-24pt | 12pt | Vertical spacing |
| **Text color** | W/Y/G | White | Card text color |
| **Exit sensitivity** | 30-90% | 60% | Phrase match threshold |
| **Anchor sensitivity** | 30-90% | 50% | Confirmation threshold |
| **Animations** | ON/OFF | ON | Card transitions |
| **Transition style** | S/F/Sc | Slide | Animation type |

---

## 🎭 Recommended Presets

### 🌟 Bright Stage
```
Font: 48pt
Color: Yellow
Spacing: 16pt
Auto: ON
Feedback: OFF
```

### 🎤 Rehearsal
```
Font: 36pt
Color: White
Spacing: 12pt
Auto: ON
Feedback: ON
```

### 📝 Manual Control
```
Font: 32pt
Color: White
Spacing: 10pt
Auto: OFF
Feedback: OFF
```

---

## 🆘 Troubleshooting

| Problem | Solution |
|---------|----------|
| Cards advance too fast | Increase exit sensitivity to 70-80% |
| Cards never advance | Decrease exit sensitivity to 40-50% |
| Text too small | Increase font size to 48-56pt |
| Text too large | Decrease font size to 28-32pt |
| Feedback distracting | Turn off "Show phrase feedback" |
| Settings don't appear | Ensure setlist is "Finished" not "In Progress" |
| Stage Mode won't start | Check microphone permissions |

---

## 💡 Tips

1. **Test in rehearsal** with feedback ON to see recognition working
2. **Use yellow text** in bright stage lights
3. **Font auto-scales** based on content length
4. **Manual swipes** always work even with auto-advance ON
5. **Settings auto-save** - no need to tap "Done"

---

## 🔍 Where Everything Lives

### User Interface
- **Settings Button**: SetlistBuilder toolbar → ⋯ menu → "Stage Mode Settings"
- **Launch Button**: SetlistBuilder toolbar → ⋯ menu → "Stage Mode"

### Code
- **Settings Storage**: `CueCardSettingsStore.shared` (singleton)
- **Settings UI**: `CueCardSettingsView` (SwiftUI sheet)
- **Stage Mode**: `StageModeView` → `StageModeViewCueCard`
- **Data Model**: `CueCard` (struct with dual-phrase recognition)

### Data Persistence
- **Storage**: UserDefaults (automatic)
- **Keys**: Prefixed with `cueCard_` (e.g., `cueCard_fontSize`)
- **Scope**: App-wide (not per-setlist)

---

## ✅ Verification Steps

1. ✅ Open a finished setlist
2. ✅ Tap ⋯ menu - see "Stage Mode Settings"
3. ✅ Tap "Stage Mode Settings" - sheet opens
4. ✅ Adjust font size slider - see value change
5. ✅ Close settings - tap ⋯ → "Stage Mode"
6. ✅ Stage Mode launches with cue cards
7. ✅ Font size matches your setting
8. ✅ Text color matches your setting
9. ✅ Auto-advance toggle works
10. ✅ Swipe gestures work for manual control

---

## 📚 Documentation Files

- `STAGE_MODE_FIX_SUMMARY.md` - Complete technical summary
- `STAGE_MODE_SETTINGS_GUIDE.md` - User guide with presets
- `STAGE_MODE_INTEGRATION_STATUS.md` - Full implementation status
- `STAGE_MODE_QUICK_REFERENCE.md` - This file!

---

## 🎉 You're All Set!

Both issues are fixed and the cue card system is fully operational with comprehensive settings!
