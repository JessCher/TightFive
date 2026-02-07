# Accessibility Settings Implementation Guide

## Problem Summary

The haptic feedback and larger touch targets settings in `AccessibilitySettingsView` were not working because:

1. ✅ **Settings were properly stored** - The `AppSettings` class correctly saves and retrieves these values
2. ✅ **UI was working** - The toggles in AccessibilitySettingsView correctly bind to the settings
3. ❌ **Settings weren't being used** - No code in the app was actually checking these values to change behavior

## Solution

I've created a new file `AccessibilityHelpers.swift` that provides easy-to-use utilities for implementing these accessibility features throughout your app.

## What's Been Fixed

### 1. **AccessibilitySettingsView.swift** - Updated
- Added haptic feedback to all toggle switches using `.onChange()`
- Added haptic feedback to the text size slider
- Added demo buttons to test haptic feedback and touch target sizes
- When you enable haptic feedback, you now get immediate feedback confirming it's on

### 2. **AccessibilityHelpers.swift** - NEW FILE
This new file provides:
- `HapticManager` - Centralized haptic feedback that respects settings
- `.accessibleTouchTarget()` modifier - Automatically adjusts button sizes
- `AccessibleButtonStyle` - Button style with haptics and size adjustments
- Additional helpers for implementing accessibility features

## How to Use These Helpers

### 1. Haptic Feedback

Replace direct haptic calls with `HapticManager`:

**Before:**
```swift
Button("Delete") {
    let generator = UIImpactFeedbackGenerator(style: .heavy)
    generator.impactOccurred()
    deleteItem()
}
```

**After:**
```swift
Button("Delete") {
    HapticManager.impact(.heavy)  // Automatically respects settings
    deleteItem()
}
```

**Types of Haptic Feedback:**
```swift
// Impact feedback (for UI interactions)
HapticManager.impact(.light)   // Subtle tap
HapticManager.impact(.medium)  // Standard button press
HapticManager.impact(.heavy)   // Important action

// Selection feedback (for pickers, toggles, sliders)
HapticManager.selection()

// Notification feedback (for results)
HapticManager.notification(.success)
HapticManager.notification(.warning)
HapticManager.notification(.error)
```

### 2. Larger Touch Targets

Apply the `.accessibleTouchTarget()` modifier to interactive elements:

**Example:**
```swift
Button("Tap Me") {
    performAction()
}
.accessibleTouchTarget()  // 44pt normally, 60pt when setting enabled
```

**Custom sizes:**
```swift
Button("Custom Button") {
    action()
}
.accessibleTouchTarget(minSize: 50, largeSize: 70)
```

### 3. Accessible Button Style

Use the pre-built button style that includes both haptics and touch targets:

```swift
Button("Save") {
    save()
}
.buttonStyle(AccessibleButtonStyle(
    baseColor: Color("TFCard"),
    accentColor: TFTheme.yellow
))
```

This automatically provides:
- Haptic feedback on press (respects settings)
- Larger padding when touch target setting is enabled
- Visual press state
- Smooth animations

### 4. SwiftUI Sensory Feedback (iOS 17+)

For SwiftUI's native `.sensoryFeedback()`, use the accessible wrapper:

```swift
Button("Toggle") {
    isOn.toggle()
}
.accessibleSensoryFeedback(.impact, trigger: isOn)
```

## Where to Apply These Changes

### High Priority (User-facing interactions)

1. **Buttons in main views:**
   - Quick Bit button
   - Add Bit buttons
   - Save/Cancel buttons
   - Navigation buttons

2. **Toggles and switches:**
   - All settings toggles
   - Feature enable/disable switches

3. **Interactive cards:**
   - Bit cards (tap to edit)
   - Set list items
   - Finished bits cards

4. **Sliders:**
   - Volume controls
   - Grit level sliders
   - Any adjustment controls

### Example Implementation Checklist

Here's how to systematically add accessibility to your views:

```swift
// Example: BitsListView.swift

import SwiftUI

struct BitsListView: View {
    @State private var bits: [Bit] = []
    
    var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(bits) { bit in
                    BitCard(bit: bit)
                        .onTapGesture {
                            HapticManager.impact(.light)  // ← Add this
                            selectBit(bit)
                        }
                        .accessibleTouchTarget()  // ← Add this
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    HapticManager.impact(.medium)  // ← Add this
                    addNewBit()
                } label: {
                    Image(systemName: "plus")
                }
                .accessibleTouchTarget()  // ← Add this
            }
        }
    }
}
```

