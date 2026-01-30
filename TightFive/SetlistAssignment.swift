import Foundation
import SwiftData
import SwiftUI

/// A bit's appearance in a setlist, stored as an immutable snapshot.
///
/// **Core Principle:** `performedRTF` is the source of truth.
/// Setlists always render from this snapshot, never from the source Bit.
/// This ensures setlists remain intact even if the original bit is deleted.
@Model
final class SetlistAssignment {
    
    // MARK: - Identity & Ordering
    
    var id: UUID
    
    /// Legacy order field (kept for migration compatibility)
    var order: Int
    
    /// When this assignment was added to the setlist
    var addedAt: Date
    
    // MARK: - Content (THE SOURCE OF TRUTH)
    
    /// The actual performed content as rich text.
    /// This is the canonical version - setlist always renders from this.
    var performedRTF: Data
    
    // MARK: - Provenance (Optional - for analytics)
    
    /// Link to source bit (may be orphaned if bit deleted)
    var bitId: UUID?
    
    /// Snapshot of bit title at time of adding.
    var bitTitleSnapshot: String
    
    /// Link to variation record (if content was modified from original)
    var variationId: UUID?
    
    // MARK: - Relationship
    
    /// The setlist this assignment belongs to.
    var setlist: Setlist?
    
    // MARK: - Initialization
    
    init(
        order: Int,
        performedRTF: Data,
        bitId: UUID? = nil,
        bitTitleSnapshot: String
    ) {
        self.id = UUID()
        self.order = order
        self.performedRTF = performedRTF
        self.bitId = bitId
        self.bitTitleSnapshot = bitTitleSnapshot
        self.addedAt = Date()
    }
}

// MARK: - Computed Properties

extension SetlistAssignment {
    
    /// Plain text extracted from RTF for search/comparison
    var plainText: String {
        NSAttributedString.fromRTF(performedRTF)?.string ?? ""
    }
    
    /// Whether this assignment has been modified from the original bit content
    var isModified: Bool {
        variationId != nil
    }
    
    /// First line of content for compact display
    var titleLine: String {
        let firstLine = plainText
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init) ?? ""
        return firstLine.isEmpty ? bitTitleSnapshot : firstLine
    }
}

// MARK: - Bit Lookup

extension SetlistAssignment {
    
    /// Fetch the source bit if it exists and is not deleted.
    func sourceBit(in context: ModelContext) -> Bit? {
        guard let bitId else { return nil }
        
        let id = bitId
        let descriptor = FetchDescriptor<Bit>(
            predicate: #Predicate { $0.id == id }
        )
        
        guard let bit = try? context.fetch(descriptor).first else { return nil }
        return bit.isDeleted ? nil : bit
    }
    
    /// Check if linked to a live (non-deleted) bit
    func hasLiveBit(in context: ModelContext) -> Bool {
        sourceBit(in: context) != nil
    }
    
    /// Check if the original bit was deleted
    func isOrphaned(in context: ModelContext) -> Bool {
        guard bitId != nil else { return false }
        return sourceBit(in: context) == nil
    }
}
