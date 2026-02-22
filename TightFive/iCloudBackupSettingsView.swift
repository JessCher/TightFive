import SwiftUI
import CloudKit

/// Settings view for iCloud backup and sync configuration
struct iCloudBackupSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var backupManager = iCloudAudioBackupManager.shared
    @State private var syncStatus: iCloudSyncStatus = .checking
    @State private var showBackupConfirmation = false
    
    enum iCloudSyncStatus: Equatable {
        case checking
        case available
        case unavailable(String)
    }
    
    var body: some View {
        Form {
            // Main sync status card
            Section {
                iCloudSyncStatusView()
            }
            
            // Audio recordings backup section
            Section {
                // Toggle for audio sync
                Toggle(isOn: $backupManager.syncAudioRecordings) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Backup Audio Recordings")
                            .foregroundStyle(.white)
                        
                        Text("Sync performance recordings to iCloud Drive")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .tint(TFTheme.yellow)
                .disabled(syncStatus != .available)
                
                // Storage usage
                if backupManager.syncAudioRecordings {
                    storageUsageRow
                }
                
                // Last backup time
                if let lastBackup = backupManager.lastBackupDate {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundStyle(TFTheme.yellow)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Last Backup")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                            
                            Text(lastBackup, style: .relative)
                                .foregroundStyle(.white)
                                .font(.subheadline)
                            
                            Text(lastBackup, style: .date)
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        
                        Spacer()
                        
                        Text("ago")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .padding(.vertical, 4)
                }
                
                // Backup status
                if backupManager.isBackingUp {
                    HStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: TFTheme.yellow))
                            .scaleEffect(0.8)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(backupManager.backupStatus.displayText)
                                .font(.subheadline)
                                .foregroundStyle(.white)
                            
                            if backupManager.totalFiles > 0 {
                                ProgressView(value: backupManager.backupProgress)
                                    .tint(TFTheme.yellow)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // Manual backup button
                if backupManager.syncAudioRecordings {
                    Button {
                        showBackupConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise.icloud")
                                .foregroundStyle(TFTheme.yellow)
                            
                            Text("Backup Now")
                                .foregroundStyle(.white)
                            
                            Spacer()
                            
                            if !backupManager.isBackingUp {
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.3))
                            }
                        }
                    }
                    .disabled(backupManager.isBackingUp)
                }
                
            } header: {
                Text("AUDIO RECORDINGS")
            } footer: {
                if case .unavailable(let reason) = syncStatus {
                    Text("\(reason). Sign in to iCloud in Settings to enable backup.")
                } else if backupManager.syncAudioRecordings {
                    Text("Audio recordings will automatically backup to iCloud Drive. You can manually backup at any time.")
                } else {
                    Text("Enable to automatically backup performance recordings to iCloud Drive. Large files may use significant iCloud storage.")
                }
            }
            
            // Error message
            if let error = backupManager.errorMessage {
                Section {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Backup Error")
                                .font(.subheadline)
                                .foregroundStyle(.white)
                            
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            
            // Info section
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    infoRow(
                        icon: "checkmark.shield",
                        title: "Automatic Sync",
                        description: "All bits, setlists, and notes sync automatically"
                    )
                    
                    Divider()
                        .background(.white.opacity(0.2))
                    
                    infoRow(
                        icon: "lock.shield",
                        title: "Private & Secure",
                        description: "Your data is encrypted and tied to your Apple ID"
                    )
                    
                    Divider()
                        .background(.white.opacity(0.2))
                    
                    infoRow(
                        icon: "arrow.triangle.2.circlepath",
                        title: "Cross-Device",
                        description: "Access your content on all your devices"
                    )
                }
                .padding(.vertical, 4)
            } header: {
                Text("ABOUT iCLOUD SYNC")
            }
        }
        .scrollContentBackground(.hidden)
        .tfBackground()
        .navigationTitle("iCloud Backup")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                TFWordmarkTitle(title: "iCloud Backup", size: 20)
            }
        }
        .confirmationDialog(
            "Backup All Recordings?",
            isPresented: $showBackupConfirmation,
            titleVisibility: .visible
        ) {
            Button("Backup Now") {
                Task {
                    await backupManager.backupAllRecordings()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will backup all performance recordings to iCloud Drive. Depending on the number of files, this may take a few minutes.")
        }
        .onAppear {
            checkiCloudStatus()
        }
    }
    
    // MARK: - Storage Usage Row
    
    private var storageUsageRow: some View {
        HStack {
            Image(systemName: "internaldrive")
                .foregroundStyle(TFTheme.yellow)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Storage Usage")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                
                let usage = backupManager.getStorageUsage()
                
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Local")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))
                        Text(iCloudAudioBackupManager.formatBytes(usage.local))
                            .font(.subheadline)
                            .foregroundStyle(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("iCloud")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))
                        Text(iCloudAudioBackupManager.formatBytes(usage.iCloud))
                            .font(.subheadline)
                            .foregroundStyle(TFTheme.yellow)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Info Row
    
    private func infoRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(TFTheme.yellow.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(TFTheme.yellow)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }
    
    // MARK: - Check iCloud Status
    
    private func checkiCloudStatus() {
        Task {
            do {
                let status = try await CKContainer.default().accountStatus()
                
                await MainActor.run {
                    switch status {
                    case .available:
                        syncStatus = .available
                    case .noAccount:
                        syncStatus = .unavailable("Not signed in to iCloud")
                    case .restricted:
                        syncStatus = .unavailable("iCloud is restricted")
                    case .couldNotDetermine:
                        syncStatus = .unavailable("Cannot determine iCloud status")
                    case .temporarilyUnavailable:
                        syncStatus = .unavailable("iCloud temporarily unavailable")
                    @unknown default:
                        syncStatus = .unavailable("Unknown status")
                    }
                }
            } catch {
                await MainActor.run {
                    syncStatus = .unavailable("Error checking iCloud: \(error.localizedDescription)")
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        iCloudBackupSettingsView()
    }
}

