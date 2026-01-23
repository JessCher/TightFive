import Foundation
import SwiftData

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
    
    /// First line of text for display in lists
    var titleLine: String {
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
}

// MARK: - Soft Delete Operations

extension Bit {
    
    /// Soft delete the bit and hard-delete all variations.
    ///
    /// **What happens:**
    /// - `isDeleted` set to true (hides from library)
    /// - `deletedAt` set to current timestamp
    /// - All variations are deleted from context (analytics cleanup)
    /// - Setlist assignments remain intact (they have their own RTF snapshots)
    ///
    /// - Parameter context: The ModelContext to delete variations from
    func softDelete(context: ModelContext) {
        isDeleted = true
        deletedAt = Date()
        
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
    func restore() {
        isDeleted = false
        deletedAt = nil
        // variations remain empty - they were hard-deleted
    }
}
