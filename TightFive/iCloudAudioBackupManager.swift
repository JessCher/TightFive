import Foundation
import SwiftUI
import SwiftData
import Combine

/// Manages backup and sync of audio recordings to iCloud Drive.
/// Provides user control over when and how audio files are synced.
@MainActor
class iCloudAudioBackupManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = iCloudAudioBackupManager()
    
    // MARK: - Published Properties
    
    @Published var isBackingUp = false
    @Published var lastBackupDate: Date?
    @Published var backupProgress: Double = 0
    @Published var backupStatus: BackupStatus = .idle
    @Published var totalFiles: Int = 0
    @Published var backedUpFiles: Int = 0
    @Published var errorMessage: String?
    
    // MARK: - User Preferences (stored separately to avoid @Observable/@AppStorage conflict)
    
    var syncAudioRecordings: Bool {
        get {
            UserDefaults.standard.bool(forKey: "syncAudioRecordings")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "syncAudioRecordings")
            if newValue {
                // When enabled, start initial backup
                Task {
                    await backupAllRecordings()
                }
            }
        }
    }
    
    private var lastBackupTimestamp: Double {
        get {
            UserDefaults.standard.double(forKey: "lastAudioBackupDate")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "lastAudioBackupDate")
            if newValue > 0 {
                lastBackupDate = Date(timeIntervalSince1970: newValue)
            }
        }
    }
    
    // MARK: - Backup Status
    
    enum BackupStatus: Equatable {
        case idle
        case checking
        case backing(current: Int, total: Int)
        case complete
        case error(String)
        
        var displayText: String {
            switch self {
            case .idle:
                return "Ready"
            case .checking:
                return "Checking files..."
            case .backing(let current, let total):
                return "Backing up \(current) of \(total)"
            case .complete:
                return "Backup complete"
            case .error(let message):
                return "Error: \(message)"
            }
        }
    }
    
    // MARK: - Directory URLs
    
    /// Local recordings directory (always available)
    private var localRecordingsURL: URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsURL.appendingPathComponent("Recordings")
    }
    
    /// iCloud Drive recordings directory (only available when iCloud is enabled)
    private var iCloudRecordingsURL: URL? {
        guard let iCloudURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents")
            .appendingPathComponent("Recordings") else {
            return nil
        }
        
        // Ensure directory exists
        try? FileManager.default.createDirectory(at: iCloudURL, withIntermediateDirectories: true)
        return iCloudURL
    }
    
    // MARK: - Initialization
    
    private init() {
        // Load last backup date
        if lastBackupTimestamp > 0 {
            lastBackupDate = Date(timeIntervalSince1970: lastBackupTimestamp)
        }
    }
    
    // MARK: - Public Methods
    
    /// Check if iCloud is available for audio backup
    func isICloudAvailable() -> Bool {
        return iCloudRecordingsURL != nil
    }
    
    /// Manually trigger backup of all recordings
    func backupAllRecordings() async {
        guard !isBackingUp else { return }
        guard syncAudioRecordings else { return }
        guard let iCloudURL = iCloudRecordingsURL else {
            backupStatus = .error("iCloud Drive not available")
            return
        }
        
        isBackingUp = true
        backupStatus = .checking
        backupProgress = 0
        errorMessage = nil
        
        do {
            // Get all local recordings
            let localFiles = try FileManager.default.contentsOfDirectory(
                at: localRecordingsURL,
                includingPropertiesForKeys: [.fileSizeKey],
                options: [.skipsHiddenFiles]
            )
            
            totalFiles = localFiles.count
            backedUpFiles = 0
            
            if totalFiles == 0 {
                backupStatus = .complete
                isBackingUp = false
                return
            }
            
            // Backup each file
            for (index, localFile) in localFiles.enumerated() {
                backedUpFiles = index + 1
                backupStatus = .backing(current: backedUpFiles, total: totalFiles)
                backupProgress = Double(backedUpFiles) / Double(totalFiles)
                
                let filename = localFile.lastPathComponent
                let iCloudFile = iCloudURL.appendingPathComponent(filename)
                
                // Check if file already exists in iCloud
                if !FileManager.default.fileExists(atPath: iCloudFile.path) {
                    // Copy to iCloud
                    try FileManager.default.copyItem(at: localFile, to: iCloudFile)
                }
                
                // Small delay to prevent overwhelming the system
                try await Task.sleep(for: .milliseconds(100))
            }
            
            // Success
            backupStatus = .complete
            lastBackupTimestamp = Date().timeIntervalSince1970
            
            // Reset status after delay
            try await Task.sleep(for: .seconds(2))
            backupStatus = .idle
            
        } catch {
            backupStatus = .error(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
        
        isBackingUp = false
    }
    
    /// Backup a single recording file
    func backupRecording(filename: String) async throws {
        guard syncAudioRecordings else { return }
        guard let iCloudURL = iCloudRecordingsURL else {
            throw BackupError.iCloudUnavailable
        }
        
        let localFile = localRecordingsURL.appendingPathComponent(filename)
        let iCloudFile = iCloudURL.appendingPathComponent(filename)
        
        // Only copy if not already in iCloud
        if !FileManager.default.fileExists(atPath: iCloudFile.path) {
            try FileManager.default.copyItem(at: localFile, to: iCloudFile)
        }
    }
    
    /// Delete a recording from both local and iCloud
    func deleteRecording(filename: String) async throws {
        // Delete from local
        let localFile = localRecordingsURL.appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: localFile.path) {
            try FileManager.default.removeItem(at: localFile)
        }
        
        // Delete from iCloud if sync is enabled
        if syncAudioRecordings, let iCloudURL = iCloudRecordingsURL {
            let iCloudFile = iCloudURL.appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: iCloudFile.path) {
                try FileManager.default.removeItem(at: iCloudFile)
            }
        }
    }
    
    /// Get storage usage for local and iCloud recordings
    func getStorageUsage() -> (local: Int64, iCloud: Int64) {
        var localSize: Int64 = 0
        var iCloudSize: Int64 = 0
        
        // Calculate local size
        if let localFiles = try? FileManager.default.contentsOfDirectory(
            at: localRecordingsURL,
            includingPropertiesForKeys: [.fileSizeKey]
        ) {
            for file in localFiles {
                if let attributes = try? FileManager.default.attributesOfItem(atPath: file.path),
                   let size = attributes[.size] as? Int64 {
                    localSize += size
                }
            }
        }
        
        // Calculate iCloud size
        if let iCloudURL = iCloudRecordingsURL,
           let iCloudFiles = try? FileManager.default.contentsOfDirectory(
            at: iCloudURL,
            includingPropertiesForKeys: [.fileSizeKey]
           ) {
            for file in iCloudFiles {
                if let attributes = try? FileManager.default.attributesOfItem(atPath: file.path),
                   let size = attributes[.size] as? Int64 {
                    iCloudSize += size
                }
            }
        }
        
        return (local: localSize, iCloud: iCloudSize)
    }
    
    // MARK: - Helper Methods
    
    /// Format bytes to human-readable string
    static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Errors

enum BackupError: LocalizedError {
    case iCloudUnavailable
    case syncDisabled
    case fileNotFound
    
    var errorDescription: String? {
        switch self {
        case .iCloudUnavailable:
            return "iCloud Drive is not available"
        case .syncDisabled:
            return "Audio sync is disabled"
        case .fileNotFound:
            return "Recording file not found"
        }
    }
}

// MARK: - Performance Extension

extension Performance {
    /// Automatically backup recording when created (if sync is enabled)
    func autoBackupIfNeeded() {
        guard !audioFilename.isEmpty else { return }
        
        Task {
            try? await iCloudAudioBackupManager.shared.backupRecording(filename: audioFilename)
        }
    }
}
