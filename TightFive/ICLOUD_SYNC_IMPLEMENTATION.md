# iCloud Sync Implementation Guide for TightFive

## Overview
This guide walks you through implementing iCloud syncing for TightFive using SwiftData's built-in CloudKit integration. This will automatically backup and sync all user data across their devices.

## Benefits of iCloud Sync
- ✅ **Automatic backup** - User data is safely stored in iCloud
- ✅ **Cross-device sync** - Work seamlessly across iPhone, iPad, and Mac
- ✅ **Zero configuration** - SwiftData handles all the complexity
- ✅ **Conflict resolution** - Automatic merging of changes
- ✅ **Privacy preserved** - Data encrypted and tied to user's iCloud account

## Implementation Steps

### Step 1: Enable iCloud Capability in Xcode

#### For Main App Target (TightFive):
1. Select your project in the Project Navigator
2. Select the **TightFive** target
3. Go to **Signing & Capabilities** tab
4. Click **+ Capability**
5. Add **iCloud**
6. Enable **CloudKit**
7. Click the **+** button under CloudKit Containers
8. Create a new container: `iCloud.com.tightfive.app`
9. Make sure it's checked

#### For Widget Extension (QuickBitWidget):
1. Select the **QuickBitWidget** target
2. Go to **Signing & Capabilities** tab
3. Click **+ Capability**
4. Add **iCloud**
5. Enable **CloudKit**
6. Select the existing container: `iCloud.com.tightfive.app`
7. Make sure it's checked

> **Note**: The widget needs access to the same container to read synced data.

### Step 2: Update TightFiveApp.swift

Replace the current `.modelContainer()` setup with an iCloud-enabled configuration:

```swift
import SwiftUI
import SwiftData

@main
struct TightFiveApp: App {
    @State private var appSettings = AppSettings.shared
    @State private var showQuickBit = false
    
    init() {
        TFTheme.applySystemAppearance()
        configureGlobalAppearance()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(TFTheme.yellow)
                .environment(appSettings)
                .globalKeyboardDismiss()
                .syncWithWidget(showQuickBit: $showQuickBit)
                .sheet(isPresented: $showQuickBit) {
                    QuickBitEditor()
                        .presentationDetents([.medium, .large])
                }
                .onAppear {
                    configureGlobalAppearance()
                }
                .onChange(of: appSettings.appFont) { oldValue, newValue in
                    configureGlobalAppearance()
                }
        }
        .modelContainer(sharedModelContainer)
    }
    
    // MARK: - Shared Model Container with iCloud Sync
    
    private var sharedModelContainer: ModelContainer {
        let schema = Schema([
            Bit.self,
            Setlist.self,
            BitVariation.self,
            SetlistAssignment.self,
            Performance.self,
            UserProfile.self
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            cloudKitDatabase: .automatic  // ✨ This enables iCloud sync!
        )
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
    
    private func configureGlobalAppearance() {
        // ... existing implementation stays the same ...
    }
}
```

### Step 3: Handle Initial Migration (Optional but Recommended)

If you already have users with local data, you'll want to migrate their existing data to the iCloud container. Here's an enhanced version with migration support:

