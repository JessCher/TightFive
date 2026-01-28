import Foundation

/// Converts partial speech transcript into a stable "current line index".
///
/// Fixes vs previous version:
/// - Uses ONLY the last N transcript words (tail) to match current speech.
/// - Scores based on matching the FIRST few words of each line (what you say when you start that line).
/// - Instant acceptance for high-confidence matches (world-class real-time feel).
/// - Reduced confirmation window for medium-confidence matches.
/// - Designed for short line chunks (6-10 words) built by StageModeView.
struct TeleprompterScrollTracker {

    // MARK: - Tuning Profiles (uncomment to switch)
    
    // Default: Balanced real-time performance
    private static let profile = TuningProfile.balanced
    
    // Uncomment for more aggressive instant scrolling:
    // private static let profile = TuningProfile.aggressive
    
    // Uncomment for more conservative (less false positives):
    // private static let profile = TuningProfile.conservative
    
    struct TuningProfile {
        let windowForward: Int
        let confirmWindow: TimeInterval
        let transcriptTailWords: Int
        let requiredPrefixMatches: Int
        let linePrefixCap: Int
        let minScore: Double
        let instantAcceptScore: Double
        
        static let balanced = TuningProfile(
            windowForward: 12,
            confirmWindow: 0.08,
            transcriptTailWords: 18,
            requiredPrefixMatches: 2,
            linePrefixCap: 6,
            minScore: 0.32,
            instantAcceptScore: 0.75
        )
        
        static let aggressive = TuningProfile(
            windowForward: 15,
            confirmWindow: 0.05,
            transcriptTailWords: 16,
            requiredPrefixMatches: 1,
            linePrefixCap: 5,
            minScore: 0.28,
            instantAcceptScore: 0.68
        )
        
        static let conservative = TuningProfile(
            windowForward: 10,
            confirmWindow: 0.12,
            transcriptTailWords: 20,
            requiredPrefixMatches: 3,
            linePrefixCap: 7,
            minScore: 0.40,
            instantAcceptScore: 0.80
        )
    }

    struct Line: Identifiable, Hashable {
        let id: UUID
        let text: String
        let normalizedWords: [String]
        let blockId: UUID?
        let blockIndex: Int
    }

    private(set) var lines: [Line] = []
    private(set) var currentIndex: Int = 0
    private(set) var currentConfidence: Double = 0  // Expose confidence for UI feedback

    private var pendingIndex: Int?
    private var pendingFirstSeen: Date?
    private var pendingScore: Double = 0

    // Tunables (use profile for easy switching)
    private let windowForward: Int
    private let confirmWindow: TimeInterval
    private let transcriptTailWords: Int
    private let requiredPrefixMatches: Int
    private let linePrefixCap: Int
    private let minScore: Double
    private let instantAcceptScore: Double

    init(lines: [Line]) {
        self.lines = lines
        self.currentIndex = 0
        
        // Apply selected profile
        let p = Self.profile
        self.windowForward = p.windowForward
        self.confirmWindow = p.confirmWindow
        self.transcriptTailWords = p.transcriptTailWords
        self.requiredPrefixMatches = p.requiredPrefixMatches
        self.linePrefixCap = p.linePrefixCap
        self.minScore = p.minScore
        self.instantAcceptScore = p.instantAcceptScore
    }

    mutating func reset(to index: Int = 0) {
        currentIndex = max(0, min(index, max(lines.count - 1, 0)))
        currentConfidence = 0
        pendingIndex = nil
        pendingFirstSeen = nil
        pendingScore = 0
    }

    mutating func jumpToBlock(blockId: UUID) {
        guard let idx = lines.firstIndex(where: { $0.blockId == blockId }) else { return }
        reset(to: idx)
    }

