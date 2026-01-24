import Foundation

/// An anchor phrase for voice-activated teleprompter navigation.
///
/// Anchors are linked to assignments (bit snapshots) in the setlist.
/// When the comedian speaks the anchor phrase, Stage Mode navigates
/// to the corresponding script block.
struct StageAnchor: Codable, Identifiable, Equatable, Hashable {
    
    var id: UUID
    var assignmentId: UUID
    var phrase: String
    var order: Int
    var isEnabled: Bool
    
    init(assignmentId: UUID, phrase: String, order: Int, isEnabled: Bool = true) {
        self.id = UUID()
        self.assignmentId = assignmentId
        self.phrase = phrase
        self.order = order
        self.isEnabled = isEnabled
    }
}

extension StageAnchor {
    
    var normalizedPhrase: String {
        phrase.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var shortPhrase: String {
        let words = phrase.split(separator: " ").prefix(5)
        let result = words.joined(separator: " ")
        return words.count < phrase.split(separator: " ").count ? result + "..." : result
    }
    
    var isValid: Bool {
        phrase.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3
    }
}

// MARK: - Setlist Extensions

extension Setlist {
    
    private var stageAnchorsKey: String {
        "StageAnchors_\(id.uuidString)"
    }
    
    var stageAnchors: [StageAnchor] {
        guard let data = UserDefaults.standard.data(forKey: stageAnchorsKey),
              let anchors = try? JSONDecoder().decode([StageAnchor].self, from: data) else {
            return []
        }
        return anchors
    }
    
    func saveAnchors(_ anchors: [StageAnchor]) {
        guard let data = try? JSONEncoder().encode(anchors) else { return }
        UserDefaults.standard.set(data, forKey: stageAnchorsKey)
    }
    
    func clearAnchors() {
        UserDefaults.standard.removeObject(forKey: stageAnchorsKey)
    }
    
    var hasConfiguredAnchors: Bool {
        let anchors = stageAnchors
        return !anchors.isEmpty && anchors.contains { $0.isEnabled && $0.isValid }
    }
    
    var isStageReady: Bool {
        !isDraft && hasScriptContent && hasConfiguredAnchors
    }
    
    /// Generate default anchors from bit blocks in the script.
    func generateDefaultAnchors() -> [StageAnchor] {
        var anchors: [StageAnchor] = []
        var order = 0
        
        for block in scriptBlocks {
            if let assignmentId = block.assignmentId,
               let assignment = assignments.first(where: { $0.id == assignmentId }) {
                let firstLine = extractFirstLine(from: assignment.plainText)
                let anchor = StageAnchor(
                    assignmentId: assignmentId,
                    phrase: firstLine,
                    order: order
                )
                anchors.append(anchor)
                order += 1
            }
        }
        
        return anchors
    }
    
    private func extractFirstLine(from text: String) -> String {
        for line in text.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                let words = trimmed.split(separator: " ").prefix(10)
                return words.joined(separator: " ")
            }
        }
        return "Bit \(assignments.count)"
    }
    
    func anchor(for assignment: SetlistAssignment) -> StageAnchor? {
        stageAnchors.first { $0.assignmentId == assignment.id }
    }
    
    func updateAnchor(_ anchor: StageAnchor) {
        var anchors = stageAnchors
        if let index = anchors.firstIndex(where: { $0.id == anchor.id }) {
            anchors[index] = anchor
            saveAnchors(anchors)
        }
    }
}

// MARK: - Array Extensions

extension Array where Element == StageAnchor {
    
    /// Find anchor matching spoken text with fuzzy matching.
    func findMatch(for spokenText: String, threshold: Double = 0.5) -> (anchor: StageAnchor, confidence: Double)? {
        let normalizedSpoken = spokenText.lowercased()
        var bestMatch: (StageAnchor, Double)?
        
        for anchor in self where anchor.isEnabled && anchor.isValid {
            let normalizedAnchor = anchor.normalizedPhrase
            
            // Exact substring match
            if normalizedSpoken.contains(normalizedAnchor) {
                return (anchor, 1.0)
            }
            
            // Word overlap matching
            let anchorWords = Set(normalizedAnchor.split(separator: " ").map(String.init))
            let spokenWords = Set(normalizedSpoken.split(separator: " ").map(String.init))
            let matchingWords = anchorWords.intersection(spokenWords)
            
            guard !anchorWords.isEmpty else { continue }
            let confidence = Double(matchingWords.count) / Double(anchorWords.count)
            
            if confidence >= threshold {
                if bestMatch == nil || confidence > bestMatch!.1 {
                    bestMatch = (anchor, confidence)
                }
            }
        }
        
        return bestMatch
    }
    
    var sortedByOrder: [StageAnchor] {
        sorted { $0.order < $1.order }
    }
}
