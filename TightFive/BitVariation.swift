import Foundation
import SwiftData
import SwiftUI

/// Tracks how a bit evolves across different setlists.
///
/// Each variation is a snapshot of the bit's content as performed in a specific setlist.
/// Variations are analytics records - they help comedians see how material evolved over time.
///
/// **Lifecycle:**
/// - Created when a comedian edits an assignment's content in a setlist
/// - Hard-deleted when the source Bit is soft-deleted (by design - analytics cleanup)
/// - Setlist assignments remain intact regardless of variation deletion
@Model
final class BitVariation {
    
    // MARK: - Identity
    
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var lastModifiedAt: Date = Date()
    
    // MARK: - Provenance (Where did this come from?)
    
    /// The setlist where this variation was created
    var setlistId: UUID = UUID()
    
    /// Snapshot of setlist title at creation time (preserved for display even if setlist renamed)
    var setlistTitle: String = ""
    
    /// Optional link to the specific assignment that created this variation
    var assignmentId: UUID?
    
    // MARK: - Content (What changed?)
    
    /// Rich text snapshot of the performed content
    var rtfData: Data = Data()
    
    // MARK: - Metadata (Why changed?)
    
    /// Optional note from the comedian ("tightened tag", "new opener", etc.)
    var note: String?
    
    // MARK: - Relationship
    
    /// The source bit this variation belongs to.
    /// Inverse relationship configured on Bit.variations
    var bit: Bit?
    
    // MARK: - Initialization
    
    init(
        setlistId: UUID,
        setlistTitle: String,
        rtfData: Data,
        assignmentId: UUID? = nil,
        note: String? = nil
    ) {
        self.id = UUID()
        let now = Date()
        self.createdAt = now
        self.lastModifiedAt = now
        self.setlistId = setlistId
        self.setlistTitle = setlistTitle
        self.rtfData = rtfData
        self.assignmentId = assignmentId
        self.note = note
    }
}

// MARK: - Computed Properties

extension BitVariation {
    
    /// Plain text extracted from RTF for comparison/search
    var plainText: String {
        NSAttributedString.fromRTF(rtfData)?.string ?? ""
    }
    
    /// Human-readable relative date ("2 days ago", "Last week")
    var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
    
    /// First line of content for display in lists
    var titleLine: String {
        let firstLine = plainText
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init) ?? ""
        return firstLine.isEmpty ? "Untitled Variation" : firstLine
    }
}
