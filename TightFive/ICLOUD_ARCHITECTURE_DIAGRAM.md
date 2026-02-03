# iCloud Architecture Diagram

## System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         TightFive App                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌────────────────┐          ┌──────────────────────┐          │
│  │  SwiftData     │ ◄─────── │  CloudKit Container  │          │
│  │  Models        │          │  (automatic sync)    │          │
│  ├────────────────┤          └──────────────────────┘          │
│  │ • Bit          │                   ▲                         │
│  │ • Setlist      │                   │                         │
│  │ • Performance  │          Syncs via .automatic               │
│  │ • Variation    │                   │                         │
│  │ • Assignment   │                   │                         │
│  │ • UserProfile  │                   ▼                         │
│  └────────────────┘          ┌──────────────────────┐          │
│                               │  iCloud (Apple)      │          │
│  ┌────────────────────────┐  │  - Database Storage  │          │
│  │ Audio Recordings       │  │  - Auto Sync         │          │
│  ├────────────────────────┤  │  - Conflict Res.     │          │
│  │ Local: Documents/      │  └──────────────────────┘          │
│  │   Recordings/          │                                     │
│  │                        │                                     │
│  │ iCloud: iCloud Drive/  │  ┌──────────────────────┐          │
│  │   TightFive/Documents/ │  │  iCloud Drive        │          │
│  │   Recordings/          │◄─┤  (user-controlled)   │          │
│  │                        │  └──────────────────────┘          │
│  └────────────────────────┘                                     │
│            ▲                                                     │
│            │ Managed by                                         │
│            │                                                     │
│  ┌────────┴────────────────────┐                               │
│  │ iCloudAudioBackupManager    │                               │
│  ├─────────────────────────────┤                               │
│  │ • syncAudioRecordings       │                               │
│  │ • backupAllRecordings()     │                               │
│  │ • lastBackupDate            │                               │
│  │ • backupProgress            │                               │
│  │ • getStorageUsage()         │                               │
│  └─────────────────────────────┘                               │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

## Data Flow Diagrams

### 1. Automatic SwiftData Sync

```
┌──────────────┐
│ User creates │
│ new Bit      │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ modelContext │
│ .insert()    │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ modelContext │
│ .save()      │
└──────┬───────┘
       │
       │ Automatic (SwiftData + CloudKit)
       ▼
┌─────────────────────────┐
│ CloudKit Container      │
│ iCloud.com.tightfive... │
└──────┬──────────────────┘
       │
       │ Syncs to other devices
       ▼
┌─────────────────────────┐
│ Other User Devices      │
│ (iPhone, iPad, Mac)     │
└─────────────────────────┘
```

### 2. User-Controlled Audio Backup

```
┌──────────────────────┐
│ Recording completes  │
│ in Stage Mode        │
└──────┬───────────────┘
       │
       ▼
┌──────────────────────┐
│ Performance created  │
│ with audioFilename   │
└──────┬───────────────┘
       │
       ▼
┌──────────────────────┐
│ .autoBackupIfNeeded()│
└──────┬───────────────┘
       │
       ▼
┌─────────────────────────────┐
│ Check: syncAudioRecordings? │
├─────────────────────────────┤
│ NO → Stop (local only)      │
│ YES → Continue              │
└──────┬──────────────────────┘
       │
       ▼
┌─────────────────────────────┐
│ iCloudAudioBackupManager    │
│ .backupRecording(filename)  │
└──────┬──────────────────────┘
       │
       ▼
┌─────────────────────────────┐
│ Copy file to iCloud Drive   │
│ Local → iCloud              │
└──────┬──────────────────────┘
       │
       ▼
┌─────────────────────────────┐
│ File available on all       │
│ devices via iCloud Drive    │
└─────────────────────────────┘
```

### 3. Manual Backup Flow

```
┌──────────────────────┐
│ User taps            │
│ "Backup Now" button  │
└──────┬───────────────┘
       │
       ▼
┌──────────────────────┐
│ Confirmation dialog  │
└──────┬───────────────┘
       │
       ▼
┌────────────────────────────┐
│ iCloudAudioBackupManager   │
│ .backupAllRecordings()     │
└──────┬─────────────────────┘
       │
       ▼
┌────────────────────────────┐
│ Scan local Recordings/     │
│ directory                   │
└──────┬─────────────────────┘
       │
       ▼
┌────────────────────────────┐
│ For each file:             │
│ 1. Check if in iCloud      │
│ 2. Copy if not             │
│ 3. Update progress         │
└──────┬─────────────────────┘
       │
       ▼
┌────────────────────────────┐
│ Update UI:                 │
│ • Progress bar             │
│ • "3 of 10"                │
│ • Last backup time         │
└────────────────────────────┘
```

## Settings View Hierarchy

