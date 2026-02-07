import Foundation
import SwiftData

/// A general-purpose note in the Notebook section.
///
/// Notes store rich text content using the same SwiftData persistence patterns as Bit and Setlist models.
///
/// **Storage:**
/// - `contentRTF` stores rich text as RTF Data (same pattern as Setlist.notesRTF)
/// - `title` is user-provided for easy identification
@Model
final class Note {

    // MARK: - Identity

    var id: UUID = UUID()

    /// User-provided title for the note
    var title: String = ""

    /// Rich text content stored as RTF Data (rendered via RichTextEditor)
    var contentRTF: Data = Data()

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // MARK: - Soft Delete

    /// When true, note is hidden from views but data is preserved
    var isDeleted: Bool = false

    /// Timestamp of deletion (nil if not deleted)
    var deletedAt: Date?

    // MARK: - Initialization

    init(title: String = "", contentRTF: Data = Data()) {
        self.id = UUID()
        self.title = title
        self.contentRTF = contentRTF
        let now = Date()
        self.createdAt = now
        self.updatedAt = now
    }
}

// MARK: - Display Properties

extension Note {

    /// Preferred display title: explicit title if set, otherwise "Untitled Note"
    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled Note" : trimmed
    }

    /// Plain text preview extracted from RTF content (first few lines for card display)
    var contentPreview: String {
        guard let attributed = NSAttributedString.fromRTF(contentRTF) else { return "" }
        let plainText = attributed.string.trimmingCharacters(in: .whitespacesAndNewlines)
        // Return first 150 characters for preview
        if plainText.count > 150 {
            return String(plainText.prefix(150)) + "\u{2026}"
        }
        return plainText
    }

    /// Whether the note has any content beyond whitespace
    var hasContent: Bool {
        guard let attributed = NSAttributedString.fromRTF(contentRTF) else { return false }
        return !attributed.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - Soft Delete Operations

extension Note {

    /// Soft delete the note (hides from views, preserves data)
    func softDelete() {
        isDeleted = true
        deletedAt = Date()
    }

    /// Restore a soft-deleted note
    func restore() {
        isDeleted = false
        deletedAt = nil
    }
}
