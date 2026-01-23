import Foundation
import SwiftData

/// A comedy setlist - an ordered collection of bits for performance.
///
/// **Architecture:**
/// - `notesRTF`: Free-form notes/structure for the setlist (renamed from bodyRTF)
/// - `assignments`: Ordered collection of bit snapshots (the actual set content)
///
/// **Key Principle:** Setlists render from `SetlistAssignment.performedRTF`,
/// never from the source Bit. This ensures setlists remain intact even if bits are deleted.
@Model
final class Setlist {
    
    // MARK: - Identity
    
    var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    
    // MARK: - Content
    
    /// Free-form notes and structure for the setlist.
    /// Migration-safe rename from `bodyRTF` using originalName attribute.
    @Attribute(originalName: "bodyRTF")
    var notesRTF: Data
    
    // MARK: - Status
    
    /// True = still being developed, False = ready for stage
    var isDraft: Bool
    
    // MARK: - Relationships
    
    /// Ordered collection of bit assignments.
    /// Each assignment stores its own RTF snapshot - setlist renders independently.
    @Relationship(deleteRule: .cascade, inverse: \SetlistAssignment.setlist)
    var assignments: [SetlistAssignment] = []
    
    // MARK: - Initialization
    
    init(title: String = "Untitled Set", notesRTF: Data = Data(), isDraft: Bool = true) {
        self.id = UUID()
        self.title = title
        let now = Date()
        self.createdAt = now
        self.updatedAt = now
        self.notesRTF = notesRTF
        self.isDraft = isDraft
    }
}

// MARK: - Computed Properties

extension Setlist {
    
    /// Assignments sorted by order (0-indexed position)
    var orderedAssignments: [SetlistAssignment] {
        assignments.sorted { $0.order < $1.order }
    }
    
    /// Total number of bits in this setlist
    var bitCount: Int {
        assignments.count
    }
    
    /// Next available order index for appending
    var nextOrder: Int {
        (assignments.map(\.order).max() ?? -1) + 1
    }
    
    /// Plain text from notes for search
    var notesPlainText: String {
        NSAttributedString.fromRTF(notesRTF)?.string ?? ""
    }
}
