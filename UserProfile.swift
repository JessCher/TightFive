import Foundation
import SwiftData

/// User profile information
@Model
final class UserProfile {
    var id: UUID
    var name: String
    var profileImageData: Data?
    var showsPerformed: Int
    var updatedAt: Date
    
    init(name: String = "", showsPerformed: Int = 0) {
        self.id = UUID()
        self.name = name
        self.showsPerformed = showsPerformed
        self.updatedAt = Date()
    }
}

extension UserProfile {
    /// Get or create the singleton user profile
    static func getOrCreate(from context: ModelContext) -> UserProfile {
        let descriptor = FetchDescriptor<UserProfile>()
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        
        // Create new profile if none exists
        let newProfile = UserProfile()
        context.insert(newProfile)
        try? context.save()
        return newProfile
    }
}
