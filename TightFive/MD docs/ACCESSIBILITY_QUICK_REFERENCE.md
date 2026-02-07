# Quick Reference: Accessibility Helpers

## 🎯 Quick Start

### Add Haptic Feedback
```swift
Button("Action") {
    HapticManager.impact(.medium)  // ← Add this line
    performAction()
}
```

### Make Button Easier to Tap
```swift
Button("Action") { 
    action() 
}
.accessibleTouchTarget()  // ← Add this modifier
```

### Both Together
```swift
Button("Save") {
    HapticManager.impact(.medium)
    save()
}
.buttonStyle(AccessibleButtonStyle(
    baseColor: Color("TFCard"),
    accentColor: TFTheme.yellow
))
// ↑ This includes haptics + touch targets + styling
```

---

## 📱 Haptic Types

| Use Case | Code | When to Use |
|----------|------|-------------|
| Light tap | `HapticManager.impact(.light)` | Minor UI interactions, list selections |
| Standard press | `HapticManager.impact(.medium)` | Button presses, standard actions |
| Important action | `HapticManager.impact(.heavy)` | Delete, save, destructive actions |
| Selection changed | `HapticManager.selection()` | Toggles, pickers, sliders |
| Success | `HapticManager.notification(.success)` | Action completed successfully |
| Warning | `HapticManager.notification(.warning)` | Warning state |
| Error | `HapticManager.notification(.error)` | Action failed |

---

## 🎨 Common Patterns

### Toggle
```swift
Toggle("Setting", isOn: $value)
    .onChange(of: value) { _, _ in
        HapticManager.selection()
    }
```

### List Item
```swift
Button {
    HapticManager.impact(.light)
    select(item)
} label: {
    ItemRow(item)
}
.accessibleTouchTarget()
```

### Delete Button
```swift
Button(role: .destructive) {
    HapticManager.impact(.heavy)
    delete()
} label: {
    Label("Delete", systemImage: "trash")
}
.accessibleTouchTarget()
```

### Navigation
```swift
NavigationLink {
    DetailView()
} label: {
    Text("Details")
}
.simultaneousGesture(TapGesture().onEnded {
    HapticManager.impact(.light)
})
.accessibleTouchTarget()
```

### Slider
```swift
Slider(value: $amount)
    .onChange(of: amount) { old, new in
        // Optional: debounce for smoother experience
        if abs(new - old) > 0.1 {
            HapticManager.selection()
        }
    }
```

---

## ✅ Testing

1. Go to Settings → Accessibility
2. Toggle "Haptic feedback" and "Larger touch targets"
3. Use the demo buttons to verify
4. Test on physical device (simulator doesn't support haptics)

---

## 💡 Pro Tips

- **Don't overdo it**: Not every tiny interaction needs haptics
- **Match intensity to importance**: Light for minor, heavy for major
- **Respect user settings**: Always use `HapticManager`, never direct UIKit calls
- **Test on device**: Simulator can't reproduce haptic feel
- **Consider battery**: Excessive haptics drain battery

---

## 🚫 Common Mistakes

### ❌ DON'T
```swift
// Direct haptic call (ignores settings)
let generator = UIImpactFeedbackGenerator()
generator.impactOccurred()
```

### ✅ DO
```swift
// Respects accessibility settings
HapticManager.impact(.medium)
```

---

## 📦 Files Involved

- `AccessibilityHelpers.swift` - The helper utilities
- `AccessibilitySettingsView.swift` - Settings UI
- `AppSettings.swift` - Settings storage
- `ACCESSIBILITY_IMPLEMENTATION_GUIDE.md` - Full documentation

---

## Need Help?

See `ACCESSIBILITY_IMPLEMENTATION_GUIDE.md` for:
- Detailed examples
- Migration strategy  
- Troubleshooting
- Best practices
