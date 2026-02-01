# Fix Instructions for StageModeView.swift

## Issues Fixed ✅

1. **Changed `@ObservedObject` to `@State` for `CueCardSettingsStore`**
   - `CueCardSettingsStore` uses the modern `@Observable` macro
   - `@ObservedObject` is for the old `ObservableObject` protocol
   - Solution: Changed to `@State private var settings = CueCardSettingsStore.shared`

2. **Removed unnecessary `Combine` import**
   - Not used in this file
   - Cleaned up imports

## Critical Issue Remaining ❌

### Duplicate CueCard Files

**Problem:** There are TWO `CueCard` Swift files in the project:
- `CueCard.swift` (167 lines) - **CORRECT VERSION**
- `CueCard 2.swift` (137 lines) - **DUPLICATE/OLD VERSION**

This causes the compiler error:
```
error: 'CueCard' is ambiguous for type lookup in this context
```

**Solution:** Delete or rename `CueCard 2.swift`

### Which CueCard file to keep?

**Keep:** `CueCard.swift` (the first one)

**Reasons:**
1. Has `blockId` and `blockIndex` properties needed by the engine
2. Has more sophisticated `normalizedWords`, `normalizedAnchor`, `normalizedExit` properties
3. Has better fuzzy matching algorithm with sliding window approach
4. The `extractCards(from:)` method matches what `CueCardEngine` expects
5. Has proper phrase extraction logic

**Delete:** `CueCard 2.swift`

**How to fix:**
1. In Xcode, locate `CueCard 2.swift` in the Project Navigator
2. Right-click and select "Delete"
3. Choose "Move to Trash"
4. Clean build folder (Product > Clean Build Folder)
5. Rebuild project

## Verification Steps

After deleting the duplicate file, verify:

1. No compiler errors about ambiguous types
2. `CueCard.extractCards(from: setlist)` resolves correctly
3. All properties like `card.fullText`, `card.anchorPhrase`, `card.exitPhrase` are available
4. The project builds successfully

## Summary of Changes Made to StageModeView.swift

```swift
// Before:
@ObservedObject private var settings = CueCardSettingsStore.shared

// After:
@State private var settings = CueCardSettingsStore.shared
```

This change is compatible with the `@Observable` macro used in `CueCardSettingsStore`.
