# Stage Mode Timer Addition

## Summary
Added performance timers to both Stage Mode Script and Stage Mode Teleprompter views to help users keep track of time during their performances.

## Changes Made

### 1. StageModeViewScript.swift
**Added timer state variables:**
- `elapsedTime: TimeInterval` - Tracks elapsed time in seconds
- `isTimerRunning: Bool` - Tracks whether timer is running
- `timer: Timer?` - The actual timer instance

**Updated top bar:**
- Added timer display between the close button and recording indicator
- Timer shows elapsed time in MM:SS format
- Timer is tappable to pause/resume
- Color changes based on state (yellow when running, white when paused)
- Uses play/pause icon to indicate current state

**Timer behavior:**
- Automatically starts when performance begins
- Stops automatically when view is dismissed
- Can be paused/resumed by tapping the timer display
- Continues running in the background during the entire performance

### 2. StageModeViewTeleprompter.swift
**Added timer state variables:**
- Same as Script view

**Updated top bar:**
- Added timer display between close button and recording indicator
- Timer is non-interactive (displays only) - uses clock icon instead of play/pause
- Syncs with teleprompter play/pause button
- Color changes based on state (yellow when running, white when paused)

**Timer behavior:**
- Automatically starts when performance begins
- Stops automatically when view is dismissed
- Syncs with teleprompter scrolling state via play/pause button
- When teleprompter is paused, timer pauses
- When teleprompter resumes, timer resumes

**Synced control:**
- The play/pause button on the right now controls both:
  1. Teleprompter scrolling (existing behavior)
  2. Timer state (new behavior)

## Design Details

### Timer Display Format
- Monospaced digits for stable display
- Format: `M:SS` or `MM:SS` (e.g., "0:45", "12:30")
- Capsule-shaped background with subtle transparency
- Icon changes based on mode:
  - **Script mode**: play/pause icon (interactive)
  - **Teleprompter mode**: clock icon (display only)

### Visual Styling
- Uses TFTheme.yellow when active
- Fades to white opacity when paused
- Consistent with existing Stage Mode design language
- Positioned centrally in top bar for easy visibility

### User Experience
- **Script Mode**: Users can pause/resume independently by tapping timer
- **Teleprompter Mode**: Timer syncs with scroll state for unified control
- Both modes auto-start for minimal friction
- Timer stops cleanly on dismiss to prevent memory leaks

## Implementation Notes

### Timer Management
- Uses Foundation's `Timer` class with 1-second intervals
- Added to main run loop in `.common` mode for reliability
- Properly invalidated in `onDisappear` to prevent memory leaks
- Stopped before engine cleanup to ensure proper session end

### State Synchronization (Teleprompter)
The `toggleTeleprompter()` function ensures:
```swift
private func toggleTeleprompter() {
    isTeleprompterPlaying.toggle()
    // Sync timer with teleprompter
    if isTeleprompterPlaying && !isTimerRunning {
        startTimer()
    } else if !isTeleprompterPlaying && isTimerRunning {
        stopTimer()
    }
}
```

This ensures the timer and teleprompter are always in sync.

## Future Enhancements (Optional)
- Add elapsed time to performance metadata for analytics
- Allow users to set countdown timers
- Add lap/split time markers at key moments
- Visual/haptic alerts at custom time intervals
- Timer color customization in settings