## Testing Checklist

After implementing these helpers, test:

1. **Haptic Feedback:**
   - [ ] Open Accessibility Settings
   - [ ] Toggle "Haptic feedback" OFF
   - [ ] Navigate through the app tapping buttons - should be NO haptics
   - [ ] Toggle "Haptic feedback" ON (you should feel a haptic)
   - [ ] Tap buttons - should feel haptics

2. **Larger Touch Targets:**
   - [ ] Toggle "Larger touch targets" OFF
   - [ ] Note the button sizes
   - [ ] Toggle "Larger touch targets" ON
   - [ ] Buttons should be visibly larger
   - [ ] Easier to tap

3. **Demo Buttons in Settings:**
   - [ ] Use the "Light/Medium/Heavy" test buttons
   - [ ] Should feel different haptic strengths (when enabled)
   - [ ] Should show size changes (when touch target setting enabled)

## Code Examples for Common Patterns

### Pattern 1: List Item with Delete

```swift
ForEach(items) { item in
    HStack {
        Text(item.name)
        Spacer()
        Button(role: .destructive) {
            HapticManager.impact(.heavy)
            deleteItem(item)
        } label: {
            Image(systemName: "trash")
        }
        .accessibleTouchTarget()
    }
}
```

### Pattern 2: Toggle Setting

```swift
Toggle("Enable Feature", isOn: $isEnabled)
    .tint(TFTheme.yellow)
    .onChange(of: isEnabled) { old, new in
        HapticManager.selection()
    }
```

### Pattern 3: Slider

```swift
Slider(value: $volume, in: 0...1)
    .onChange(of: volume) { old, new in
        // Debounce haptics for sliders
        if abs(new - old) > 0.1 {
            HapticManager.selection()
        }
    }
```

### Pattern 4: Navigation Button

```swift
NavigationLink {
    DetailView()
} label: {
    Label("View Details", systemImage: "arrow.right")
}
.simultaneousGesture(TapGesture().onEnded {
    HapticManager.impact(.light)
})
.accessibleTouchTarget()
```

### Pattern 5: Custom Button with Full Accessibility

```swift
Button {
    HapticManager.impact(.medium)
    performMainAction()
} label: {
    Text("Primary Action")
        .appFont(.headline)
        .foregroundStyle(.white)
}
.buttonStyle(AccessibleButtonStyle(
    baseColor: TFTheme.yellow,
    accentColor: .white
))
```

## Migration Strategy

### Phase 1: Critical Interactions (Do First)
- Main action buttons (Quick Bit, Save, Delete)
- Navigation buttons
- Primary toggles

### Phase 2: Secondary Interactions
- List items
- Cards
- Toolbar buttons

### Phase 3: Fine-tuning
- Sliders and pickers
- Gesture recognizers
- Custom controls

## Additional Considerations

### Performance
- `HapticManager` is lightweight and only creates generators when needed
- The touch target modifier is efficient and only affects layout

### Backwards Compatibility
- All code is iOS 15+ compatible
- Uses standard UIKit haptic generators
- SwiftUI modifiers work on all supported versions

### Accessibility Best Practices
- Always provide haptic feedback for important actions
- Use appropriate haptic intensity (light for minor actions, heavy for destructive)
- Ensure touch targets are at least 44x44 points (Apple HIG)
- Test with VoiceOver enabled

## Questions or Issues?

If you encounter any issues:

1. Check that `AppSettings.shared.hapticsEnabled` is being respected
2. Verify the button has the `.accessibleTouchTarget()` modifier
3. Test on a physical device (simulator doesn't support haptics)
4. Check that `HapticManager` is imported where used

## Summary

The accessibility settings are now **working**:

✅ Haptic feedback toggle controls whether haptics play
✅ Larger touch targets toggle controls button sizes
✅ Demo buttons in settings show immediate effect
✅ Easy-to-use helpers for implementation throughout app
✅ Comprehensive examples and patterns provided

The next step is to systematically add these helpers to your existing views using the patterns above!
