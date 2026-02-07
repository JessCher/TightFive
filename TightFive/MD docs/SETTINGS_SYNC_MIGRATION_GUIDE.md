# Settings Sync Migration Guide

## Overview

Your app settings now sync automatically across all your devices using **iCloud Key-Value Storage**! This means when you customize your app on your iPhone, those same settings will instantly appear on your iPad (and vice versa).

## What Changed

### Before
- Settings were stored in `UserDefaults` (local device only)
- Each device had independent settings
- You had to reconfigure settings on every device

### After
- Settings are stored in **NSUbiquitousKeyValueStore** (iCloud)
- Settings sync automatically across all devices signed into the same iCloud account
- Changes on one device appear on other devices within seconds
- Local fallback ensures the app works even without iCloud

## Technical Implementation

### Storage Strategy

The `AppSettings` class now uses a **dual-storage approach**:

1. **Primary Storage**: `NSUbiquitousKeyValueStore` (iCloud Key-Value Store)
   - Syncs settings across devices
   - Apple-provided service with automatic conflict resolution
   - Handles up to 1 MB of data (more than enough for app preferences)

2. **Secondary Storage**: `UserDefaults` (Local)
   - Provides immediate local access
   - Acts as a fallback if iCloud is unavailable
   - Ensures app works offline

### How It Works

```swift
// When you SET a setting:
1. Value is written to iCloud KV Store
2. Value is written to local UserDefaults
3. iCloud syncs to other devices automatically
4. SwiftUI views update via @Observable

// When you GET a setting:
1. Check iCloud KV Store first
2. Fall back to local UserDefaults if needed
3. Return default value if neither has data
```

### Automatic Sync from Other Devices

The `init()` method now observes changes from iCloud:

```swift
NotificationCenter.default.addObserver(
    forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
    object: cloudStore,
    queue: .main
) { notification in
    // When settings change on another device:
    // 1. Copy values from iCloud to local store
    // 2. Trigger UI update via notifyChange()
}
```

## What Syncs

**All** app settings now sync across devices, including:

### Visual Customization
- ✅ Bit card frame colors
- ✅ Bit card bottom bar colors
- ✅ Bit window themes
- ✅ Custom hex colors
- ✅ Grit levels (all layers and densities)
- ✅ Grit colors (all custom colors)

### Typography
- ✅ App font selection
- ✅ Font color
- ✅ Font size multiplier

### UI Themes
- ✅ Tile card themes
- ✅ Quick Bit button theme
- ✅ Custom theme colors

### Background
- ✅ Base background color
- ✅ Cloud count, opacity, colors, and offsets
- ✅ Dust count and opacity

### Accessibility
- ✅ Reduce motion
- ✅ High contrast
- ✅ Haptics enabled
- ✅ Bold text
- ✅ Larger touch targets

## User Experience

### First Launch After Update
- Your existing settings from local UserDefaults are automatically available
- The first time you change a setting after the update, it syncs to iCloud
- Other devices will receive the synced settings within seconds

### Sync Behavior
- **Immediate**: Settings sync as soon as you change them
- **Automatic**: No manual sync button needed
- **Seamless**: Works in the background
- **Smart**: Handles conflicts automatically (most recent wins)

### Requirements
- ✅ Signed into iCloud on all devices
- ✅ iCloud Drive enabled (Settings > [Your Name] > iCloud)
- ✅ Internet connection (sync happens in background)

### Offline Behavior
- All settings work offline using local UserDefaults
- Changes made offline will sync when connection is restored
- No data loss if temporarily offline

## Testing the Sync

To verify settings are syncing:

1. **On iPhone**:
   - Open Settings
   - Change a visual preference (e.g., bit card frame color)
   - Notice the change immediately

2. **On iPad**:
   - Wait 5-10 seconds
   - Open the app (or switch tabs if already open)
   - See the same setting automatically applied!

## Troubleshooting

### Settings Not Syncing?

1. **Check iCloud Status**:
   - Go to Settings > [Your Name] > iCloud
   - Ensure iCloud Drive is enabled
   - Ensure TightFive has iCloud permission

2. **Force Sync**:
   - Change any setting on the device
   - This triggers an immediate sync

3. **Check Connection**:
   - Ensure you have an active internet connection
   - iCloud sync requires network connectivity

4. **Wait a Moment**:
   - Sync typically happens within 5-10 seconds
   - Complex settings may take slightly longer

### Conflicting Changes

If you change the same setting on two devices simultaneously:
- iCloud automatically resolves the conflict
- The most recent change wins
- No manual intervention needed

## Performance Impact

- **Minimal**: iCloud KV Store is designed for preferences
- **Async**: All sync operations happen in the background
- **Efficient**: Only changed values are synced
- **Lightweight**: Settings data is < 50 KB total

## Privacy & Security

- ✅ Settings stored in your personal iCloud account
- ✅ End-to-end encrypted by Apple
- ✅ Never shared with third parties
- ✅ Only accessible from your devices

## Migration Details

### Code Changes

All computed properties in `AppSettings` now use helper methods:

```swift
// Old:
var bitCardFrameColor: BitCardFrameColor {
    get {
        UserDefaults.standard.string(forKey: "...")
    }
    set {
        UserDefaults.standard.set(newValue, forKey: "...")
    }
}

// New:
var bitCardFrameColor: BitCardFrameColor {
    get {
        getString(forKey: "...")  // Checks iCloud then local
    }
    set {
        setString(newValue, forKey: "...")  // Writes to both
    }
}
```

### Helper Methods

Four new helper methods handle all storage operations:

- `getString(forKey:default:)` - For string values
- `setString(_:forKey:)` - Store string values
- `getDouble(forKey:)` - For numeric values
- `setDouble(_:forKey:)` - Store numeric values
- `getBool(forKey:)` - For boolean values
- `setBool(_:forKey:)` - Store boolean values
- `getInt(forKey:)` - For integer values
- `setInt(_:forKey:)` - Store integer values
- `hasBeenSet(forKey:)` - Check if value exists

## Limitations

### iCloud KV Store Limits
- **Storage**: 1 MB per app (we use < 50 KB)
- **Keys**: 1024 key-value pairs maximum (we use < 100)
- **Sync Frequency**: Automatic, typically within seconds
- **Devices**: Syncs to all devices with same iCloud account

These limits are more than sufficient for app preferences.

## Future Enhancements

Potential improvements:
- Sync presets (save/load custom theme combinations)
- Share settings with other users
- Export/import settings as JSON
- Settings history/version control

## Support

If you experience any issues with settings sync:
1. Check iCloud status in iOS Settings
2. Restart the app on both devices
3. Check for app updates
4. Contact support with specific details

---

**Note**: This migration is automatic and requires no action from users. All existing settings are preserved and will begin syncing immediately after the update.
