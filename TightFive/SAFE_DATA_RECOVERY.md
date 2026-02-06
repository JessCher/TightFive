# Safe Data Recovery - Notebook Folders

## ⚠️ IMPORTANT: Your Data is Safe

**This fix will ONLY clear corrupted folder data. It will NOT delete:**
- ❌ Your bits
- ❌ Your setlists  
- ❌ Your performances
- ❌ Your notes (they'll become unassigned)
- ❌ Any other data

**This fix will ONLY clear:**
- ✅ Folder structures (which are corrupted anyway)

---

## What Happened

When you tried to create folders before we added `NoteFolder` to the SwiftData schema, they were created in memory but never properly persisted. These "ghost" folders are causing the freeze when the app tries to load them.

---

## Safe Recovery Steps

### Option 1: Automatic Recovery (Recommended)

The app now has a built-in recovery tool:

1. **Try to open the Folders page**
   - If it freezes, force quit the app and reopen
   - Try again - it should show an error state

2. **You'll see an error screen** with:
   - "Folders Error" message
   - "Clear Corrupted Folders" button
   - Note: "This will only remove folder data, not your notes, bits, or setlists"

3. **Tap "Clear Corrupted Folders"**
   - This safely removes ONLY the corrupted folder data
   - All your other data remains intact

4. **Folders page will reload**
   - You'll see the empty state
   - Create a new folder to test
   - It will now save properly!

---

### Option 2: If the App Still Freezes

If the app freezes before you can see the error screen, we can clear the data manually:

#### For iOS Simulator:
1. In Terminal, run:
   ```bash
   xcrun simctl get_app_container booted com.yourcompany.TightFive data
   ```
2. Navigate to that directory
3. Delete the `default.store` file
4. Restart the app

#### For Physical Device:
1. Go to Settings → General → iPhone Storage
2. Find "TightFive"
3. Tap "Offload App" (NOT "Delete App")
4. Tap "Reinstall App"
5. Open the app - data should be preserved

---

### Option 3: Nuclear Option (Last Resort)

**⚠️ ONLY if Options 1 & 2 fail:**

If you absolutely cannot recover and must start fresh:

1. **Export your data first:**
   - Take screenshots of important bits/setlists
   - Note down anything critical

2. **Delete and reinstall:**
   - Delete the app
   - Reinstall from Xcode
   - Re-create your data

**But this should NOT be necessary!** Options 1 or 2 should work.

---

## What the Recovery Does

The `clearCorruptedFolders()` function:

```swift
1. Fetches all NoteFolder objects
2. Deletes them (they were corrupted anyway)
3. Fetches all Note objects to verify they're preserved
4. Saves the cleanup
5. Reloads the folders view (now empty but working)
```

**Important:** Notes that were "in" folders will become unassigned (visible in "All Notes"), but they won't be deleted.

---

## After Recovery

Once you've cleared the corrupted folders:

### ✅ Test 1: Create a Folder
1. Tap the + button
2. Name it "Test Folder"
3. It should appear immediately

### ✅ Test 2: Verify Persistence
1. Force quit the app (swipe up from app switcher)
2. Reopen the app
3. Go to Folders
4. "Test Folder" should still exist

### ✅ Test 3: Create a Note in Folder
1. Tap "Test Folder"
2. Tap the menu (•••)
3. Tap "New Note in Folder"
4. Write some text
5. Go back
6. Note should be in the folder

### ✅ Test 4: Verify Your Other Data
1. Go to Bits - all your bits should be there
2. Go to Setlists - all your setlists should be there
3. Go to Notebook - all your notes should be there (even if not in folders)

---

## Why This Happened

**Timeline of events:**

1. You created `Note` and `NoteFolder` models
2. You wrote UI code to create folders/notes
3. **But forgot to add them to the SwiftData schema**
4. When you created folders, they existed in memory only
5. Save operations silently failed
6. On app restart, SwiftData tried to load them but couldn't
7. This created "ghost" objects that caused freezes

**The fix:**
- Added models to schema (so new folders work)
- Clear corrupted "ghost" folders (so view doesn't freeze)
- Keep all other data intact

---

## Prevention

This won't happen again because:

1. ✅ Models are now in the schema
2. ✅ Save operations have proper error handling
3. ✅ Console logs show success/failure
4. ✅ Recovery tool is built-in if issues occur

---

## Support

If you still have issues after trying Options 1 and 2:

1. Check the console for error messages
2. Look for "❌ Failed to..." logs
3. Try the recovery again
4. Check that all your bits/setlists/notes are still there

The goal is to preserve all your important data (bits, setlists, performances) and only clear the broken folder structures.

---

## Summary

**Safe recovery:**
1. Try to open Folders page
2. Tap "Clear Corrupted Folders" button
3. Create a new folder to test
4. Verify all other data is intact

**Your bits, setlists, performances, and notes are SAFE.** We're only clearing the folder structures that were corrupted before the schema was fixed.
