import SwiftUI
import CloudKit
import CoreData

/// Displays the current iCloud sync status for TightFive.
/// Shows whether user is signed in, syncing, synced, or has errors.
struct iCloudSyncStatusView: View {
    @State private var syncStatus: SyncStatus = .checking
    @State private var lastSyncTime: Date?
    
    enum SyncStatus: Equatable {
        case checking
        case synced
        case syncing
        case error(String)
        case notSignedIn
        
        var icon: String {
            switch self {
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
        
        var color: Color {
            switch self {
            case .checking, .synced, .syncing:
                return TFTheme.yellow
            case .error:
                return .red
            case .notSignedIn:
                return .orange
            }
        }
        
        var text: String {
            switch self {
            case .checking:
                return "Checking..."
            case .synced:
                return "Synced"
            case .syncing:
                return "Syncing..."
            case .error(let message):
                return message
            case .notSignedIn:
                return "iCloud Off"
            }
        }
        
        var detailText: String? {
            switch self {
            case .synced:
                return "All data backed up"
            case .syncing:
                return "Updating..."
            case .notSignedIn:
                return "Sign in to iCloud to backup"
            case .error:
                return "Tap for details"
            case .checking:
                return nil
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                // Status icon
                ZStack {
                    Circle()
                        .fill(syncStatus.color.opacity(0.15))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: syncStatus.icon)
                        .font(.system(size: 16))
                        .foregroundStyle(syncStatus.color)
                        .symbolEffect(.pulse, options: .repeating, isActive: syncStatus == .syncing)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(syncStatus.text)
                        .appFont(.body, weight: .semibold)
                        .foregroundStyle(TFTheme.text)
                    
                    if let detailText = syncStatus.detailText {
                        Text(detailText)
                            .appFont(.caption2)
                            .foregroundStyle(TFTheme.text.opacity(0.5))
                    }
                    
                    if let lastSync = lastSyncTime, case .synced = syncStatus {
                        Text("Last synced \(lastSync, style: .relative)")
                            .appFont(.caption2)
                            .foregroundStyle(TFTheme.text.opacity(0.4))
                    }
                }
                
                Spacer()
                
                // Info button
                if case .notSignedIn = syncStatus {
                    Button {
                        openSettings()
                    } label: {
                        Text("Sign In")
                            .appFont(.caption, weight: .semibold)
                            .foregroundStyle(.black)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(TFTheme.yellow)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(16)
        .tfDynamicCard(cornerRadius: 14)
        .onAppear {
            checkSyncStatus()
            startMonitoring()
        }
    }
    
    private func checkSyncStatus() {
        Task {
            // Check iCloud account status
            do {
                let accountStatus = try await CKContainer.default().accountStatus()
                
                await MainActor.run {
                    switch accountStatus {
                    case .available:
                        syncStatus = .synced
                        lastSyncTime = Date()
                    case .noAccount:
                        syncStatus = .notSignedIn
                    case .restricted:
                        syncStatus = .error("iCloud is restricted")
                    case .couldNotDetermine:
                        syncStatus = .checking
                    case .temporarilyUnavailable:
                        syncStatus = .error("Temporarily unavailable")
                    @unknown default:
                        syncStatus = .error("Unknown status")
                    }
                }
            } catch {
                await MainActor.run {
                    syncStatus = .error("Check failed")
                }
            }
        }
    }
    
    private func startMonitoring() {
        // Listen for CloudKit notifications
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name.NSPersistentStoreRemoteChange,
            object: nil,
            queue: .main
        ) { _ in
            // Sync activity detected
            syncStatus = .syncing
            
            // After a short delay, mark as synced
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                if case .syncing = syncStatus {
                    syncStatus = .synced
                    lastSyncTime = Date()
                }
            }
        }
    }
    
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Compact Version for Toolbar

/// Compact iCloud sync indicator for use in toolbars or status bars
struct CompactiCloudSyncIndicator: View {
    @State private var syncStatus: SyncStatus = .checking
    
    enum SyncStatus {
        case checking
        case synced
        case syncing
        case error
        case notSignedIn
        
        var icon: String {
            switch self {
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
        
        var color: Color {
            switch self {
            case .checking, .synced, .syncing:
                return TFTheme.yellow
            case .error:
                return .red
            case .notSignedIn:
                return .orange
            }
        }
    }
    
    var body: some View {
        Image(systemName: syncStatus.icon)
            .font(.system(size: 14))
            .foregroundStyle(syncStatus.color)
            .symbolEffect(.pulse, options: .repeating, isActive: syncStatus == .syncing)
            .onAppear {
                checkStatus()
            }
    }
    
    private func checkStatus() {
        Task {
            do {
                let accountStatus = try await CKContainer.default().accountStatus()
                await MainActor.run {
                    switch accountStatus {
                    case .available:
                        syncStatus = .synced
                    case .noAccount, .restricted:
                        syncStatus = .notSignedIn
                    default:
                        syncStatus = .error
                    }
                }
            } catch {
                await MainActor.run {
                    syncStatus = .error
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        iCloudSyncStatusView()
        
        HStack {
            Text("Compact:")
            CompactiCloudSyncIndicator()
        }
    }
    .padding()
    .tfBackground()
}
