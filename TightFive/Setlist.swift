import Foundation
import SwiftData

@Model
final class Setlist {
    var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date

    /// Rich text stored as RTF data (like Notes exports).
    var bodyRTF: Data

    /// True = still being developed
    var isDraft: Bool

    init(title: String = "Untitled Set", bodyRTF: Data = Data(), isDraft: Bool = true) {
        self.id = UUID()
        self.title = title
        let now = Date()
        self.createdAt = now
        self.updatedAt = now
        self.bodyRTF = bodyRTF
        self.isDraft = isDraft
    }
}

