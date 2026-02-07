# TightFive Accessibility Implementation Guide

This guide explains how the accessibility settings in TightFive work and how to implement them throughout the app.

## Overview

The app now supports 6 accessibility settings:
1. **Reduce Motion** - Disables animations
2. **High Contrast** - Increases visual contrast
3. **Bold Text** - Makes all text bold
4. **Text Size** - Adjusts font size (80% to 160%)
5. **Haptic Feedback** - Controls vibration feedback
6. **Larger Touch Targets** - Increases button sizes

## Implementation Details

### 1. Bold Text
**Location:** `FontExtensions.swift`

Bold text is automatically applied through the `.appFont()` modifier. When `AppSettings.shared.boldText` is enabled, all text using `.appFont()` will render with bold weight.

```swift
// Automatically respects bold text setting
Text("Hello World")
    .appFont(.headline)
```

### 2. Reduce Motion
**Location:** `FontExtensions.swift`

Use `.accessibleAnimation()` instead of `.animation()`:

```swift
// Before:
myView
    .animation(.spring(), value: someValue)

// After:
myView
    .accessibleAnimation(.spring(), value: someValue)
```

Or use the global function:

```swift
// Before:
withAnimation {
    someValue = newValue
}

// After:
withAccessibleAnimation {
    someValue = newValue
}
```

### 3. High Contrast
**Location:** `FontExtensions.swift`, `DynamicTexturedCard.swift`

High contrast mode automatically increases:
- Border thickness (1.5pt → 2.5pt)
- Shadow opacity (0.6 → 0.8)
- Shadow radius (4pt → 6pt)
- Border opacity (0.9 → 1.0)

Apply to custom views:

```swift
myView
    .accessibleContrast()
```

### 4. Text Size
**Location:** `FontExtensions.swift`

Automatically handled by `.appFont()` modifier. No additional code needed.

### 5. Haptic Feedback
**Location:** `FontExtensions.swift`

Use the helper function:

```swift
// In a button or tap gesture:
Button("Tap Me") {
    // Trigger haptic feedback
    Text("").hapticFeedback(.light)
    
    // Your action code
    doSomething()
}
```

Or use the `AccessibleButtonStyle`:

```swift
Button("Tap Me") {
    doSomething()
}
.buttonStyle(AccessibleButtonStyle())
```

### 6. Larger Touch Targets
**Location:** `FontExtensions.swift`

Apply to buttons and tappable elements:

```swift
Button("Tap Me") {
    doSomething()
}
.accessibleTapTarget()  // Adds 4pt padding when enabled
```

## VoiceOver Support

All controls in `AccessibilitySettingsView` now have proper VoiceOver labels:

- **accessibilityLabel**: Describes what the control is
- **accessibilityHint**: Describes what the control does
- **accessibilityValue**: For sliders, describes current value
- **accessibilityAddTraits(.isHeader)**: Marks section headers
- **accessibilityHidden(true)**: Hides decorative elements

### Example Implementation:

```swift
Toggle("Feature", isOn: $isEnabled)
    .labelsHidden()
    .accessibilityLabel("Enable feature")
    .accessibilityHint("Turns the feature on or off")

Slider(value: $volume, in: 0...100)
    .accessibilityLabel("Volume")
    .accessibilityValue("\(Int(volume)) percent")
    .accessibilityHint("Adjusts the volume level")
```

## Best Practices

### 1. Use Semantic Modifiers
Always use `.appFont()` instead of `.font()` to ensure text size and bold settings apply.

### 2. Replace All Animations
Search your codebase for:
- `.animation()` → Replace with `.accessibleAnimation()`
- `withAnimation` → Replace with `withAccessibleAnimation`

### 3. Add Accessibility Labels to All Interactive Elements
Every Button, Toggle, Slider, and TextField should have:
- Clear `.accessibilityLabel()`
- Descriptive `.accessibilityHint()`
- Appropriate traits (`.accessibilityAddTraits()`)

### 4. Group Related Content
Use `.accessibilityElement(children: .combine)` to combine labels and descriptions:

```swift
VStack(alignment: .leading) {
    Text("Setting Name")
    Text("Setting description")
}
.accessibilityElement(children: .combine)
```

### 5. Hide Decorative Elements
Use `.accessibilityHidden(true)` on purely decorative elements:

```swift
Image("decorative-pattern")
    .accessibilityHidden(true)
```

## Testing Checklist

### Bold Text
- [ ] All text becomes bold when enabled
- [ ] Layout doesn't break with bold text

### Reduce Motion
- [ ] No animations play when enabled
- [ ] Transitions are instant
- [ ] Functionality remains intact

### High Contrast
- [ ] Borders are more visible
- [ ] Shadows are darker
- [ ] Text is easier to read

### Text Size
- [ ] Slider adjusts all text in app
- [ ] Layout adapts to larger text
- [ ] Nothing gets cut off

### Haptic Feedback
- [ ] Buttons vibrate when enabled
- [ ] No vibration when disabled
- [ ] Appropriate feedback intensity

### Larger Touch Targets
- [ ] Buttons are easier to tap when enabled
- [ ] No overlap between adjacent buttons
- [ ] Layout remains balanced

### VoiceOver
- [ ] All controls are announced correctly
- [ ] Hints provide context
- [ ] Navigation is logical
- [ ] State changes are announced
- [ ] Sliders announce values

## Examples in Codebase

See these files for reference implementations:
- `AccessibilitySettingsView.swift` - Complete VoiceOver implementation
- `FontExtensions.swift` - All accessibility modifiers
- `DynamicTexturedCard.swift` - High contrast implementation
- `FlippableBitCard.swift` - Accessible animation example

## Migration Guide

To add accessibility support to existing views:

1. Find all `.animation()` calls and replace with `.accessibleAnimation()`
2. Find all `withAnimation` calls and replace with `withAccessibleAnimation`
3. Add `.accessibilityLabel()` to all interactive controls
4. Apply `.accessibleTapTarget()` to all buttons
5. Add haptic feedback with `.hapticFeedback()` in button actions
6. Test with VoiceOver enabled
7. Verify settings work by toggling them in Accessibility Settings
