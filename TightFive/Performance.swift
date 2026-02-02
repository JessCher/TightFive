import Foundation
import SwiftData
import SwiftUI

/// A recorded comedy performance with audio and metadata.
@Model
final class Performance {
    
    var id: UUID
    var createdAt: Date
    var datePerformed: Date
    var setlistId: UUID
    var setlistTitle: String
    var customTitle: String?
    var city: String
    var venue: String
    var audioFilename: String
    var duration: TimeInterval
    var fileSize: Int64
    var notes: String  // Keep as String - no schema change
    var rating: Int  // "How it felt" - manual overall rating
    
    // MARK: - Individual Bit Ratings & Notes
    
    /// Dictionary of bit ratings by script block ID (1-5 stars)
    @Attribute(.externalStorage) var bitRatings: [String: Int] = [:]
    
    /// Dictionary of bit notes by script block ID
    @Attribute(.externalStorage) var bitNotes: [String: String] = [:]
    
    /// Auto-calculated "How it went" rating based on bit ratings
    var calculatedRating: Int {
        let ratings = bitRatings.values.filter { $0 > 0 }
        guard !ratings.isEmpty else { return 0 }
        let sum = ratings.reduce(0, +)
        return Int(round(Double(sum) / Double(ratings.count)))
    }
    
    // MARK: - Soft Delete
    
    /// When true, performance is hidden from main views but recoverable from Trashcan
    var isDeleted: Bool = false
    
    /// Timestamp of deletion (nil if not deleted)
    var deletedAt: Date?
    
    // MARK: - AI Analytics (Added)
    
    /// Serialized performance insights (JSON)
    var analyticsData: Data?
    
    /// Cached insights (computed property, lazy)
    var insights: [PerformanceAnalytics.Insight]? {
        get {
            guard let data = analyticsData else { return nil }
            return try? JSONDecoder().decode([PerformanceAnalytics.Insight].self, from: data)
        }
        set {
            analyticsData = try? JSONEncoder().encode(newValue)
        }
    }
    
    /// Has AI analysis been performed?
    var hasAnalytics: Bool {
        analyticsData != nil
    }
    
    init(
        setlistId: UUID,
        setlistTitle: String,
        customTitle: String? = nil,
        datePerformed: Date? = nil,
        city: String = "",
        venue: String = "",
        audioFilename: String,
        duration: TimeInterval = 0,
        fileSize: Int64 = 0
    ) {
        self.id = UUID()
        self.createdAt = Date()
        self.datePerformed = datePerformed ?? Date()
        self.setlistId = setlistId
        self.setlistTitle = setlistTitle
        self.customTitle = customTitle
        self.city = city
        self.venue = venue
        self.audioFilename = audioFilename
        self.duration = duration
        self.fileSize = fileSize
        self.notes = ""  // Back to String
        self.rating = 0
    }
}

extension Performance {
    
    var displayTitle: String {
        customTitle?.isEmpty == false ? customTitle! : setlistTitle
    }
    
    var audioURL: URL? {
        guard !audioFilename.isEmpty else { return nil }
        return Performance.recordingsDirectory.appendingPathComponent(audioFilename)
    }
    
    var audioFileExists: Bool {
        guard let url = audioURL else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }
    
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: datePerformed)
    }
    
    var formattedDateWithTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
    
    var isReviewed: Bool {
        rating > 0 || !notes.isEmpty
    }
}

extension Performance {
    
    static var recordingsDirectory: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let recordings = documents.appendingPathComponent("Recordings", isDirectory: true)
        if !FileManager.default.fileExists(atPath: recordings.path) {
            try? FileManager.default.createDirectory(at: recordings, withIntermediateDirectories: true)
        }
        return recordings
    }
    
    static func generateFilename(for setlistTitle: String) -> String {
        let sanitized = setlistTitle
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "-")
            .prefix(30)
        let timestamp = Int(Date().timeIntervalSince1970)
        return "\(sanitized)_\(timestamp).m4a"
    }
    
    func deleteAudioFile() {
        guard let url = audioURL else { return }
        try? FileManager.default.removeItem(at: url)
    }
    
    static var totalStorageUsed: Int64 {
        let fileManager = FileManager.default
        let directory = recordingsDirectory
        guard let files = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        var total: Int64 = 0
        for file in files {
            if let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += Int64(size)
            }
        }
        return total
    }
    
    static var formattedTotalStorage: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalStorageUsed)
    }
}
// MARK: - Soft Delete Operations

extension Performance {
    
    /// Soft delete the performance.
    ///
    /// **What happens:**
    /// - `isDeleted` set to true (hides from main views)
    /// - `deletedAt` set to current timestamp
    /// - Performance becomes recoverable from Trashcan
    /// - Audio file remains on disk
    func softDelete() {
        isDeleted = true
        deletedAt = Date()
    }
    
    /// Restore a soft-deleted performance.
    func restore() {
        isDeleted = false
        deletedAt = nil
    }
    
    /// Hard delete: completely remove performance and audio file.
    func hardDelete(context: ModelContext) {
        deleteAudioFile()
        context.delete(self)
    }
}