```swift
@main
struct TightFiveApp: App {
    @State private var appSettings = AppSettings.shared
    @State private var showQuickBit = false
    @State private var migrationState: MigrationState = .checking
    
    enum MigrationState {
        case checking
        case migrating
        case complete
        case error(String)
    }
    
    init() {
        TFTheme.applySystemAppearance()
        configureGlobalAppearance()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                switch migrationState {
                case .checking, .migrating:
                    migrationView
                case .complete:
                    ContentView()
                        .tint(TFTheme.yellow)
                        .environment(appSettings)
                        .globalKeyboardDismiss()
                        .syncWithWidget(showQuickBit: $showQuickBit)
                        .sheet(isPresented: $showQuickBit) {
                            QuickBitEditor()
                                .presentationDetents([.medium, .large])
                        }
                        .onAppear {
                            configureGlobalAppearance()
                        }
                        .onChange(of: appSettings.appFont) { oldValue, newValue in
                            configureGlobalAppearance()
                        }
                case .error(let message):
                    errorView(message)
                }
            }
            .task {
                await checkAndMigrateIfNeeded()
            }
        }
        .modelContainer(sharedModelContainer)
    }
    
    // MARK: - Shared Model Container with iCloud Sync
    
    private var sharedModelContainer: ModelContainer {
        let schema = Schema([
            Bit.self,
            Setlist.self,
            BitVariation.self,
            SetlistAssignment.self,
            Performance.self,
            UserProfile.self
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            cloudKitDatabase: .automatic
        )
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
    
    // MARK: - Migration
    
    private func checkAndMigrateIfNeeded() async {
        // Check if this is first launch with iCloud
        let defaults = UserDefaults.standard
        let hasCompletedICloudMigration = defaults.bool(forKey: "hasCompletedICloudMigration")
        
        if hasCompletedICloudMigration {
            migrationState = .complete
            return
        }
        
        // Check if there's local data to migrate
        let hasLocalData = await checkForLocalData()
        
        if !hasLocalData {
            // No local data, just mark as complete
            defaults.set(true, forKey: "hasCompletedICloudMigration")
            migrationState = .complete
            return
        }
        
        // Perform migration
        migrationState = .migrating
        
        do {
            // SwiftData with CloudKit will automatically handle migration
            // We just need to wait a moment for initial sync
            try await Task.sleep(for: .seconds(2))
            
            defaults.set(true, forKey: "hasCompletedICloudMigration")
            migrationState = .complete
        } catch {
            migrationState = .error("Migration failed: \(error.localizedDescription)")
        }
    }
    
    private func checkForLocalData() async -> Bool {
        do {
            let container = sharedModelContainer
            let context = ModelContext(container)
            
            let bitDescriptor = FetchDescriptor<Bit>()
            let bits = try context.fetch(bitDescriptor)
            
            return !bits.isEmpty
        } catch {
            return false
        }
    }
    
    // MARK: - Migration Views
    
    private var migrationView: some View {
        ZStack {
            Color("TFCard")
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: TFTheme.yellow))
                    .scaleEffect(1.5)
                
                VStack(spacing: 12) {
                    Text(migrationState == .checking ? "Checking iCloud" : "Setting up iCloud Sync")
                        .appFont(.title2, weight: .semibold)
                        .foregroundStyle(TFTheme.text)
                    
                    Text("Your data is being prepared for sync")
                        .appFont(.subheadline)
                        .foregroundStyle(TFTheme.text.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
        }
    }
    
    private func errorView(_ message: String) -> some View {
        ZStack {
            Color("TFCard")
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 48))
                    .foregroundStyle(.red)
                
                VStack(spacing: 12) {
                    Text("Setup Error")
                        .appFont(.title2, weight: .semibold)
                        .foregroundStyle(TFTheme.text)
                    
                    Text(message)
                        .appFont(.subheadline)
                        .foregroundStyle(TFTheme.text.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                Button {
                    Task {
                        await checkAndMigrateIfNeeded()
                    }
                } label: {
                    Text("Retry")
                        .appFont(.headline)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(TFTheme.yellow)
                        .clipShape(Capsule())
                }
            }
            .padding()
        }
    }
    
    private func configureGlobalAppearance() {
        // ... existing implementation ...
    }
}
```

### Step 4: Add iCloud Status Indicator (Optional)

Add a visual indicator to show users their sync status. Create a new view:

```swift
// iCloudSyncStatusView.swift
import SwiftUI
import SwiftData

struct iCloudSyncStatusView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var syncStatus: SyncStatus = .checking
    
    enum SyncStatus {
        case checking
        case synced
        case syncing
        case error
        case notSignedIn
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: syncStatusIcon)
                .foregroundStyle(syncStatusColor)
            
            Text(syncStatusText)
                .appFont(.caption2)
                .foregroundStyle(TFTheme.text.opacity(0.6))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.05))
        .clipShape(Capsule())
        .onAppear {
            checkSyncStatus()
        }
    }
    
    private var syncStatusIcon: String {
        switch syncStatus {
        case .checking:
            return "icloud"
        case .synced:
            return "icloud.and.arrow.up"
        case .syncing:
            return "arrow.triangle.2.circlepath.icloud"
        case .error:
            return "exclamationmark.icloud"
        case .notSignedIn:
            return "person.crop.circle.badge.xmark"
        }
    }
    
    private var syncStatusColor: Color {
        switch syncStatus {
        case .checking, .synced, .syncing:
            return TFTheme.yellow
        case .error:
            return .red
        case .notSignedIn:
            return .orange
        }
    }
    
    private var syncStatusText: String {
        switch syncStatus {
        case .checking:
            return "Checking..."
        case .synced:
            return "Synced"
        case .syncing:
            return "Syncing..."
        case .error:
            return "Sync Error"
        case .notSignedIn:
            return "iCloud Off"
        }
    }
    
    private func checkSyncStatus() {
        Task {
            // Check iCloud account status
            let accountStatus = await CKContainer.default().accountStatus()
            
            await MainActor.run {
                switch accountStatus {
                case .available:
                    syncStatus = .synced
                case .noAccount, .restricted:
                    syncStatus = .notSignedIn
                case .couldNotDetermine:
                    syncStatus = .checking
                case .temporarilyUnavailable:
                    syncStatus = .error
                @unknown default:
                    syncStatus = .error
                }
            }
        }
    }
}
```

Then add it to your Settings view:

```swift
// In SettingsView.swift, add this section:

// iCloud Sync Status
Section {
    HStack {
        Image(systemName: "icloud")
            .foregroundStyle(TFTheme.yellow)
        
        Text("iCloud Sync")
            .appFont(.body)
            .foregroundStyle(TFTheme.text)
        
        Spacer()
        
        iCloudSyncStatusView()
    }
    .padding(.vertical, 4)
} header: {
    Text("BACKUP & SYNC")
        .appFont(.caption, weight: .semibold)
        .foregroundStyle(TFTheme.text.opacity(0.5))
}
```

### Step 5: Handle Audio Files (Performance Recordings)

