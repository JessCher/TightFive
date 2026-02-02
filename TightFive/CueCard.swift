import Foundation
import SwiftUI

/// A single cue card representing one script block in Stage Mode.
///
/// Each card has:
/// - Full content text (displayed on screen)
/// - Anchor phrase (first ~10-20 words) - confirms we're IN this block
/// - Exit phrase (last ~10-20 words) - triggers transition to NEXT block
struct CueCard: Identifiable, Equatable {
    let id: UUID
    let blockId: UUID
    let blockIndex: Int
    let fullText: String
    
    /// First ~10-20 words of the block - what performer sees/says when card appears
    let anchorPhrase: String
    
    /// Last ~10-20 words of the block - triggers transition to next card
    let exitPhrase: String
    
    /// Normalized words for matching (full text)
    let normalizedWords: [String]
    
    /// Normalized anchor phrase words
    let normalizedAnchor: [String]
    
    /// Normalized exit phrase words
    let normalizedExit: [String]
    
    var isEmpty: Bool {
        fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - Factory

extension CueCard {
    /// Extract cue cards from setlist script blocks
    static func extractCards(from setlist: Setlist) -> [CueCard] {
        var cards: [CueCard] = []
        
        for (blockIndex, block) in setlist.scriptBlocks.enumerated() {
            let text = block.plainText(using: setlist.assignments)
                .replacingOccurrences(of: "\r\n", with: "\n")
                .replacingOccurrences(of: "\r", with: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard !text.isEmpty else { continue }
            
            let (anchor, exit) = extractPhrases(from: text)
            
            cards.append(CueCard(
                id: UUID(),
                blockId: block.id,
                blockIndex: blockIndex,
                fullText: text,
                anchorPhrase: anchor,
                exitPhrase: exit,
                normalizedWords: normalizeWords(text),
                normalizedAnchor: normalizeWords(anchor),
                normalizedExit: normalizeWords(exit)
            ))
        }
        
        return cards
    }
    
    /// Extract anchor (first ~10-20 words) and exit (last ~10-20 words) phrases
    private static func extractPhrases(from text: String) -> (anchor: String, exit: String) {
        let words = text.split(whereSeparator: \.isWhitespace).map(String.init)
        
        let targetWords = 15 // Aim for ~15 words per phrase
        
        // Anchor: first 10-20 words (or all if text is short)
        let anchorWords = Array(words.prefix(min(targetWords, words.count)))
        let anchor = anchorWords.joined(separator: " ")
        
        // Exit: last 10-20 words (or all if text is short)
        let exitWords = Array(words.suffix(min(targetWords, words.count)))
        let exit = exitWords.joined(separator: " ")
        
        return (anchor, exit)
    }
    
    /// Normalize text for speech recognition matching
    private static func normalizeWords(_ text: String) -> [String] {
        let folded = text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
        
        var scalars: [UnicodeScalar] = []
        scalars.reserveCapacity(folded.unicodeScalars.count)
        
        for s in folded.unicodeScalars {
            if CharacterSet.alphanumerics.contains(s) {
                scalars.append(s)
            } else if CharacterSet.whitespacesAndNewlines.contains(s) {
                scalars.append(UnicodeScalar(32))
            } else {
                scalars.append(UnicodeScalar(32))
            }
        }
        
        let cleaned = String(String.UnicodeScalarView(scalars))
        return cleaned.split(whereSeparator: \.isWhitespace).map(String.init)
    }
}

// MARK: - Recognition Helpers

extension CueCard {
    /// Check if transcript matches the exit phrase (triggers next card)
    func matchesExitPhrase(_ transcript: String) -> (matches: Bool, confidence: Double) {
        guard !normalizedExit.isEmpty else { return (false, 0.0) }
        
        let transcriptWords = CueCard.normalizeWords(transcript)
        let confidence = fuzzyMatch(transcriptWords: transcriptWords, targetWords: normalizedExit)
        
        let threshold = CueCardSettingsStore.shared.exitPhraseSensitivity
        return (confidence >= threshold, confidence)
    }
    
    /// Check if transcript matches the anchor phrase (confirms we're in this card)
    func matchesAnchorPhrase(_ transcript: String) -> (matches: Bool, confidence: Double) {
        guard !normalizedAnchor.isEmpty else { return (false, 0.0) }
        
        let transcriptWords = CueCard.normalizeWords(transcript)
        let confidence = fuzzyMatch(transcriptWords: transcriptWords, targetWords: normalizedAnchor)
        
        let threshold = CueCardSettingsStore.shared.anchorPhraseSensitivity
        return (confidence >= threshold, confidence)
    }
    
    /// Fuzzy matching using sliding window approach
    private func fuzzyMatch(transcriptWords: [String], targetWords: [String]) -> Double {
        guard !transcriptWords.isEmpty, !targetWords.isEmpty else { return 0.0 }
        
        let windowSize = targetWords.count
        var bestScore = 0.0
        
        // Try all possible windows in the transcript
        for start in 0...(transcriptWords.count - min(windowSize, transcriptWords.count)) {
            let end = min(start + windowSize, transcriptWords.count)
            let window = Array(transcriptWords[start..<end])
            
            // Calculate match score for this window
            let score = matchScore(window: window, target: targetWords)
            bestScore = max(bestScore, score)
        }
        
        return bestScore
    }
    
    /// Calculate match score between window and target
    private func matchScore(window: [String], target: [String]) -> Double {
        let matchLength = min(window.count, target.count)
        guard matchLength > 0 else { return 0.0 }
        
        var matches = 0
        for i in 0..<matchLength {
            if window[i] == target[i] {
                matches += 1
            }
        }
        
        return Double(matches) / Double(target.count)
    }
}
