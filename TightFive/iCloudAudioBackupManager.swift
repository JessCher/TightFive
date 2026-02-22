import Foundation
import SwiftUI
import SwiftData
import CloudKit
import Combine

/// Manages backup and sync of audio recordings to iCloud Drive.
/// Provides user control over when and how audio files are synced.
@MainActor
class iCloudAudioBackupManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = iCloudAudioBackupManager()
    private static let ubiquityContainerIdentifier = "iCloud.com.tightfive.app"
    
    // MARK: - Published Properties
    
    @Published var isBackingUp = false
    @Published var lastBackupDate: Date?
    @Published var backupProgress: Double = 0
    @Published var backupStatus: BackupStatus = .idle
    @Published var totalFiles: Int = 0
    @Published var backedUpFiles: Int = 0
    @Published var errorMessage: String?
    @Published var isDownloading = false
    @Published var downloadError: String?
    
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
        guard let iCloudURL = ubiquityContainerURL()?
            .appendingPathComponent("Documents")
            .appendingPathComponent("Recordings") else {
            return nil
        }
        
        // Ensure directory exists
        try? FileManager.default.createDirectory(at: iCloudURL, withIntermediateDirectories: true)
        return iCloudURL
    }

    /// Resolve ubiquity container with an explicit identifier first, then fallback
    /// to the default container for compatibility with older builds.
    private func ubiquityContainerURL() -> URL? {
        if let explicit = FileManager.default.url(
            forUbiquityContainerIdentifier: Self.ubiquityContainerIdentifier
        ) {
            return explicit
        }
        return FileManager.default.url(forUbiquityContainerIdentifier: nil)
    }
    
    // MARK: - Initialization
    
    private init() {
        // Load last backup date
        if lastBackupTimestamp > 0 {
            lastBackupDate = Date(timeIntervalSince1970: lastBackupTimestamp)
        }
    }
    
    // MARK: - Public Methods
    
    /// Check if iCloud Drive ubiquity container is reachable for audio backup.
    ///
    /// > Note: This only checks the ubiquity container. The iCloud *account*
    /// > may be available (CloudKit works) even when this returns `false` – for
    /// > example before the container has been initialised on a fresh install.
    /// > UI that gates user interaction should prefer ``isICloudAccountAvailable()``
    /// > which checks the CloudKit account status instead.
    func isICloudDriveAvailable() -> Bool {
        return iCloudRecordingsURL != nil
    }

    /// Check whether the user's iCloud account is signed-in and available
    /// via CloudKit. This is the correct check for determining whether the
    /// backup toggle should be enabled, because CloudKit availability is
    /// what the rest of the app relies on for sync.
    func isICloudAccountAvailable() async -> Bool {
        do {
            let status = try await CKContainer.default().accountStatus()
            return status == .available
        } catch {
            return false
        }
    }
    
    /// Manually trigger backup of all recordings
    func backupAllRecordings() async {
        guard !isBackingUp else { return }
        guard syncAudioRecordings else { return }
        guard let iCloudURL = iCloudRecordingsURL else {
            backupStatus = .error("iCloud Drive not available")
            errorMessage = "iCloud Drive not available"
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
            
            // Perform file I/O on a background utility thread to avoid
            // blocking the main actor, reporting progress back as we go.
            try await Task.detached(priority: .utility) { [localFiles, iCloudURL] in
                for (index, localFile) in localFiles.enumerated() {
                    let current = index + 1
                    let total = localFiles.count
                    let progress = Double(current) / Double(total)
                    
                    await MainActor.run {
                        self.backedUpFiles = current
                        self.backupStatus = .backing(current: current, total: total)
                        self.backupProgress = progress
                    }
                    
                    let iCloudFile = iCloudURL.appendingPathComponent(localFile.lastPathComponent)
                    if !FileManager.default.fileExists(atPath: iCloudFile.path) {
                        try FileManager.default.copyItem(at: localFile, to: iCloudFile)
                    }
                    
                    // Yield cooperatively between files so other tasks can run
                    await Task.yield()
                }
            }.value
            
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
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) {
            for file in localFiles {
                if let values = try? file.resourceValues(forKeys: [.fileSizeKey]),
                   let size = values.fileSize {
                    localSize += Int64(size)
                }
            }
        }

        // Calculate iCloud size – must handle both downloaded files and
        // evicted .icloud placeholder files. When iCloud reclaims disk space
        // it replaces "File.m4a" with ".File.m4a.icloud" (a small binary
        // plist). We parse the plist to recover the real file size.
        if let iCloudURL = iCloudRecordingsURL,
           let iCloudFiles = try? FileManager.default.contentsOfDirectory(
            at: iCloudURL,
            includingPropertiesForKeys: [.fileSizeKey]
           ) {
            for file in iCloudFiles {
                let name = file.lastPathComponent

                if name.hasPrefix(".") && name.hasSuffix(".icloud") {
                    // Evicted iCloud file – extract actual size from placeholder plist
                    if let size = iCloudPlaceholderFileSize(at: file) {
                        iCloudSize += size
                    }
                } else {
                    // Downloaded file – use actual size via resource values
                    if let values = try? file.resourceValues(forKeys: [.fileSizeKey]),
                       let size = values.fileSize {
                        iCloudSize += Int64(size)
                    }
                }
            }
        }

        return (local: localSize, iCloud: iCloudSize)
    }

    /// Extract the actual file size from a `.icloud` placeholder file.
    /// These placeholders are binary plists containing the original file's size.
    private func iCloudPlaceholderFileSize(at url: URL) -> Int64? {
        guard let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(
                from: data, format: nil
              ) as? [String: Any] else {
            return nil
        }
        if let size = plist["NSURLFileSizeKey"] as? NSNumber {
            return size.int64Value
        }
        return nil
    }
    
    // MARK: - iCloud Download

    /// Download a recording from iCloud Drive and copy it to local storage.
    /// Returns the local URL once the file is available for playback.
    func downloadRecordingFromiCloud(filename: String) async throws -> URL {
        guard let iCloudBase = ubiquityContainerURL()?
            .appendingPathComponent("Documents")
            .appendingPathComponent("Recordings") else {
            throw BackupError.iCloudUnavailable
        }

        let iCloudFileURL = iCloudBase.appendingPathComponent(filename)
        let localFile = localRecordingsURL.appendingPathComponent(filename)

        // Already available locally
        if FileManager.default.fileExists(atPath: localFile.path) {
            return localFile
        }

        // Downloaded in ubiquity container but not copied locally yet
        if FileManager.default.fileExists(atPath: iCloudFileURL.path) {
            try FileManager.default.copyItem(at: iCloudFileURL, to: localFile)
            return localFile
        }

        // File is evicted – trigger iCloud download
        isDownloading = true
        downloadError = nil
        defer { isDownloading = false }

        do {
            try FileManager.default.startDownloadingUbiquitousItem(at: iCloudFileURL)
        } catch {
            downloadError = error.localizedDescription
            throw error
        }

        // Poll until the file materialises (or timeout)
        let maxWait: TimeInterval = 120
        let start = Date()

        while !FileManager.default.fileExists(atPath: iCloudFileURL.path) {
            if Date().timeIntervalSince(start) > maxWait {
                downloadError = BackupError.downloadTimeout.localizedDescription
                throw BackupError.downloadTimeout
            }
            try await Task.sleep(for: .milliseconds(500))
        }

        // Copy to local recordings directory for future offline access
        if !FileManager.default.fileExists(atPath: localFile.path) {
            try FileManager.default.copyItem(at: iCloudFileURL, to: localFile)
        }

        return localFile
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
    case downloadTimeout

    var errorDescription: String? {
        switch self {
        case .iCloudUnavailable:
            return "iCloud Drive is not available"
        case .syncDisabled:
            return "Audio sync is disabled"
        case .fileNotFound:
            return "Recording file not found"
        case .downloadTimeout:
            return "Download timed out. Please check your internet connection and try again."
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