```
Settings
├── iCloud Backup & Sync ──────────► iCloudBackupSettingsView
│   │                                  │
│   └─ CompactiCloudSyncIndicator    ├─ iCloudSyncStatusView (full)
│                                     │   └─ Shows sync status
│                                     │
│                                     ├─ Toggle: Backup Audio
│                                     │   └─ @AppStorage("syncAudioRecordings")
│                                     │
│                                     ├─ Storage Usage
│                                     │   └─ getStorageUsage()
│                                     │
│                                     ├─ Last Backup Time
│                                     │   └─ @AppStorage("lastAudioBackupDate")
│                                     │
│                                     ├─ Progress Indicator
│                                     │   └─ backupProgress, backupStatus
│                                     │
│                                     └─ "Backup Now" Button
│                                         └─ backupAllRecordings()
│
├── Theme and Customization
├── Stage Mode Settings
└── Run Mode Settings
```

## Component Relationships

```
┌──────────────────────────────────────────────────────────────┐
│                      App Level                                │
├──────────────────────────────────────────────────────────────┤
│                                                                │
│  TightFiveApp.swift                                           │
│  └─ sharedModelContainer                                      │
│      └─ ModelConfiguration(cloudKitDatabase: .automatic)      │
│                                                                │
└────────────────┬───────────────────────────────────────────────┘
                 │
                 │ Provides ModelContext
                 │
    ┌────────────┴─────────────┬──────────────────────────┐
    │                          │                          │
    ▼                          ▼                          ▼
┌─────────┐            ┌──────────────┐         ┌─────────────┐
│ Bits    │            │ Setlists     │         │ Performances│
│ View    │            │ View         │         │ View        │
└────┬────┘            └──────┬───────┘         └──────┬──────┘
     │                        │                         │
     │ Creates/edits          │ Creates/edits           │ Creates
     ▼                        ▼                         ▼
┌─────────┐            ┌──────────────┐         ┌─────────────┐
│ Bit     │            │ Setlist      │         │ Performance │
│ Model   │            │ Model        │         │ Model       │
└────┬────┘            └──────┬───────┘         └──────┬──────┘
     │                        │                         │
     │ Auto-syncs             │ Auto-syncs              │ Calls
     ▼                        ▼                         ▼
┌─────────────────────────────────────────────────────────────┐
│                    CloudKit Container                        │
│              (Automatic SwiftData Sync)                      │
└─────────────────────────────────────────────────────────────┘

                            Performance only:
                                    │
                                    │ .autoBackupIfNeeded()
                                    ▼
                    ┌───────────────────────────────┐
                    │ iCloudAudioBackupManager      │
                    │ (User-controlled sync)        │
                    └───────────┬───────────────────┘
                                │
                                ▼
                    ┌───────────────────────────────┐
                    │      iCloud Drive             │
                    │  (File-based storage)         │
                    └───────────────────────────────┘
```

## Storage Comparison

### SwiftData Models (Automatic)

```
Storage: CloudKit Database
Size Limit: 1 GB per user (free tier)
Sync: Automatic, real-time
Control: None (always syncs)
Models:
  • Bit
  • Setlist
  • BitVariation
  • SetlistAssignment
  • Performance (metadata only)
  • UserProfile

Perfect for: Structured data
```

### Audio Files (User-Controlled)

```
Storage: iCloud Drive
Size Limit: User's iCloud storage quota
Sync: User-controlled toggle
Control: Full (on/off, manual trigger)
Files:
  • recording_[timestamp].m4a
  • Large binary files (10-100 MB each)

Perfect for: Large media files
```

## Key Architectural Decisions

### 1. Why Two Sync Systems?

**SwiftData + CloudKit** for structured data:
- ✅ Automatic sync
- ✅ Conflict resolution
- ✅ Efficient for small data
- ✅ Query-able
- ❌ Size limits

**iCloud Drive** for audio:
- ✅ Large files supported
- ✅ User controls storage usage
- ✅ Simple file copying
- ✅ Works with native Files app
- ❌ Manual implementation

### 2. Why User Control for Audio?

Users may want to:
- Save iCloud storage space
- Keep recordings private/local
- Sync only important shows
- Manage bandwidth on cellular

### 3. Why Separate Last Sync Tracking?

- CloudKit sync is invisible (no access to status)
- Audio sync is explicit (we control it)
- Users want visibility for large files
- Progress matters for multi-file backups

## Benefits Summary

### Automatic Sync Benefits
- Zero user configuration
- Real-time updates
- Offline support
- Conflict resolution
- Cross-platform

### User-Controlled Benefits
- Storage management
- Privacy control
- Bandwidth awareness
- Explicit feedback
- Manual override

### Combined Benefits
- Best of both worlds
- Appropriate for data type
- User empowerment
- iOS best practices
- App Store friendly

---

**Legend:**
- `┌─┐` = Component boundaries
- `│` = Data flow
- `▼` = Direction of flow
- `◄─` = Bidirectional sync
- `└─` = Hierarchy/relationship
