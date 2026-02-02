# FlippableScriptBlockCard.swift - Compilation Fix

## Problem
The file `FlippableScriptBlockCard.swift` had compilation errors because it was missing the proper imports needed to access types and extensions used throughout your codebase.

## Errors Fixed

### Missing Imports
The file was missing critical imports:
- ❌ Missing `SwiftUI` - needed for all SwiftUI views
- ❌ Missing `UIKit` - needed for UIKit types and RTF helpers
- ❌ Had unnecessary `Combine` import

### Resolution
Updated the imports to:
```swift
import SwiftUI
import SwiftData
import UIKit
```

## Dependencies Used in This File

### Types from Your Codebase
- **`ScriptBlock`** - Enum representing setlist content blocks (from `ScriptBlock.swift`)
- **`SetlistAssignment`** - Model for bit assignments in setlists (from `SetlistAssignment.swift`)
- **`Performance`** - Model for performance data (from `Performance.swift`)
- **`FlippableBitCard`** - Reusable flip card component (from `FlippableBitCard.swift`)

### Extensions Used
1. **`Text.appFont(_:weight:)`** - Custom font system (from `FontExtensions 2.swift`)
2. **`View.appFont(_:weight:)`** - Custom font system (from `FontExtensions 2.swift`)
3. **`View.tfDynamicCard(cornerRadius:)`** - Textured card modifier (from `DynamicTexturedCard.swift`)
4. **`NSAttributedString.fromRTF(_:)`** - RTF conversion helper (from `RTFHelpers.swift`)

### Theme/Styling
- **`TFTheme.text`** - Dynamic text color (from `TFTheme.swift`)
- **`TFTheme.yellow`** - App accent color (from `TFTheme.swift`)

## Why These Imports Matter

### SwiftUI
Required for all view components and SwiftUI-specific features:
- `View` protocol
- `@State`, `@Binding`, `@FocusState` property wrappers
- Layout containers like `VStack`, `HStack`, `ZStack`
- Components like `Text`, `Image`, `Button`, `TextEditor`

### SwiftData
Required for:
- `@Bindable` property wrapper for Performance model
- `ModelContext` environment value
- Model persistence

### UIKit
Required for:
- `NSAttributedString` for RTF parsing
- Foundation types used by RTF helpers
- Interoperability with UIKit-based extensions

## Verification

After this fix, all compilation errors should be resolved:
✅ `TFTheme` is now accessible
✅ `Performance` type is recognized
✅ `SetlistAssignment` type is recognized
✅ `ScriptBlock` type is recognized
✅ `FlippableBitCard` is found
✅ `.appFont()` modifier works on Text and View
✅ `.tfDynamicCard()` modifier is available
✅ `NSAttributedString.fromRTF()` is accessible

## File Structure
The file now properly connects to your codebase:
```
FlippableScriptBlockCard.swift
├── Imports: SwiftUI, SwiftData, UIKit
├── FlippableScriptBlockCard (View)
│   ├── Uses: ScriptBlock, SetlistAssignment
│   ├── Uses: FlippableBitCard for animation
│   ├── Uses: TFTheme for colors
│   ├── Uses: .appFont() for typography
│   └── Uses: .tfDynamicCard() for card styling
└── FlippableScriptBlockList (View)
    ├── Uses: Performance model with @Bindable
    ├── Manages: Flip state for multiple cards
    └── Persists: Changes via ModelContext
```

## Integration
This file integrates seamlessly with `ShowNotesView.swift`:
- Called via `FlippableScriptBlockList` component
- Receives setlist data (blocks + assignments)
- Binds to Performance model for ratings/notes
- Auto-saves changes to SwiftData

## Next Steps
The feature is now ready to use! When you run the app:
1. Open Show Notes
2. Tap a performance
3. Scroll to the Setlist section
4. Tap any script block card to flip and rate/annotate

All compilation errors are resolved and the feature should work as designed.
