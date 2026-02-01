# Stage Mode Types Implementation

## Overview

Stage Mode now supports three different presentation modes, all of which record audio and create performance entries with show notes. Users can choose their preferred presentation style while maintaining the core Stage Mode functionality of recording performances.

## Three Mode Types

### 1. **Cue Cards** (Default)
- Voice-driven cards with anchor and exit phrases
- Auto-advance when exit phrases are detected
- Manual swipe gestures for fallback navigation
- Speech recognition feedback indicators
- Full-screen, auto-scaled card display

**Best for:** Performers who want voice-driven navigation and phrase-based prompts

### 2. **Script**
- Static scrollable script view
- Same layout as Run Mode Script
- Manual scrolling through setlist content
- Displays all script blocks sequentially

**Best for:** Performers who prefer reading a traditional script while recording

### 3. **Teleprompter**
- Auto-scrolling teleprompter view
- Adjustable scroll speed and font size
- Context window with dimmed surrounding text
- Voice-aware anchor phrase scrolling

**Best for:** Performers who want auto-scrolling text while recording

## Key Distinction

**Stage Mode (all types):**
- ✅ Records audio
- ✅ Creates Performance entry
- ✅ Generates Show Notes tab
- ✅ Full-screen immersive experience
- ✅ Saves recording with duration and file size

**Run Mode:**
- ❌ No recording
- ❌ No performance tracking
- ✅ Practice timer
- ✅ Multiple display modes
- ✅ Perfect for rehearsal

## Implementation Details

### Files Modified

1. **CueCardSettingsStore.swift**
   - Added `StageModeType` enum with three cases
   - Added `stageModeType` property to store user preference
   - Updated `resetToDefaults()` to include mode type

2. **CueCardSettingsView.swift**
   - Added "Stage Mode Type" section at top
   - Picker to select between Cue Cards, Script, and Teleprompter
   - Conditional display of cue card-specific settings
   - Reorganized into separate view components for clarity

3. **StageModeView.swift**
   - Updated wrapper to route based on `CueCardSettingsStore.shared.stageModeType`
   - Routes to appropriate implementation:
     - `.cueCards` → `StageModeViewCueCard`
     - `.script` → `StageModeViewScript`
     - `.teleprompter` → `StageModeViewTeleprompter`

4. **StageModeViewScript.swift** (NEW)
   - Clone of Run Mode Script functionality
   - Integrated with `CueCardEngine` for recording
   - Uses Stage Mode settings for font size, line spacing, and text color
   - Includes exit confirmation and save confirmation overlays
   - Recording indicator in top bar

### Files Already Existing

5. **StageModeViewTeleprompter.swift** (EXISTING)
   - Already implemented with recording functionality
   - Uses `StageTeleprompterEngine` for voice-aware scrolling
   - Anchor phrase detection for automatic scrolling

6. **StageModeViewCueCard.swift** (EXISTING)
   - Original cue card implementation
   - Full voice-driven navigation
   - Exit and anchor phrase detection

## Settings Integration

### Global Settings Access

Users can access Stage Mode settings from two locations:

1. **Within Stage Mode**
   - Tap gear icon while in Stage Mode

2. **Global Settings Page**
   - Settings → Stage Mode → Stage Mode Settings
   - Allows configuration before entering Stage Mode

### Settings Sections

The settings view dynamically shows/hides sections based on selected mode:

- **Stage Mode Type** - Always visible
- **Auto-Advance** - Only for Cue Cards
- **Speech Recognition** - Only for Cue Cards  
- **Display** - Always visible (applies to all modes)
- **Animations** - Only for Cue Cards

## User Experience

1. User selects a setlist
2. Taps "Enter Stage Mode"
3. Based on their selected mode type in settings:
   - **Cue Cards:** Full-screen cards with voice navigation
   - **Script:** Scrollable script with recording
   - **Teleprompter:** Auto-scrolling text with recording
4. Recording starts automatically on entry
5. When user exits, performance is saved with:
   - Audio recording
   - Duration
   - File size
   - Show notes tab
   - Performance insights

## Benefits

- **Flexibility:** Users choose presentation style that works best for them
- **Consistency:** All modes record and track performances
- **Clear Separation:** Stage Mode = Performance, Run Mode = Practice
- **Reusability:** Leverages existing Run Mode UI components
- **Discoverability:** Settings clearly explain each mode type

## Future Enhancements

Potential additions:
- Per-setlist mode preferences
- Quick mode switcher in Stage Mode UI
- Mode-specific analytics in Show Notes
- Custom teleprompter settings for Stage Mode
- Hybrid modes (e.g., cards with teleprompter fallback)
