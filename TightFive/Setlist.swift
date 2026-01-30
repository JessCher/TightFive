import Foundation
import SwiftData
import SwiftUI

/// A comedy setlist - a performance script with modular bit insertion.
///
/// **New Architecture:**
/// - `scriptBlocks`: The Performance Script as ordered content blocks (freeform text + inserted bits)
/// - `notesRTF`: Auxiliary notes (delivery ideas, reminders - NOT shown in Stage/Run modes)
/// - `assignments`: Bit snapshots referenced by script blocks
///
/// **Source of Truth:**
/// - Stage Mode and Run Through mode both read from `scriptBlocks`
/// - Notes tab is strictly auxiliary and excluded from performance views
@Model
final class Setlist {
    
    // MARK: - Identity
    
    var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    
    // MARK: - Performance Script
    
    /// JSON-encoded array of ScriptBlock for the performance script.
    /// This is the blended document shown in Stage Mode and Run Through.
    /// Default empty array for migration compatibility.
    var scriptBlocksData: Data = Data()
    
    // MARK: - Auxiliary Notes
    
    /// Free-form notes for delivery ideas, reminders, meta thoughts.
    /// NOT shown in Stage Mode or Run Through mode.
    @Attribute(originalName: "bodyRTF")
    var notesRTF: Data
    
    // MARK: - Status
    
    /// True = still being developed, False = ready for stage
    var isDraft: Bool
    
    // MARK: - Soft Delete
    
    /// When true, setlist is hidden from main views but recoverable from Trashcan
    var isDeleted: Bool = false
    
    /// Timestamp of deletion (nil if not deleted)
    var deletedAt: Date?
    
    // MARK: - Relationships
    
    /// Bit snapshots referenced by ScriptBlock.bit entries.
    @Relationship(deleteRule: .cascade, inverse: \SetlistAssignment.setlist)
    var assignments: [SetlistAssignment] = []
    
    // MARK: - Initialization
    
    init(title: String = "Untitled Set", notesRTF: Data = Data(), isDraft: Bool = true) {
        self.id = UUID()
        self.title = title
        let now = Date()
        self.createdAt = now
        self.updatedAt = now
        self.scriptBlocksData = Self.encodeBlocks([])
        self.notesRTF = notesRTF
        self.isDraft = isDraft
    }
}

// MARK: - Script Block Access

extension Setlist {
    
    /// Decoded script blocks
    var scriptBlocks: [ScriptBlock] {
        get {
            Self.decodeBlocks(scriptBlocksData) ?? []
        }
        set {
            scriptBlocksData = Self.encodeBlocks(newValue)
        }
    }
    
    private static func encodeBlocks(_ blocks: [ScriptBlock]) -> Data {
        (try? JSONEncoder().encode(blocks)) ?? Data()
    }
    
    private static func decodeBlocks(_ data: Data) -> [ScriptBlock]? {
        guard !data.isEmpty else { return [] }
        return try? JSONDecoder().decode([ScriptBlock].self, from: data)
    }
}

// MARK: - Script Content

extension Setlist {
    
    /// Full plain text of the performance script (for search, display)
    var scriptPlainText: String {
        scriptBlocks.fullPlainText(using: assignments)
    }
    
    /// Check if script has any content
    var hasScriptContent: Bool {
        !scriptBlocks.isEmpty && !scriptPlainText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// Get all bit assignment IDs in script order
    var orderedAssignmentIds: [UUID] {
        scriptBlocks.compactMap { $0.assignmentId }
    }
}

// MARK: - Computed Properties

extension Setlist {
    
    /// Assignments in the order they appear in the script
    var orderedAssignments: [SetlistAssignment] {
        orderedAssignmentIds.compactMap { id in
            assignments.first { $0.id == id }
        }
    }
    
    /// Total number of bits in this setlist
    var bitCount: Int {
        scriptBlocks.filter { $0.isBit }.count
    }
    
    /// Total number of blocks (bits + freeform)
    var blockCount: Int {
        scriptBlocks.count
    }
    
    /// Plain text from notes for search (auxiliary notes only)
    var notesPlainText: String {
        NSAttributedString.fromRTF(notesRTF)?.string ?? ""
    }
    
    /// Check if notes have content
    var hasNotes: Bool {
        !notesPlainText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// Estimated duration in seconds based on word count.
    /// Uses a speaking rate of ~150 words per minute (standard comedy pace).
    var estimatedDuration: TimeInterval {
        let text = scriptPlainText
        let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let wordCount = words.count
        
        // 150 words per minute = 2.5 words per second
        let seconds = Double(wordCount) / 2.5
        
        // Round to nearest 15 seconds for cleaner display
        return (seconds / 15.0).rounded() * 15.0
    }
    
    /// Formatted duration string (e.g., "5m 30s" or "12m")
    var formattedDuration: String {
        let totalSeconds = Int(estimatedDuration)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        
        if seconds == 0 {
            return "\(minutes)m"
        } else {
            return "\(minutes)m \(seconds)s"
        }
    }
}

// MARK: - Migration Support

extension Setlist {
    
    /// Migrate from old assignment-only model to new script blocks model.
    func migrateToScriptBlocksIfNeeded() {
        guard scriptBlocks.isEmpty, !assignments.isEmpty else { return }
        
        let sorted = assignments.sorted { $0.order < $1.order }
        var blocks: [ScriptBlock] = []
        for assignment in sorted {
            blocks.append(.newBit(assignmentId: assignment.id))
        }
        
        scriptBlocks = blocks
        updatedAt = Date()
    }
}
// MARK: - Soft Delete Operations

extension Setlist {
    
    /// Soft delete the setlist.
    ///
    /// **What happens:**
    /// - `isDeleted` set to true (hides from main views)
    /// - `deletedAt` set to current timestamp
    /// - Setlist becomes recoverable from Trashcan
    /// - All assignments and script content remain intact
    func softDelete() {
        isDeleted = true
        deletedAt = Date()
    }
    
    /// Restore a soft-deleted setlist.
    func restore() {
        isDeleted = false
        deletedAt = nil
    }
    
    /// Hard delete: completely remove setlist and all related data.
    /// This also deletes all assignments (cascade delete configured on relationship).
    func hardDelete(context: ModelContext) {
        // Assignments will be deleted automatically via cascade rule
        context.delete(self)
    }
}

