import Foundation
import SwiftData

/// A folder for organizing notes in the Notebook section.
///
/// Folders provide hierarchical organization for notes. Deleting a folder
/// cascades to delete all contained notes (matching SwiftData relationship patterns).
///
/// **Design:**
/// - Uses `@Relationship(deleteRule: .cascade)` so folder deletion removes all child notes
/// - Notes can exist without a folder (unassigned, visible in "All Notes")
/// - Folder names are user-provided and editable
@Model
final class NoteFolder {

    // MARK: - Identity

    var id: UUID = UUID()

    /// User-provided folder name
    var name: String = ""

    var createdAt: Date = Date()

    // MARK: - Relationships

    /// All notes in this folder. Cascade delete removes notes when folder is deleted.
    @Relationship(deleteRule: .cascade, inverse: \Note.folder)
    var notes: [Note]? = []

    // MARK: - Initialization

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
    }
}

// MARK: - Display Properties

extension NoteFolder {

    /// Number of non-deleted notes in the folder
    var activeNoteCount: Int {
        (notes ?? []).filter { !$0.isDeleted }.count
    }

    /// Display name with fallback
    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled Folder" : trimmed
    }
}