Audio files stored in `Performance` records need special handling since CloudKit has file size limits. Here are two approaches:

#### Option A: Store Audio in iCloud Drive (Recommended)
```swift
// In Performance model, update audio storage location
extension Performance {
    static var recordingsDirectory: URL {
        // Use iCloud Drive for audio files
        if let iCloudURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents")
            .appendingPathComponent("Recordings") {
            
            // Create directory if needed
            try? FileManager.default.createDirectory(at: iCloudURL, withIntermediateDirectories: true)
            return iCloudURL
        }
        
        // Fallback to local documents
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsURL.appendingPathComponent("Recordings")
    }
}
```

#### Option B: Keep Audio Local with Optional iCloud Upload
```swift
// Add a user preference for audio sync
extension AppSettings {
    @AppStorage("syncAudioRecordings") var syncAudioRecordings: Bool = false
}

// In Settings, add a toggle:
Toggle("Sync Audio Recordings", isOn: $appSettings.syncAudioRecordings)
    .tint(TFTheme.yellow)
```

### Step 6: Update Widget Configuration

If using App Groups with widgets, update WidgetIntegration.swift to be aware of iCloud:

```swift
// Note: Widgets can read from iCloud-synced SwiftData
// No changes needed if you're already using ModelContainer in widgets
// The same cloudKitDatabase: .automatic will work
```

### Step 7: Test iCloud Sync

#### Testing Checklist:
1. **Sign in to iCloud** on your test device
2. **Enable iCloud Drive** in Settings → Apple ID → iCloud
3. **Install the app** and create some data (bits, setlists, etc.)
4. **Open CloudKit Dashboard** (developer.apple.com/icloud/dashboard)
5. **Verify data** appears in your container
6. **Install on second device** with same iCloud account
7. **Verify sync** - data should appear automatically
8. **Test conflict resolution** - make changes offline on both devices, then go online
9. **Test deletion** - delete on one device, verify on other
10. **Test large data** - create many bits, verify performance

## Important Considerations

### 1. CloudKit Limits
- **Free tier**: 1GB database storage per user
- **Asset storage**: 250MB per user
- **Request limits**: Reasonable for typical usage
- **Consider**: Audio files can be large - implement Option A or B above

### 2. User Privacy
- Data is tied to user's iCloud account
- Cannot access data from different Apple IDs
- Users must be signed in to iCloud
- Consider adding a "Sign in to iCloud" prompt if not signed in

### 3. Testing
- Use **Development CloudKit environment** during testing
- Switch to **Production** before App Store release
- Test with multiple devices
- Test with poor network conditions

### 4. Error Handling
Consider adding retry logic for network failures:

```swift
extension ModelContext {
    func saveWithRetry(maxAttempts: Int = 3) async throws {
        var lastError: Error?
        
        for attempt in 1...maxAttempts {
            do {
                try self.save()
                return
            } catch {
                lastError = error
                if attempt < maxAttempts {
                    // Wait before retry (exponential backoff)
                    try await Task.sleep(for: .seconds(pow(2.0, Double(attempt))))
                }
            }
        }
        
        throw lastError ?? NSError(domain: "ModelContext", code: -1)
    }
}
```

### 5. Notification Handling
Monitor CloudKit notifications for sync events:

```swift
import CloudKit

class CloudKitManager: ObservableObject {
    @Published var isSyncing = false
    
    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleStoreRemoteChange),
            name: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil
        )
    }
    
    @objc private func handleStoreRemoteChange(_ notification: Notification) {
        // Handle sync events
        DispatchQueue.main.async {
            self.isSyncing = true
            
            // Reset after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.isSyncing = false
            }
        }
    }
}
```

## Troubleshooting

### "CloudKit is not available"
- Check that user is signed in to iCloud
- Verify iCloud Drive is enabled
- Check entitlements are correctly configured

### "Container not found"
- Verify container ID matches in Xcode capabilities
- Check that container exists in CloudKit Dashboard
- Ensure signing is configured correctly

### Data not syncing
- Check network connection
- Verify CloudKit Dashboard shows data
- Try signing out and back in to iCloud
- Check Console.app for CloudKit logs

### Sync conflicts
- SwiftData handles most conflicts automatically
- For custom conflict resolution, implement merge logic in models

## Additional Resources

- [Apple CloudKit Documentation](https://developer.apple.com/icloud/cloudkit/)
- [SwiftData with CloudKit](https://developer.apple.com/documentation/swiftdata)
- [CloudKit Dashboard](https://icloud.developer.apple.com/dashboard)
- [Testing CloudKit Apps](https://developer.apple.com/documentation/cloudkit/testing_cloudkit_apps)

## Summary

After implementing the above:
- ✅ All user data automatically backs up to iCloud
- ✅ Data syncs across iPhone, iPad, and Mac
- ✅ Conflict resolution happens automatically
- ✅ Users can safely delete the app without losing data
- ✅ Zero manual backup configuration needed

The key change is just one line in your ModelConfiguration:
```swift
cloudKitDatabase: .automatic
```

Everything else is optional polish to make the experience smoother!