    mutating func ingestTranscript(_ transcript: String, now: Date = Date()) -> Int? {
        guard !lines.isEmpty else { return nil }

        let normalized = Self.normalize(transcript)
        var transcriptWords = normalized.split(separator: " ").map(String.init)
        guard !transcriptWords.isEmpty else { 
            // Empty transcript = not speaking, decay confidence
            currentConfidence = max(0, currentConfidence * 0.75)
            return nil 
        }

        // Only look at the tail
        if transcriptWords.count > transcriptTailWords {
            transcriptWords = Array(transcriptWords.suffix(transcriptTailWords))
        }

        let start = currentIndex
        let end = min(lines.count - 1, currentIndex + windowForward)

        var bestIndex: Int?
        var bestScore: Double = 0

        for idx in start...end {
            let lineWords = lines[idx].normalizedWords
            if lineWords.isEmpty { continue }

            let score = Self.score(lineWords: lineWords, transcriptWords: transcriptWords,
                                   requiredPrefixMatches: requiredPrefixMatches,
                                   linePrefixCap: linePrefixCap)

            if score > bestScore {
                bestScore = score
                bestIndex = idx
            }
        }

        guard let candidate = bestIndex, bestScore >= minScore else {
            // No match: decay confidence gradually (paused or off-script)
            currentConfidence = max(0, currentConfidence * 0.85)
            
            // Clear stale pending
            if let t = pendingFirstSeen, now.timeIntervalSince(t) > confirmWindow {
                pendingIndex = nil
                pendingFirstSeen = nil
                pendingScore = 0
            }
            return nil
        }

        // Never jump backwards (unless confidence was very low, indicating we were lost)
        if candidate < currentIndex && currentConfidence > 0.3 { 
            return nil 
        }

        // INSTANT ACCEPTANCE: High confidence scores bypass confirmation for real-time feel
        if bestScore >= instantAcceptScore && candidate != currentIndex {
            currentIndex = candidate
            currentConfidence = bestScore
            pendingIndex = nil
            pendingFirstSeen = nil
            pendingScore = 0
            return currentIndex
        }

        // Confirmation (anti-jitter) for medium-confidence matches
        if let p = pendingIndex, let t = pendingFirstSeen {
            if p == candidate {
                // Same candidate: check if enough time has passed OR if score is improving
                let elapsed = now.timeIntervalSince(t)
                let scoreImproving = bestScore > pendingScore
                
                if elapsed >= confirmWindow || scoreImproving {
                    if candidate != currentIndex {
                        currentIndex = candidate
                        currentConfidence = bestScore
                        pendingIndex = nil
                        pendingFirstSeen = nil
                        pendingScore = 0
                        return currentIndex
                    } else {
                        pendingIndex = nil
                        pendingFirstSeen = nil
                        pendingScore = 0
                        return nil
                    }
                }
                // Still pending, update score and confidence
                pendingScore = max(pendingScore, bestScore)
                currentConfidence = bestScore
                return nil
            } else {
                // Different candidate, reset pending
                pendingIndex = candidate
                pendingFirstSeen = now
                pendingScore = bestScore
                currentConfidence = bestScore * 0.7  // Reduce confidence when switching candidates
                return nil
            }
        } else {
            pendingIndex = candidate
            pendingFirstSeen = now
            pendingScore = bestScore
            currentConfidence = bestScore * 0.7
            return nil
        }
    }

    // MARK: - Matching

    private static func score(
        lineWords: [String],
        transcriptWords: [String],
        requiredPrefixMatches: Int,
        linePrefixCap: Int
    ) -> Double {

        // Focus on the beginning of the line (what you say when you “arrive” here)
        let prefixCount = min(max(1, linePrefixCap), lineWords.count)
        let prefix = Array(lineWords.prefix(prefixCount))

        let orderedMatches = orderedMatchCount(needle: prefix, haystack: transcriptWords)
        if orderedMatches < min(requiredPrefixMatches, prefix.count) {
            return 0
        }

        let consecutive = longestConsecutiveMatch(needle: prefix, haystack: transcriptWords)

        // Score emphasizes ordered matches, with a bump for consecutive runs
        let orderedRatio = Double(orderedMatches) / Double(prefix.count)
        let consecutiveRatio = Double(consecutive) / Double(prefix.count)

        return min(0.95, (orderedRatio * 0.75) + (consecutiveRatio * 0.25))
    }

    private static func orderedMatchCount(needle: [String], haystack: [String]) -> Int {
        var matched = 0
        var i = 0
        for w in haystack {
            if i >= needle.count { break }
            if w == needle[i] {
                matched += 1
                i += 1
            }
        }
        return matched
    }

    private static func longestConsecutiveMatch(needle: [String], haystack: [String]) -> Int {
        guard !needle.isEmpty, !haystack.isEmpty else { return 0 }
        var best = 0

        for i in 0..<needle.count {
            for j in 0..<haystack.count {
                var run = 0
                while (i + run) < needle.count,
                      (j + run) < haystack.count,
                      needle[i + run] == haystack[j + run] {
                    run += 1
                }
                best = max(best, run)
            }
        }
        return best
    }

    private static func normalize(_ text: String) -> String {
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
        return cleaned
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
