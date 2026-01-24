import Foundation

/// A block of content in a setlist performance script.
///
/// The performance script is composed of ordered blocks:
/// - Freeform text (transitions, tags, crowd work prompts)
/// - Inserted bits (modular, drag-droppable)
///
/// This enables the blended document architecture where comedians
/// write freely between inserted bits.
enum ScriptBlock: Codable, Identifiable, Equatable {
    case freeform(id: UUID, text: String)
    case bit(id: UUID, assignmentId: UUID)
    
    var id: UUID {
        switch self {
        case .freeform(let id, _): return id
        case .bit(let id, _): return id
        }
    }
    
    var isFreeform: Bool {
        if case .freeform = self { return true }
        return false
    }
    
    var isBit: Bool {
        if case .bit = self { return true }
        return false
    }
    
    var assignmentId: UUID? {
        if case .bit(_, let assignmentId) = self {
            return assignmentId
        }
        return nil
    }
    
    var freeformText: String? {
        if case .freeform(_, let text) = self {
            return text
        }
        return nil
    }
}

// MARK: - Factory Methods

extension ScriptBlock {
    
    static func newFreeform(text: String = "") -> ScriptBlock {
        .freeform(id: UUID(), text: text)
    }
    
    static func newBit(assignmentId: UUID) -> ScriptBlock {
        .bit(id: UUID(), assignmentId: assignmentId)
    }
}

// MARK: - Content Extraction

extension ScriptBlock {
    
    /// Extract plain text content from this block
    func plainText(using assignments: [SetlistAssignment]) -> String {
        switch self {
        case .freeform(_, let text):
            return text
        case .bit(_, let assignmentId):
            guard let assignment = assignments.first(where: { $0.id == assignmentId }) else {
                return ""
            }
            return assignment.plainText
        }
    }
}

// MARK: - Array Extensions

extension Array where Element == ScriptBlock {
    
    /// Get all plain text content concatenated with line breaks
    func fullPlainText(using assignments: [SetlistAssignment]) -> String {
        map { $0.plainText(using: assignments) }
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n\n")
    }
    
    /// Find index of block containing assignment
    func index(forAssignmentId id: UUID) -> Int? {
        firstIndex { $0.assignmentId == id }
    }
    
    /// Get all assignment IDs in order
    var assignmentIds: [UUID] {
        compactMap { $0.assignmentId }
    }
}
