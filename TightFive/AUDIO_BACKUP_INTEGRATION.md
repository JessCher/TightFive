# Quick Integration Guide: Audio Backup

## Overview
This guide shows you how to integrate automatic audio backup into your existing Performance recording flow.

## 1. Add Extension to Performance Model

Find your `Performance.swift` file (or wherever the Performance model is defined) and add this extension at the bottom:

```swift
// MARK: - iCloud Audio Backup

extension Performance {
    /// Automatically backup recording to iCloud Drive if sync is enabled
    func autoBackupIfNeeded() {
        guard let filename = audioFilename else { return }
        
        Task {
            try? await iCloudAudioBackupManager.shared.backupRecording(filename: filename)
        }
    }
}
```

## 2. Hook Up Automatic Backup After Recording

### In Stage Mode (or wherever recordings are created)

Find where you create a new `Performance` object after recording. It probably looks something like:

```swift
// Your existing code
let performance = Performance(
    setlistId: setlist.id,
    setlistTitle: setlist.title,
    datePerformed: Date(),
    city: city,
    venue: venue,
    audioFilename: filename,
    duration: duration,
    fileSize: fileSize
)

modelContext.insert(performance)
try? modelContext.save()

// ✨ ADD THIS LINE ✨
performance.autoBackupIfNeeded()
```

That's it! Now recordings will automatically backup when sync is enabled.

## 3. Hook Up Deletion

Find where you delete performances. Add the backup deletion:

```swift
// Before deleting
if let filename = performance.audioFilename {
    Task {
        try? await iCloudAudioBackupManager.shared.deleteRecording(filename: filename)
    }
}

// Then delete as usual
modelContext.delete(performance)
try? modelContext.save()
```

## 4. Test It

1. Open Settings → iCloud Backup & Sync
2. Enable "Backup Audio Recordings"
3. Create a new recording in Stage Mode
4. Recording should automatically backup
5. Check "Last Backup" time in settings
6. Verify file appears in Files app → iCloud Drive → TightFive → Documents → Recordings

## That's It!

The rest is already done:
- ✅ Settings UI is ready
- ✅ Manager class is implemented
- ✅ Progress tracking works
- ✅ Manual backup button works
- ✅ Storage stats work

Just add those two integration points and you're done!

## Common Issues

### "iCloud Drive not available"
- User needs to sign in to iCloud
- Settings app shows prompt to enable iCloud Drive

### Files not appearing
- Check that `syncAudioRecordings` is true
- Verify iCloud entitlement is enabled in Xcode
- Look in Files app: iCloud Drive → TightFive

### Backup not triggering
- Make sure you called `autoBackupIfNeeded()` after save
- Check for errors in Console.app
- Verify file exists locally first

## Advanced: Custom Backup Triggers

You can also manually trigger backup for specific scenarios:

```swift
// Backup a specific file
Task {
    try await iCloudAudioBackupManager.shared.backupRecording(filename: "myfile.m4a")
}

// Backup all recordings
Task {
    await iCloudAudioBackupManager.shared.backupAllRecordings()
}

// Check if iCloud is available
if iCloudAudioBackupManager.shared.isICloudAvailable() {
    // iCloud is ready
}

// Get storage usage
let usage = iCloudAudioBackupManager.shared.getStorageUsage()
print("Local: \(usage.local) bytes")
print("iCloud: \(usage.iCloud) bytes")
```

## Files You Need

All the code is already created in these files:

1. **iCloudAudioBackupManager.swift** - Manager class
2. **iCloudBackupSettingsView.swift** - Settings UI
3. **SettingsView.swift** - Updated with iCloud section
4. **iCloudSyncStatusView.swift** - Status indicators

Just add the two integration points above and you're ready to go! 🎉
