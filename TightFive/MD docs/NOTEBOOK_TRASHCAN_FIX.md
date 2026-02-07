# Notebook Trashcan Integration Fix

## Problem
Notebook notes were not appearing in the trashcan when deleted, and they were reappearing after app restart. The warning message mentioned they would be "moved to the trash," but they never actually showed up there.

## Root Cause
The `TrashcanView` was missing support for the `Note` model entirely. It only had queries for:
- `Bit`
- `Setlist`
- `Performance`

This meant deleted notes were soft-deleted (marked as `isDeleted = true`) but had no way to be viewed, restored, or permanently deleted from the trashcan.

## Changes Made

### TrashcanView.swift

1. **Added Note Query**
   - Added `@Query` to fetch all soft-deleted notes
   - Sorted by `deletedAt` in reverse order (newest first)

2. **Updated Empty State Logic**
   - Added `deletedNotes.isEmpty` check to `isEmpty` computed property
   - Added `deletedNotes.count` to `totalItemCount` computation

3. **Added Deleted Notes Section**
   - New section in the trashcan list displaying deleted notebook notes
   - Shows "NOTEBOOK NOTES (count)" header
   - Each note row displays title and deletion timestamp
   - Supports restore and permanent delete actions via swipe gestures

4. **Updated Hard Delete Logic**
   - Added `.note` case to `hardDelete()` function
   - Uses `modelContext.delete()` to permanently remove notes
   - Added note deletion to `emptyTrash()` function

5. **Updated TrashItemType Enum**
   - Added `.note` case
   - Icon: "book.closed"
   - Color: `.orange`

6. **Updated Preview**
   - Added `Note.self` to the model container in the preview

## How It Works Now

### Deleting a Note
1. User swipes left on a note in NotebookView
2. Confirmation alert appears: "This note will be moved to the trash."
3. User confirms deletion
4. Note's `softDelete()` method is called:
   - Sets `isDeleted = true`
   - Sets `deletedAt = Date()`
5. Changes are saved to SwiftData
6. Note immediately disappears from NotebookView (filtered out by the `!note.isDeleted` predicate)

### Viewing Deleted Notes
1. User navigates to TrashcanView
2. Deleted notes appear in "NOTEBOOK NOTES" section
3. Each entry shows:
   - Note title (or "Untitled Note")
   - Deletion timestamp (e.g., "Deleted 5 minutes ago")
   - Orange book icon

### Restoring a Note
1. Swipe right on a deleted note (or use context menu)
2. Tap "Restore" button
3. Note's `restore()` method is called:
   - Sets `isDeleted = false`
   - Sets `deletedAt = nil`
4. Note reappears in NotebookView immediately

### Permanently Deleting a Note
1. Swipe left on a deleted note (or use context menu)
2. Tap "Delete" button
3. Confirmation alert: "Permanently Delete? This will permanently delete '[title]' and cannot be undone."
4. User confirms
5. Note is hard-deleted using `modelContext.delete(note)`
6. Note is completely removed from the database

### Empty Trashcan
1. Tap "Empty" button in toolbar
2. Confirmation shows total count including notes
3. User confirms
4. All deleted items (including notes) are permanently removed

## Testing Checklist

- [x] Delete a note from NotebookView → appears in trashcan
- [x] Deleted notes don't reappear after app restart
- [x] Restore a note from trashcan → appears back in NotebookView
- [x] Permanently delete a note from trashcan → gone forever
- [x] Empty trashcan includes notes in the count
- [x] Swipe gestures work on note rows in trashcan
- [x] Context menu works on note rows in trashcan
- [x] Visual styling matches other trashcan items

## Architecture Notes

The `Note` model already had proper soft-delete support:
- `isDeleted` property (used in query predicates)
- `deletedAt` timestamp (used for sorting in trashcan)
- `softDelete()` method (sets the flags)
- `restore()` method (clears the flags)

The only missing piece was integrating `Note` into the `TrashcanView` UI, which has now been completed. This matches the existing pattern used for `Bit`, `Setlist`, and `Performance` models.
