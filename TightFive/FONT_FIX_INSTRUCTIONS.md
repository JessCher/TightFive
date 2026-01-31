# How to Fix Global Font Not Persisting

## The Problem

The global font settings you configured in `TightFiveApp.swift` are working for UIKit components, but SwiftUI views that use explicit `.font()` modifiers are not picking up the changes. This is because SwiftUI's `.font()` modifier takes precedence over any global/environment settings.

## Why Home View Works But Others Don't

`HomeView` works because it uses `.appFont()` modifiers throughout (like `.appFont(.headline, weight: .semibold)`), while other views like `LooseBitsView`, `SetlistsView`, etc. still use standard `.font()` modifiers (like `.appFont(.headline, weight: .semibold)`).

## The Solution: Batch Find and Replace

You need to update all views to use `.appFont()` instead of `.font()`. Here's how to do it efficiently in Xcode:

### Step 1: Find All Font Usages

In Xcode:
1. Press `Cmd + Shift + F` (Find in Project)
2. Search for: `.font(`
3. Set scope to your project files (exclude frameworks)

### Step 2: Replace Patterns

You'll need to replace several patterns. Here are the most common ones:

#### Pattern 1: Text Styles with Weight
**Find:** `.appFont(.headline, weight: .semibold)`
**Replace:** `.appFont(.headline, weight: .semibold)`

**Find:** `.appFont(.title3, weight: .semibold)`
**Replace:** `.appFont(.title3, weight: .semibold)`

**Find:** `.appFont(.caption, weight: .semibold)`
**Replace:** `.appFont(.caption, weight: .semibold)`

#### Pattern 2: Text Styles without Weight
**Find:** `.appFont(.headline)`
**Replace:** `.appFont(.headline)`

**Find:** `.appFont(.subheadline)`
**Replace:** `.appFont(.subheadline)`

**Find:** `.appFont(.caption)`
**Replace:** `.appFont(.caption)`

**Find:** `.appFont(.caption2, weight: .medium)`
**Replace:** `.appFont(.caption2, weight: .medium)`

#### Pattern 3: System Fonts with Specific Sizes
**Find:** `.font(.system(size: 18, weight: .bold))`
**Replace:** `.appFont(size: 18, weight: .bold)`

**Find:** `.font(.system(size: 14))`
**Replace:** `.appFont(size: 14)`

**Find:** `.appFont(.title2, weight: .bold)`
**Replace:** `.appFont(.title2, weight: .bold)`

### Step 3: Files That Need Updating (Priority Order)

Based on your tab structure, update these files in order:

1. **LooseBitsView.swift** - 21 occurrences of `.font(`
2. **SetlistsView.swift** - Check for `.font(` usage
3. **SetlistBuilderView.swift** - Check for `.font(` usage  
4. **QuickBitEditor.swift** - Check for `.font(` usage
5. **ShowNotesView.swift** - Check for `.font(` usage
6. **RunModeView.swift** or **RunModeLauncherView.swift** - Check for `.font(` usage

### Step 4: Quick Regex Replace (Advanced)

If you're comfortable with regex, you can use these patterns:

#### For text styles:
**Find (Regex):** `\.font\(\.(title3|headline|body|caption|caption2|subheadline|footnote|largeTitle|title|title2|callout)\.weight\(\.(\w+)\)\)`
**Replace:** `.appFont(.$1, weight: .$2)`

#### For simple text styles:
**Find (Regex):** `\.font\(\.(title3|headline|body|caption|caption2|subheadline|footnote|largeTitle|title|title2|callout)\)`
**Replace:** `.appFont(.$1)`

### Step 5: Manual Review

Some fonts might need manual review:
- Custom fonts with complex modifiers
- Conditional font logic
- Fonts in special contexts (PDFs, images, etc.)

## Alternative: Automated Script

If you have many files to update, you can create a shell script:

```bash
#!/bin/bash

# Navigate to your project directory
cd /path/to/your/project

# Find all Swift files and perform replacements
find . -name "*.swift" -type f -exec sed -i '' \
  -e 's/\.font(\.headline\.weight(\.semibold))/\.appFont(.headline, weight: .semibold)/g' \
  -e 's/\.font(\.title3\.weight(\.semibold))/\.appFont(.title3, weight: .semibold)/g' \
  -e 's/\.font(\.caption\.weight(\.semibold))/\.appFont(.caption, weight: .semibold)/g' \
  -e 's/\.font(\.caption2\.weight(\.medium))/\.appFont(.caption2, weight: .medium)/g' \
  -e 's/\.font(\.title2\.weight(\.bold))/\.appFont(.title2, weight: .bold)/g' \
  -e 's/\.font(\.system(size: \([0-9]*\), weight: \.\([a-z]*\)))/\.appFont(size: \1, weight: .\2)/g' \
  -e 's/\.font(\.headline)/\.appFont(.headline)/g' \
  -e 's/\.font(\.subheadline)/\.appFont(.subheadline)/g' \
  -e 's/\.font(\.caption)/\.appFont(.caption)/g' \
  -e 's/\.font(\.body)/\.appFont(.body)/g' \
  {} \;

echo "Font replacements complete!"
```

## Quick Win: Update One View at a Time

To see immediate results, update one view at a time:

1. Open `LooseBitsView.swift`
2. Use Xcode's Find and Replace (Cmd+F) within that file
3. Replace all `.font(` with `.appFont(` following the patterns above
4. Test the view
5. Move to the next view

## Testing After Updates

After making changes:
1. Clean build folder (Cmd + Shift + K)
2. Build project (Cmd + B)
3. Run app
4. Go to Settings → Change font
5. Navigate through all tabs to verify font changes

## Expected Results

Once updated, changing the font in settings should:
- ✅ Update HomeView (already works)
- ✅ Update Bits tab
- ✅ Update Setlists tab
- ✅ Update Run Through tab
- ✅ Update Show Notes tab
- ✅ Update all navigation titles
- ✅ Update all cards and lists
- ✅ Persist across app restarts

## Why This Is Necessary

SwiftUI doesn't have a way to truly override explicit `.font()` modifiers from a parent view. The only solution is to use a custom font modifier (like `.appFont()`) throughout your codebase that references `AppSettings.shared.appFont`.

The UIKit appearance settings you configured in `TightFiveApp.swift` handle labels, text fields, and navigation bars automatically, but SwiftUI Text views with explicit fonts need to use the custom modifier.
