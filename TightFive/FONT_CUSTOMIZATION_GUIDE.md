# Font Customization Guide

## Overview
Users can now customize font family, color, and size throughout the app. These settings persist across app launches and are stored in UserDefaults.

## What's Been Added

### 1. AppSettings.swift
- `appFontColorHex: String` - Stores custom font color as hex (default: "#FFFFFF" white)
- `appFontSizeMultiplier: Double` - Stores font size multiplier (default: 1.0, range: 0.8-1.4)
- `fontColor: Color` - Computed property that returns the custom font color

### 2. TFTheme.swift
- `TFTheme.text: Color` - Dynamic property that returns the user's custom font color
- Use this instead of `.white` for text that should respect the custom color

### 3. FontExtensions 2.swift
- Updated `.appFont()` modifiers to automatically apply size multiplier
- All existing uses of `.appFont()` now respect the custom size
- Added `.appFontColor()` modifier as an alternative way to apply custom color

### 4. SettingsView.swift
- Added ColorPicker for font color with hex input
- Added Slider for font size (80%-140%) with percentage display  
- Added FontPreview component to show changes in real-time
- Settings save immediately when changed

## How to Use Custom Font Color

### Option 1: Use TFTheme.text (Recommended)
```swift
Text("Hello World")
    .appFont(.headline)
    .foregroundStyle(TFTheme.text)  // Uses custom font color
```

### Option 2: Use .appFontColor() modifier
```swift
Text("Hello World")
    .appFont(.headline)
    .appFontColor()  // Applies custom font color
```

### Option 3: Direct access
```swift
Text("Hello World")
    .appFont(.headline)
    .foregroundStyle(AppSettings.shared.fontColor)
```

## Applying to Existing Views

To make existing text respect the custom color, replace:
```swift
.foregroundStyle(.white)
```

With:
```swift
.foregroundStyle(TFTheme.text)
```

For text with opacity:
```swift
// Before
.foregroundStyle(.white.opacity(0.6))

// After
.foregroundStyle(TFTheme.text.opacity(0.6))
```

## Font Size

The font size multiplier is **automatically applied** to all text using `.appFont()` modifiers. No changes needed!

```swift
// This text will automatically scale with the user's size preference
Text("Scales automatically")
    .appFont(.body)
```

## Views Already Updated

- ✅ **HomeView.swift** - Tile cards now use `TFTheme.text`
- ✅ **SettingsView.swift** - Preview section shows font customization

## Views That Need Updating

To fully apply custom font color throughout the app, update these views to use `TFTheme.text` instead of `.white`:

- **SetlistsView.swift** - Tile cards
- **RunModeView.swift** - Setlist rows
- **MoreView.swift** - Settings cards
- **LooseBitsView.swift** - Bit cards
- **FinishedBitsView.swift** - Bit cards
- **ShowNotesView.swift** - Performance rows
- All other views with text

## Quick Search & Replace

To update all views at once:

1. Search for: `.foregroundStyle(.white)`
2. Replace with: `.foregroundStyle(TFTheme.text)`

3. Search for: `.foregroundStyle(.white.opacity(`
4. Replace with: `.foregroundStyle(TFTheme.text.opacity(`

## Testing

1. Go to Settings → Theme Customization
2. Change "Font Color" to any color
3. Adjust "Font Size" slider
4. Navigate through the app to see changes
5. Restart app to verify persistence

## Notes

- Font size changes apply immediately to all text using `.appFont()`
- Font color requires views to use `TFTheme.text` instead of `.white`
- Settings are saved to UserDefaults automatically
- Default values: White color (#FFFFFF), 100% size (1.0)
