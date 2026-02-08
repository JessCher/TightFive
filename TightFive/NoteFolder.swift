import Foundation
import SwiftData

/// User-created folder for organizing notebook notes.
@Model
final class NoteFolder {

    // MARK: - Identity

    var id: UUID = UUID()
    var title: String = ""
    var sortOrder: Int = 0
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // MARK: - Relationships

    @Relationship(inverse: \Note.folder)
    var notes: [Note]? = []

    // MARK: - Initialization

    init(title: String, sortOrder: Int) {
        self.id = UUID()
        self.title = title
        self.sortOrder = sortOrder
        let now = Date()
        self.createdAt = now
        self.updatedAt = now
    }
}

extension NoteFolder {
    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled Folder" : trimmed
    }
}
