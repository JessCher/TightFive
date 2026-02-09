# Shareable Bit Cards Migration Guide

## Overview
The shareable bit cards customization system has been refactored to use the same architecture as tile cards and the Quick Bit button, providing a consistent and unified customization experience.

## What Changed

### Removed Types
- ❌ `BitCardFrameColor` enum
- ❌ `BitWindowTheme` enum

### Now Using
- ✅ `TileCardTheme` enum for all three sections (frame, bottom bar, window)

## Property Changes

### Theme Properties (All now use `TileCardTheme`)

| Old Property | New Property | Default Value |
|-------------|--------------|---------------|
| `bitCardFrameColor: BitCardFrameColor` | `bitCardFrameTheme: TileCardTheme` | `.darkGrit` |
| `bitCardBottomBarColor: BitCardFrameColor` | `bitCardBottomBarTheme: TileCardTheme` | `.darkGrit` |
| `bitWindowTheme: BitWindowTheme` | `bitCardWindowTheme: TileCardTheme` | `.darkGrit` |

### Custom Color Properties (Renamed for clarity)

| Old Property | New Property |
|-------------|--------------|
| `customFrameColorHex` | `bitCardFrameCustomColorHex` |
| `customBottomBarColorHex` | `bitCardBottomBarCustomColorHex` |
| `customWindowColorHex` | `bitCardWindowCustomColorHex` |

### Grit Colors (Updated defaults to match tile cards)

All grit layer colors now default to the tile card color scheme:
- Layer 1: `#F4C430` (yellow)
- Layer 2: `#FFFFFF4D` (white with opacity)
- Layer 3: `#FFFFFF1A` (white with lower opacity)

**Old defaults were:**
- Layer 1: `#8B4513` (brown)
- Layer 2: `#000000` (black)
- Layer 3: `#CC6600` (orange)

### Removed Properties

- ❌ `bitCardGritLevel` (global grit level removed; use individual section settings)
- ❌ `adjustedBitCardGritDensity()` helper method

## `TileCardTheme` Enum

```swift
enum TileCardTheme: String, CaseIterable, Identifiable {
    case darkGrit = "darkGrit"
    case yellowGrit = "yellowGrit"
    case custom = "custom"

    var displayName: String {
        switch self {
        case .darkGrit: return "Dark Grit"
        case .yellowGrit: return "Yellow Grit"
        case .custom: return "Custom"
        }
    }

    var baseColor: Color {
        switch self {
        case .darkGrit: return Color("TFCard")
        case .yellowGrit: return Color("TFYellow")
        case .custom: return Color("TFCard") // Fallback
        }
    }
}
```

## Code Migration Examples

### Example 1: Accessing Frame Theme

**Before:**
```swift
let frameColor = AppSettings.shared.bitCardFrameColor
if frameColor == .chalkboard {
    // Dark grit theme
}
```

**After:**
```swift
let frameTheme = AppSettings.shared.bitCardFrameTheme
if frameTheme == .darkGrit {
    // Dark grit theme
}
```

### Example 2: Getting Custom Colors

**Before:**
```swift
let customColor = AppSettings.shared.customFrameColorHex
```

**After:**
```swift
let customColor = AppSettings.shared.bitCardFrameCustomColorHex
```

### Example 3: Rendering a Themed Element

**Before:**
```swift
let frameColor = settings.bitCardFrameColor.color(customHex: settings.customFrameColorHex)
let hasTexture = settings.bitCardFrameColor.hasTexture
```

**After:**
```swift
// Get base color based on theme
let frameColor: Color = {
    switch settings.bitCardFrameTheme {
    case .darkGrit:
        return Color("TFCard")
    case .yellowGrit:
        return Color("TFYellow")
    case .custom:
        return Color(hex: settings.bitCardFrameCustomColorHex) ?? Color("TFCard")
    }
}()

// Check if grit should be rendered
let hasTexture = (settings.bitCardFrameTheme != .custom) || 
                 (settings.bitCardFrameTheme == .custom && settings.bitCardFrameGritEnabled)
```

### Example 4: Theme Picker

**Before:**
```swift
Picker("Frame Color", selection: $settings.bitCardFrameColor) {
    ForEach(BitCardFrameColor.allCases) { color in
        Text(color.displayName).tag(color)
    }
}
```

**After:**
```swift
Picker("Frame Theme", selection: $settings.bitCardFrameTheme) {
    ForEach(TileCardTheme.allCases) { theme in
        Text(theme.displayName).tag(theme)
    }
}
```

### Example 5: Conditional Customization UI

**Before:**
```swift
if settings.bitCardFrameColor == .custom {
    ColorPicker("Custom Frame Color", selection: $customColor)
    Toggle("Enable Grit", isOn: $settings.bitCardFrameGritEnabled)
    
    if settings.bitCardFrameGritEnabled {
        // Show grit color pickers
    }
}
```

**After:**
```swift
if settings.bitCardFrameTheme == .custom {
    ColorPicker("Custom Frame Color", selection: $customColor)
    Toggle("Enable Grit", isOn: $settings.bitCardFrameGritEnabled)
    
    if settings.bitCardFrameGritEnabled {
        ColorPicker("Grit Layer 1", selection: $gritLayer1Color)
        ColorPicker("Grit Layer 2", selection: $gritLayer2Color)
        ColorPicker("Grit Layer 3", selection: $gritLayer3Color)
    }
}
```

## Benefits of This Change

1. **Consistency**: All customizable elements (tile cards, Quick Bit button, shareable bit cards) now use the same theme system
2. **Simplified Code**: Fewer enum types to maintain
3. **Better Defaults**: Grit colors now default to the more appealing yellow/white scheme
4. **Unified UX**: Users learn one customization pattern that applies everywhere
5. **Easier Maintenance**: Changes to theme behavior apply consistently across all elements

## Testing Checklist

- [ ] Frame theme picker displays correctly
- [ ] Bottom bar theme picker displays correctly
- [ ] Window theme picker displays correctly
- [ ] Custom color pickers appear when `.custom` is selected
- [ ] Grit toggles work correctly
- [ ] Grit color pickers appear when grit is enabled
- [ ] Preview updates in real-time when settings change
- [ ] Settings persist correctly across app launches
- [ ] Settings sync across devices via iCloud

## Files That Need Updates

You'll need to search your codebase for:
- `BitCardFrameColor`
- `BitWindowTheme`
- `bitCardFrameColor`
- `bitCardBottomBarColor`
- `bitWindowTheme`
- `customFrameColorHex`
- `customBottomBarColorHex`
- `customWindowColorHex`
- `bitCardGritLevel`
- `adjustedBitCardGritDensity`

Common locations:
- Settings/customization views
- Bit card rendering views
- Preview components
- Export/sharing functionality
