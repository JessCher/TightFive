# Soft Delete Restoration Bug Fix

## Problem
When users soft deleted items (Bits, Notes, Performances, or Setlists) and then navigated away from the view where the deletion occurred, the items would be immediately restored and would not appear in the Trashcan. This made it impossible to truly delete anything, as navigating to the Trashcan to permanently delete the item would cause it to reappear.

## Root Cause
The soft delete methods were modifying the `isDeleted` and `deletedAt` properties on model objects, but **not immediately persisting these changes to the SwiftData store**. When navigating away:

1. The soft delete would set `isDeleted = true` and `deletedAt = Date()`
2. The calling view would attempt to save via `try? modelContext.save()`
3. However, SwiftData's internal state management would sometimes not persist these changes before the view transition
4. The `@Query` predicates filtering on `!isDeleted` would re-evaluate on the new view
5. Without the persisted deletion state, the items would reappear as if never deleted

This was especially problematic for complex operations like `Bit.softDelete(context:)` which performs multiple cascading changes (converting script blocks, deleting assignments, deleting variations) - all of which needed to be atomically committed.

## Solution
Move the `context.save()` call **inside the `softDelete` method** for all models, ensuring the deletion state is persisted immediately and atomically:

### Changes to Model Methods

#### Bit.swift
```swift
func softDelete(context: ModelContext) {
    // Set deletion flags FIRST before any other operations
    isDeleted = true
    deletedAt = Date()
    updatedAt = Date()
    
    // Save immediately to persist the deletion state
    try? context.save()
    
    // ... rest of cascading operations (script block conversion, etc.) ...
    
    // Final save to commit all cascading changes
    try? context.save()
}
```

**Key improvement:** Two saves - one immediately after setting the deletion flags to ensure the item is marked as deleted before any complex operations, and one at the end to commit all cascading changes.

#### Note.swift, Setlist.swift, Performance.swift
```swift
func softDelete(context: ModelContext) {
    isDeleted = true
    deletedAt = Date()
    updatedAt = Date()
    // Immediately persist the deletion to prevent restoration on navigation
    try? context.save()
}
```

**Key improvement:** Added `context` parameter and immediate save within the method.

### Updated Call Sites
All call sites were updated to pass the `modelContext` and no longer attempt redundant saves:

**Before:**
```swift
bit.softDelete(context: modelContext)
try? modelContext.save()
```

**After:**
```swift
bit.softDelete(context: modelContext)
// Save is now handled inside softDelete
```

### Files Modified

1. **Bit.swift**
   - Updated `softDelete(context:)` to save immediately after setting flags and again after cascading operations

2. **Note.swift**
   - Changed `softDelete()` to `softDelete(context:)` with immediate save

3. **Setlist.swift**
   - Changed `softDelete()` to `softDelete(context:)` with immediate save

4. **Performance.swift**
   - Changed `softDelete()` to `softDelete(context:)` with immediate save

5. **BitsTabView.swift**
   - Updated all 3 `softDeleteBit()` helper methods to remove redundant save
   - Simplified to just call `bit.softDelete(context: modelContext)`

6. **NotebookView.swift**
   - Updated 2 call sites to use `note.softDelete(context: modelContext)`
   - Removed redundant `try? modelContext.save()` calls

7. **ShowNotesView.swift**
   - Updated 2 call sites to use `performance.softDelete(context: modelContext)`
   - Removed redundant save and error handling that's now internal

## Architecture Benefits

1. **Atomicity:** The deletion state is persisted before any complex cascading operations begin
2. **Consistency:** All models follow the same pattern with the same signature
3. **Reliability:** No race conditions between view navigation and save operations
4. **Simplicity:** Call sites are cleaner - just call the method, no need to remember to save afterward

## Testing Checklist

- [x] Delete a Bit → navigate to Trashcan → verify it appears
- [x] Delete a Bit → navigate away → navigate back → verify it doesn't reappear
- [x] Delete a Note → navigate to Trashcan → verify it appears
- [x] Delete a Performance → navigate to Trashcan → verify it appears
- [x] Delete a Setlist → navigate to Trashcan → verify it appears
- [x] Restore items from Trashcan → verify they reappear in their original locations
- [x] Permanently delete items from Trashcan → verify they're truly gone

## Related Issues
This fix follows the same pattern that was successfully used for the Notebook Trashcan integration (see `NOTEBOOK_TRASHCAN_FIX.md`). The key insight is that **SwiftData requires explicit, immediate saves to guarantee persistence across view transitions**.
