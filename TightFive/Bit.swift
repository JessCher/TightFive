import Foundation
import SwiftData
import SwiftUI

enum BitStatus: String, Codable, CaseIterable {
    case loose
    case finished
}

/// A comedy bit - the atomic unit of material in TightFive.
///
/// Bits are stored as plain text for fast search. When added to setlists,
/// they're converted to themed RTF and stored as snapshots in SetlistAssignment.
///
/// **Soft Delete Behavior:**
/// - `isDeleted = true` hides from library views
/// - All variations are hard-deleted (analytics cleanup)
/// - Setlist assignments remain intact (history preserved)
/// - Can be restored if needed (variations are gone by design)
@Model
final class Bit {
    
    // MARK: - Identity
    
    var id: UUID
    
    /// Plain text content - the master copy
    var text: String
    
    /// Optional user-provided title for easier identification
    var title: String = ""
    
    /// Free-form tags for quick filtering/search
    var tags: [String] = []
    
    var createdAt: Date
    var updatedAt: Date
    
    // MARK: - Status
    
    /// Raw storage for BitStatus enum (SwiftData compatible)
    var statusRaw: String
    
    // MARK: - Soft Delete
    
    /// When true, bit is hidden from library but setlist assignments remain
    var isDeleted: Bool = false
    
    /// Timestamp of deletion (nil if not deleted)
    var deletedAt: Date?
    
    // MARK: - Favorites
    
    /// Whether this bit is marked as a favorite
    var isFavorite: Bool = false
    
    // MARK: - Relationships
    
    /// All variations of this bit across setlists.
    /// These are hard-deleted when the bit is soft-deleted.
    @Relationship(inverse: \BitVariation.bit)
    var variations: [BitVariation] = []
    
    // MARK: - Initialization
    
    init(text: String, status: BitStatus = .loose) {
        self.id = UUID()
        self.text = text
        let now = Date()
        self.createdAt = now
        self.updatedAt = now
        self.statusRaw = status.rawValue
        self.title = ""
        self.tags = []
    }
}

// MARK: - Status Accessor

extension Bit {
    
    var status: BitStatus {
        get { BitStatus(rawValue: statusRaw) ?? .loose }
        set { statusRaw = newValue.rawValue }
    }
}

// MARK: - Display Properties

extension Bit {
    
    /// Preferred display title: explicit `title` if set; otherwise first line of text
    var titleLine: String {
        let explicit = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !explicit.isEmpty { return explicit }
        let first = text
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init) ?? ""
        return first.isEmpty ? "Untitled Bit" : first
    }
    
    /// Number of variations across all setlists
    var variationCount: Int {
        variations.count
    }
    
    /// Estimated duration in seconds based on word count.
    /// Uses a speaking rate of ~150 words per minute (standard comedy pace).
    var estimatedDuration: TimeInterval {
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

// MARK: - Soft Delete Operations

extension Bit {
    
    /// Soft delete the bit and hard-delete all variations.
    ///
    /// **What happens:**
    /// - `isDeleted` set to true (hides from library)
    /// - `deletedAt` set to current timestamp
    /// - All ScriptBlocks referencing this bit are converted to freeform text (preserves script content)
    /// - Setlist assignments are deleted (no longer needed after conversion)
    /// - All variations are deleted from context (analytics cleanup)
    ///
    /// - Parameter context: The ModelContext to delete variations from
    func softDelete(context: ModelContext) {
        isDeleted = true
        deletedAt = Date()
        
        // Fetch all setlists that contain this bit
        let bitId = self.id
        let descriptor = FetchDescriptor<Setlist>()
        
        if let allSetlists = try? context.fetch(descriptor) {
            for setlist in allSetlists {
                // Find all assignments for this bit in the setlist
                let assignmentsToConvert = setlist.assignments.filter { $0.bitId == bitId }
                
                // Convert each bit block to freeform block
                for assignment in assignmentsToConvert {
                    // Find the corresponding ScriptBlock
                    if let blockIndex = setlist.scriptBlocks.firstIndex(where: { 
                        $0.assignmentId == assignment.id 
                    }) {
                        // Convert bit block to freeform block, preserving the RTF content
                        var blocks = setlist.scriptBlocks
                        let blockId = blocks[blockIndex].id
                        blocks[blockIndex] = .freeform(id: blockId, rtfData: assignment.performedRTF)
                        setlist.scriptBlocks = blocks
                        setlist.updatedAt = Date()
                    }
                    
                    // Remove the assignment from the setlist
                    setlist.assignments.removeAll { $0.id == assignment.id }
                    
                    // Delete the assignment from context
                    context.delete(assignment)
                }
            }
        }
        
        // Hard-delete all variations (analytics cleanup)
        for variation in variations {
            context.delete(variation)
        }
        variations.removeAll()
    }
    
    /// Restore a soft-deleted bit.
    ///
    /// **Note:** Variations are permanently lost - this is by design.
    /// The bit returns to the library but its evolution history is cleared.
    /// Converted script blocks remain as freeform text and are not reconnected.
    func restore() {
        isDeleted = false
        deletedAt = nil
        // variations remain empty - they were hard-deleted
        // converted script blocks remain freeform - they are not reconnected
    }
}
