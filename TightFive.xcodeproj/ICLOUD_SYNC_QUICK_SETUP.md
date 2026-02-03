# iCloud Sync - Quick Setup Checklist

## ✅ Quick Steps to Enable iCloud Sync

### 1. Enable iCloud Capability (5 minutes)

**Main App Target (TightFive):**
1. ☐ Select project in navigator
2. ☐ Select **TightFive** target
3. ☐ Go to **Signing & Capabilities** tab
4. ☐ Click **+ Capability** button
5. ☐ Add **iCloud**
6. ☐ Check **CloudKit**
7. ☐ Click **+** under CloudKit Containers
8. ☐ Create: `iCloud.com.tightfive.app`
9. ☐ Ensure it's checked

**Widget Extension (QuickBitWidget):**
1. ☐ Select **QuickBitWidget** target
2. ☐ Go to **Signing & Capabilities** tab
3. ☐ Click **+ Capability** button
4. ☐ Add **iCloud**
5. ☐ Check **CloudKit**
6. ☐ Select existing: `iCloud.com.tightfive.app`
7. ☐ Ensure it's checked

### 2. Code is Already Updated ✨

The following files have been modified with iCloud support:

- ☑️ **TightFiveApp.swift** - ModelContainer now uses `cloudKitDatabase: .automatic`
- ☑️ **iCloudSyncStatusView.swift** - New component to show sync status (created)
- ☑️ **ICLOUD_SYNC_IMPLEMENTATION.md** - Full documentation (created)

### 3. Add Sync Status to Settings (Optional - 2 minutes)

Open **SettingsView.swift** and add this section:

```swift
// Add after existing sections
Section {
    iCloudSyncStatusView()
} header: {
    Text("BACKUP & SYNC")
        .appFont(.caption, weight: .semibold)
        .foregroundStyle(TFTheme.text.opacity(0.5))
}
```

### 4. Test on Device (10 minutes)

**Prerequisites:**
- ☐ Sign in to iCloud on test device
- ☐ Enable iCloud Drive in Settings → [Your Name] → iCloud

**Test Steps:**
1. ☐ Build and run app
2. ☐ Create test data (bits, setlists)
3. ☐ Open CloudKit Dashboard: https://icloud.developer.apple.com/dashboard
4. ☐ Select your container: `iCloud.com.tightfive.app`
5. ☐ Switch to **Development** environment
6. ☐ Verify data appears in Record Types
7. ☐ Install on second device (same iCloud account)
8. ☐ Wait ~30 seconds
9. ☐ Verify data syncs automatically

### 5. Handle Audio Files (Optional - 15 minutes)

Audio recordings in Show Notes are large files. Choose one option:

**Option A: Store in iCloud Drive (Recommended)**
- Automatically synced with iCloud Drive
- No size limits for CloudKit database
- See full implementation in `ICLOUD_SYNC_IMPLEMENTATION.md`

**Option B: Keep Local with Toggle**
- Faster performance
- User chooses whether to sync
- See full implementation in `ICLOUD_SYNC_IMPLEMENTATION.md`

For now, audio files will remain local-only until you implement one of these options.

## What Works Immediately ✅

After enabling iCloud capability, these sync automatically:
- ✅ All bits (loose and finished)
- ✅ All setlists (draft and finalized)
- ✅ Bit variations
- ✅ Setlist assignments
- ✅ Performance metadata (Show Notes)
- ✅ User profile
- ✅ Tags, ratings, notes

**Audio recordings** require additional setup (see step 5).

## Important Notes

### First Launch
- When a user first launches with iCloud enabled, sync happens automatically
- No migration code needed - SwiftData handles it
- First sync may take a few seconds depending on data size

### Network Requirements
- Syncing requires internet connection
- Works on WiFi and cellular
- Changes are queued when offline and sync when online

### Privacy
- Data is tied to user's Apple ID
- Encrypted in transit and at rest
- Cannot be accessed by other users
- User controls data via iCloud settings

### CloudKit Dashboard
During development, use the CloudKit Dashboard to:
- Verify data is syncing
- View record structure
- Debug sync issues
- Test with sample data

**URL:** https://icloud.developer.apple.com/dashboard

## Troubleshooting

### "CloudKit not available"
- Verify user is signed in to iCloud
- Check iCloud Drive is enabled
- Ensure capabilities are configured

### Data not syncing
- Check internet connection
- Sign out and back in to iCloud
- Check Console.app for CloudKit errors
- Verify container ID matches in capabilities

### Testing sync between devices
- Use same Apple ID on both devices
- Wait 30-60 seconds after changes
- Pull to refresh if app supports it
- Check CloudKit Dashboard to verify data

## Production Checklist

Before submitting to App Store:

- ☐ Test with real iCloud account (not Sandbox)
- ☐ Test sync across multiple devices
- ☐ Test with poor network connection
- ☐ Test sign out/sign in scenarios
- ☐ Switch CloudKit Dashboard to **Production** environment
- ☐ Add privacy policy mentioning iCloud usage
- ☐ Update App Store description mentioning iCloud sync
- ☐ Test App Review account has iCloud enabled

## Resources

- **Full Guide:** `ICLOUD_SYNC_IMPLEMENTATION.md`
- **CloudKit Dashboard:** https://icloud.developer.apple.com/dashboard
- **Apple Documentation:** https://developer.apple.com/icloud/cloudkit/
- **SwiftData + CloudKit:** https://developer.apple.com/documentation/swiftdata

## Summary

The code is **already updated** with iCloud sync! 

The only remaining step is enabling the **iCloud capability** in Xcode (Step 1).

That's it! One capability setting = Full iCloud backup & sync. 🎉
