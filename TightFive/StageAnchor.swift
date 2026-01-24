import Foundation

/// An anchor phrase for voice-activated teleprompter navigation.
///
/// Anchors can reference any script block - either a bit assignment or a freeform text block.
/// When the comedian speaks the anchor phrase, Stage Mode navigates to the corresponding block.
struct StageAnchor: Codable, Identifiable, Equatable, Hashable {
    
    /// Reference to the script block this anchor navigates to
    enum BlockReference: Codable, Equatable, Hashable {
        case bit(assignmentId: UUID)
        case freeform(blockId: UUID)
        
        var id: UUID {
            switch self {
            case .bit(let assignmentId): return assignmentId
            case .freeform(let blockId): return blockId
            }
        }
    }
    
    var id: UUID
    var blockReference: BlockReference
    var phrase: String
    var order: Int
    var isEnabled: Bool
    
    init(blockReference: BlockReference, phrase: String, order: Int, isEnabled: Bool = true) {
        self.id = UUID()
        self.blockReference = blockReference
        self.phrase = phrase
        self.order = order
        self.isEnabled = isEnabled
    }
    
    // MARK: - Legacy Support
    
    /// Legacy initializer for migration from assignmentId-only system
    @available(*, deprecated, message: "Use init(blockReference:phrase:order:isEnabled:) instead")
    init(assignmentId: UUID, phrase: String, order: Int, isEnabled: Bool = true) {
        self.init(blockReference: .bit(assignmentId: assignmentId), phrase: phrase, order: order, isEnabled: isEnabled)
    }
    
    /// Legacy accessor for backward compatibility
    var assignmentId: UUID? {
        if case .bit(let id) = blockReference {
            return id
        }
        return nil
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
    
    var isBitAnchor: Bool {
        if case .bit = blockReference { return true }
        return false
    }
    
    var isFreeformAnchor: Bool {
        if case .freeform = blockReference { return true }
        return false
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
    
    /// Generate default anchors from ALL blocks in the script (bits AND freeform).
    func generateDefaultAnchors() -> [StageAnchor] {
        var anchors: [StageAnchor] = []
        var order = 0
        
        for block in scriptBlocks {
            switch block {
            case .bit(_, let assignmentId):
                // Bit block - use bit title and assignment reference
                if let assignment = assignments.first(where: { $0.id == assignmentId }) {
                    let firstLine = extractFirstLine(from: assignment.plainText)
                    let anchor = StageAnchor(
                        blockReference: .bit(assignmentId: assignmentId),
                        phrase: firstLine,
                        order: order
                    )
                    anchors.append(anchor)
                    order += 1
                }
                
            case .freeform(let blockId, let rtfData):
                // Freeform block - extract first line from RTF content
                let plainText = NSAttributedString.fromRTF(rtfData)?.string ?? ""
                let trimmed = plainText.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Only create anchor if freeform has meaningful content
                if !trimmed.isEmpty {
                    let firstLine = extractFirstLine(from: plainText)
                    let anchor = StageAnchor(
                        blockReference: .freeform(blockId: blockId),
                        phrase: firstLine,
                        order: order
                    )
                    anchors.append(anchor)
                    order += 1
                }
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
        return "Block \(scriptBlocks.count)"
    }
    
    func anchor(for block: ScriptBlock) -> StageAnchor? {
        switch block {
        case .bit(_, let assignmentId):
            return stageAnchors.first {
                if case .bit(let anchorAssignmentId) = $0.blockReference {
                    return anchorAssignmentId == assignmentId
                }
                return false
            }
        case .freeform(let blockId, _):
            return stageAnchors.first {
                if case .freeform(let anchorBlockId) = $0.blockReference {
                    return anchorBlockId == blockId
                }
                return false
            }
        }
    }
    
    func updateAnchor(_ anchor: StageAnchor) {
        var anchors = stageAnchors
        if let index = anchors.firstIndex(where: { $0.id == anchor.id }) {
            anchors[index] = anchor
            saveAnchors(anchors)
        }
    }
    
    /// Find the script block index for a given anchor
    func blockIndex(for anchor: StageAnchor) -> Int? {
        switch anchor.blockReference {
        case .bit(let assignmentId):
            return scriptBlocks.firstIndex { block in
                if case .bit(_, let blockAssignmentId) = block {
                    return blockAssignmentId == assignmentId
                }
                return false
            }
        case .freeform(let blockId):
            return scriptBlocks.firstIndex { block in
                block.id == blockId
            }
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
