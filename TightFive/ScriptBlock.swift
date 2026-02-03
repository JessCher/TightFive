import Foundation
import UIKit
import SwiftUI

/// A block of content in a setlist performance script.
///
/// The performance script is composed of ordered blocks:
/// - Freeform rich-text (transitions, tags, crowd work prompts)
/// - Inserted bits (modular, drag-droppable)
///
/// This enables the blended document architecture where comedians
/// write freely between inserted bits.
enum ScriptBlock: Identifiable, Equatable, Codable {
    case freeform(id: UUID, rtfData: Data)
    case bit(id: UUID, assignmentId: UUID)

    // MARK: - Identity
    var id: UUID {
        switch self {
        case .freeform(let id, _): return id
        case .bit(let id, _): return id
        }
    }

    // MARK: - Convenience
    var isFreeform: Bool {
        if case .freeform = self { return true }
        return false
    }

    var isBit: Bool {
        if case .bit = self { return true }
        return false
    }

    var assignmentId: UUID? {
        if case .bit(_, let assignmentId) = self { return assignmentId }
        return nil
    }

    var freeformRTF: Data? {
        if case .freeform(_, let data) = self { return data }
        return nil
    }

    var freeformPlainText: String? {
        guard case .freeform(_, let data) = self else { return nil }
        return NSAttributedString.fromRTF(data)?.string ?? ""
    }
}

// MARK: - Factory Methods

extension ScriptBlock {
    static func newFreeform(rtfData: Data = TFRTFTheme.body("")) -> ScriptBlock {
        .freeform(id: UUID(), rtfData: rtfData)
    }

    /// Backwards-compat convenience for older callsites.
    static func newFreeform(text: String) -> ScriptBlock {
        .freeform(id: UUID(), rtfData: TFRTFTheme.body(text))
    }

    static func newBit(assignmentId: UUID) -> ScriptBlock {
        .bit(id: UUID(), assignmentId: assignmentId)
    }
}

// MARK: - Content Extraction

extension ScriptBlock {
    /// Extract plain text content from this block
    func plainText(using assignments: [SetlistAssignment]?) -> String {
        switch self {
        case .freeform(_, let rtfData):
            return NSAttributedString.fromRTF(rtfData)?.string ?? ""
        case .bit(_, let assignmentId):
            guard let assignment = assignments?.first(where: { $0.id == assignmentId }) else { return "" }
            return assignment.plainText
        }
    }
}

// MARK: - Codable (Backwards Compatible)

extension ScriptBlock {
    private enum CodingKeys: String, CodingKey {
        case kind
        case id
        case assignmentId
        case rtfData
        // legacy
        case text
    }

    private enum Kind: String, Codable {
        case freeform
        case bit
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)

        switch kind {
        case .freeform:
            let id = try container.decode(UUID.self, forKey: .id)
            if let data = try container.decodeIfPresent(Data.self, forKey: .rtfData) {
                self = .freeform(id: id, rtfData: data)
            } else if let legacyText = try container.decodeIfPresent(String.self, forKey: .text) {
                // Migrate legacy plain text → themed RTF.
                self = .freeform(id: id, rtfData: TFRTFTheme.body(legacyText))
            } else {
                self = .freeform(id: id, rtfData: TFRTFTheme.body(""))
            }

        case .bit:
            let id = try container.decode(UUID.self, forKey: .id)
            let assignmentId = try container.decode(UUID.self, forKey: .assignmentId)
            self = .bit(id: id, assignmentId: assignmentId)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .freeform(let id, let rtfData):
            try container.encode(Kind.freeform, forKey: .kind)
            try container.encode(id, forKey: .id)
            try container.encode(rtfData, forKey: .rtfData)
        case .bit(let id, let assignmentId):
            try container.encode(Kind.bit, forKey: .kind)
            try container.encode(id, forKey: .id)
            try container.encode(assignmentId, forKey: .assignmentId)
        }
    }
}

// MARK: - Array Extensions

extension Array where Element == ScriptBlock {
    /// Get all plain text content concatenated with line breaks
    func fullPlainText(using assignments: [SetlistAssignment]?) -> String {
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
