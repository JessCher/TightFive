# Keyboard Handling Improvements - Show Notes

## Overview
Added comprehensive keyboard dismissal and text field visibility management to the Show Notes feature, ensuring a smooth note-taking experience similar to standard notes apps.

## Features Implemented

### 1. **Swipe-to-Dismiss Keyboard** 🔄
- Implemented `.dismissKeyboardOnDrag()` extension
- Dismisses keyboard when user scrolls or drags the ScrollView
- Uses `simultaneousGesture` to not interfere with scrolling behavior
- Works in both the setlist cards section and overall notes section

### 2. **Tap-to-Dismiss Keyboard** 👆
- Implemented `.dismissKeyboardOnTap()` extension
- Dismisses keyboard when user taps outside of text fields
- Allows quick dismissal without needing a dedicated "Done" button
- Applied to the entire PerformanceDetailView ScrollView

### 3. **Auto-Scroll to Active Text Field** 📍
- When a text field gains focus, the ScrollView automatically scrolls to center it
- Prevents keyboard from blocking the text being typed
- 0.4s delay allows keyboard animation to complete first
- Smooth easing animation for scroll positioning

### 4. **Smart Card Spacing** 📐
- Flipped cards get extra vertical padding (20pt top + 20pt bottom)
- Adjacent cards smoothly slide up/down when a card flips
- Ensures the flipped card's text field is never obscured by other cards
- Works in conjunction with auto-scroll for optimal visibility

### 5. **Focus Change Tracking** 🎯
- Added `onTextFieldFocus` callback to `FlippableScriptBlockCard`
- Parent view (`FlippableScriptBlockList`) tracks which card has active text input
- Triggers scroll animation when keyboard appears
- Uses `onChange(of: isNotesFocused)` to detect focus changes

## Implementation Details

### Keyboard Dismissal Extensions
```swift
extension View {
    /// Dismiss keyboard when user taps outside text fields
    func dismissKeyboardOnTap() -> some View {
        self.onTapGesture {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder), 
                to: nil, from: nil, for: nil
            )
        }
    }
    
    /// Dismiss keyboard when user drags/scrolls
    func dismissKeyboardOnDrag() -> some View {
        self.simultaneousGesture(
            DragGesture().onChanged { _ in
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder), 
                    to: nil, from: nil, for: nil
                )
            }
        )
    }
}
```

### Applied To
1. **FlippableScriptBlockList** - ScrollView for setlist cards
   - `.dismissKeyboardOnDrag()` on inner ScrollView
   - `.dismissKeyboardOnTap()` on outer container

2. **PerformanceDetailView** - Main ScrollView
   - `.dismissKeyboardOnDrag()` for scroll-to-dismiss
   - `.dismissKeyboardOnTap()` for tap-to-dismiss

### Auto-Scroll Implementation
```swift
onTextFieldFocus: {
    activeTextFieldID = block.id
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
        withAnimation(.easeInOut(duration: 0.3)) {
            proxy.scrollTo(block.id, anchor: .center)
        }
    }
}
```

## User Experience Flow

### Scenario 1: Rating a Bit
1. User taps flip button on a card
2. Card flips (3D animation)
3. Adjacent cards slide apart (spring animation)
4. ScrollView centers the flipped card
5. User taps notes field
6. Keyboard appears
7. ScrollView re-centers to keep text visible
8. **User swipes down** → Keyboard dismisses
9. Continue rating other bits

### Scenario 2: Writing Overall Notes
1. User scrolls to "Overall Show Notes" section
2. Taps the TextEditor
3. Keyboard appears
4. User types notes
5. **User swipes up** → Keyboard dismisses
6. **User taps anywhere** → Keyboard dismisses (if still visible)

### Scenario 3: Editing Multiple Cards
1. User flips first card → Scrolls to center
2. Types notes → Swipes to dismiss keyboard
3. Flips card back → Spacing collapses
4. Scrolls to next card
5. Flips second card → Auto-centers again
6. Types notes → Tap outside to dismiss
7. Seamless flow through entire setlist

## Benefits

### For Users
✅ **No manual keyboard dismissal** - Just swipe or tap
✅ **Never blocked by keyboard** - Auto-scroll keeps text visible
✅ **Smooth animations** - Professional feel
✅ **Standard iOS behavior** - Matches Notes, Messages, etc.
✅ **Fast workflow** - Rate all bits quickly without friction

### For Developers
✅ **Reusable extensions** - Can use in other views
✅ **Non-intrusive** - Uses `simultaneousGesture` to preserve scrolling
✅ **Declarative** - Simple modifier syntax
✅ **Consistent** - Same behavior across all text fields

## Technical Notes

### Why `simultaneousGesture`?
- Regular `.gesture()` would override the ScrollView's scroll gesture
- `simultaneousGesture` allows both gestures to work together
- Keyboard dismisses while scrolling still functions normally

### Why the 0.4s Delay?
- iOS keyboard appearance animation takes ~0.3-0.35s
- 0.4s ensures keyboard is fully visible before repositioning
- Prevents jarring double-scroll effect
- User perceives it as a single smooth motion

### Why `.center` Anchor?
- Centers the active card in the viewport
- Works well for both top and bottom cards
- Provides consistent positioning
- Leaves room for keyboard at bottom

### Memory Management
- Uses weak self in closures where needed
- `@State` properly manages flipped card state
- No retain cycles or memory leaks
- Focus state clears automatically on dismiss

## Compatibility

- ✅ iOS 17+
- ✅ Works with SwiftData persistence
- ✅ Compatible with existing keyboard toolbar buttons
- ✅ Respects system keyboard settings
- ✅ Works with external keyboards (dismissal is no-op)

## Future Enhancements (Optional)

- Add haptic feedback on keyboard dismiss
- Custom keyboard toolbar with rating shortcuts
- Keyboard shortcuts for quick rating (⌘1 through ⌘5)
- Voice-to-text for quick note taking
- Dictation support for hands-free notes

---

**Result:** Show Notes now has best-in-class text editing UX that feels like a native iOS notes app! 🎉
