import Foundation
import SwiftData

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
    var notes: String
    var rating: Int
    
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
        self.notes = ""
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
