import Foundation
import SwiftData

enum BitStatus: String, Codable, CaseIterable {
    case loose
    case finished
}

@Model
final class Bit {
    var id: UUID
    var text: String
    var createdAt: Date
    var updatedAt: Date
    var statusRaw: String

    init(text: String, status: BitStatus = .loose) {
        self.id = UUID()
        self.text = text
        let now = Date()
        self.createdAt = now
        self.updatedAt = now
        self.statusRaw = status.rawValue
    }

    var status: BitStatus {
        get { BitStatus(rawValue: statusRaw) ?? .loose }
        set { statusRaw = newValue.rawValue }
    }

    var titleLine: String {
        let first = text
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init) ?? ""
        return first.isEmpty ? "Untitled Bit" : first
    }
}
