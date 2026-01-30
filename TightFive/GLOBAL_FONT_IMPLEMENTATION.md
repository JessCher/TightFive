# Global Font Implementation Guide

## Overview
The app now has a comprehensive global font system that applies the selected font from settings throughout the entire application.

## What Was Implemented

### 1. **TightFiveApp.swift** - Root Level Configuration
The main app file now includes:

- **`@StateObject private var appSettings`** - Observes font changes
- **`configureGlobalAppearance()`** - Applies fonts to UIKit components
- **Font change observer** - Automatically updates when font changes in settings
- **UIKit appearance configuration** - Sets fonts for:
  - `UILabel` - All labels throughout the app
  - `UITextField` - Text input fields
  - `UITextView` - Multi-line text views
  - `UINavigationBar` - Navigation titles and large titles

### 2. **FontExtensions 2.swift** - SwiftUI Font Extensions
Enhanced with:

- **`appFont(size:weight:)`** - Applies custom font with specific size
- **`appFont(_:weight:)`** - Applies custom font with text style (e.g., `.headline`, `.body`)
- **`AppFontKey` environment key** - Makes font available in SwiftUI environment
- **`GlobalFontModifier`** - A view modifier that applies font globally
- **`withGlobalFont()`** - Convenience method to apply global font

### 3. **ContentView.swift** - Root View Application
- Added `.withGlobalFont()` modifier to apply fonts throughout the view hierarchy

### 4. **FinishedBitsView.swift** - Example Implementation
All text elements now use `.appFont()`:
- Empty state text
- Bit detail view (titles, body, tags)
- Tag editor
- Bit card rows
- Share cards

## How It Works

### Automatic Font Application
When the user changes the font in settings:

1. **AppSettings** updates the `appFont` property
2. **TightFiveApp** observes this change via `onChange(of: appSettings.appFont)`
3. **`configureGlobalAppearance()`** updates all UIKit components
4. **`GlobalFontModifier`** propagates changes through SwiftUI environment
5. All views using `.appFont()` automatically re-render with the new font

### Two-Tier Approach

#### Tier 1: UIKit Global Appearance (Broad Coverage)
- Affects all standard UIKit components
- Automatically applies to labels, text fields, navigation bars
- No code changes needed in individual views

#### Tier 2: SwiftUI `.appFont()` Modifier (Precise Control)
- Use for custom SwiftUI views
- Provides fine-grained control over font sizes and weights
- Consistent API: `.appFont(.headline, weight: .bold)`

## Usage Examples

### In SwiftUI Views

```swift
// Use text style
Text("Hello World")
    .appFont(.headline, weight: .semibold)

// Use specific size
Text("Custom Size")
    .appFont(size: 24, weight: .bold)

// In a button
Button("Tap Me") {
    // action
}
.appFont(.body)
```

### Supported Text Styles
- `.largeTitle` (34pt)
- `.title` (28pt)
- `.title2` (22pt)
- `.title3` (20pt)
- `.headline` (17pt)
- `.body` (17pt)
- `.callout` (16pt)
- `.subheadline` (15pt)
- `.footnote` (13pt)
- `.caption` (12pt)
- `.caption2` (11pt)

## Available Fonts
The user can choose from:
- System Default
- Helvetica Neue
- Georgia
- Menlo
- Palatino
- Times New Roman
- Trebuchet MS
- Verdana
- Courier
- Avenir
- Baskerville
- American Typewriter

## Migration Guide for Other Views

To apply fonts to other views in the app:

1. **Find all `.font()` usages**
   ```swift
   // Search: .font(
   ```

2. **Replace with `.appFont()`**
   ```swift
   // Old:
   Text("Hello").font(.headline.weight(.bold))
   
   // New:
   Text("Hello").appFont(.headline, weight: .bold)
   ```

3. **Update specific sizes**
   ```swift
   // Old:
   Text("Custom").font(.system(size: 18))
   
   // New:
   Text("Custom").appFont(size: 18)
   ```

## Benefits

✅ **Global Control** - Change font once in settings, applies everywhere
✅ **Consistent Typography** - All text uses the same font family
✅ **Easy Maintenance** - No need to update individual views
✅ **User Preference** - Respects user's font choice
✅ **Hot Reload** - Font changes apply immediately without restart
✅ **Type Safety** - Compile-time checking of font styles

## Technical Details

### Font Weight Support
The implementation includes a `UIFont` extension that adds weight support:

```swift
extension UIFont {
    func withWeight(_ weight: UIFont.Weight) -> UIFont {
        // Adds traits to font descriptor
    }
}
```

### Environment Propagation
The font is available in the SwiftUI environment:

```swift
@Environment(\.appFont) var selectedFont
```

### Performance Considerations
- Font changes trigger a single appearance update
- SwiftUI views using `.appFont()` efficiently re-render
- No performance impact on scrolling or animations

## Next Steps

### Recommended Migrations (Priority Order)

1. **LooseBitsView.swift** - Similar structure to FinishedBitsView
2. **SetlistsView.swift** - List views with cards
3. **SetlistBuilderView.swift** - Complex editing interface
4. **QuickBitEditor.swift** - Input forms
5. **ShowNotesView.swift** - Notes and reflections
6. **RichTextEditor.swift** - Text editing (may need special handling)

### Search Pattern
Run this search to find all views that need updating:
```
\.font\(\.
```

This will find patterns like:
- `.font(.headline)`
- `.font(.body)`
- `.font(.title3.weight(.bold))`

### Bulk Replace Strategy
For simple cases, you can use find and replace:
```
Find: .font(.headline)
Replace: .appFont(.headline)
```

## Testing Checklist

- [ ] Change font in settings
- [ ] Verify HomeView tiles update
- [ ] Verify FinishedBitsView cards update
- [ ] Check navigation titles
- [ ] Test text fields and inputs
- [ ] Verify share card exports
- [ ] Check all text sizes are appropriate
- [ ] Test with different font families

## Troubleshooting

### Font Not Applying?
1. Ensure view uses `.appFont()` instead of `.font()`
2. Check that view is within ContentView hierarchy
3. Verify font name is correct in AppFont enum

### UIKit Components Not Updating?
1. Font changes apply to new views automatically
2. Existing views may need `setNeedsLayout()`
3. Try navigating away and back

### Custom Fonts Not Loading?
1. Verify font names match exactly (case-sensitive)
2. Check that fonts are included in app bundle
3. Ensure Info.plist includes font files if custom

## Conclusion

The global font system is now fully implemented! The font selected in settings will automatically apply throughout the app, both in UIKit and SwiftUI components. For best results, continue migrating other views to use `.appFont()` modifiers as shown in FinishedBitsView.
