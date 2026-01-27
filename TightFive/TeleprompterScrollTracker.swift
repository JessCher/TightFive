import Foundation

/// Converts partial speech transcript into a stable "current line index".
///
/// Fixes vs previous version:
/// - Uses ONLY the last N transcript words (tail) to match current speech.
/// - Scores based on matching the FIRST few words of each line (what you say when you start that line).
/// - Confirmation to prevent jitter.
/// - Designed for short line chunks (8–14 words) built by StageModeView.
struct TeleprompterScrollTracker {

    struct Line: Identifiable, Hashable {
        let id: UUID
        let text: String
        let normalizedWords: [String]
        let blockId: UUID?
        let blockIndex: Int
    }

    private(set) var lines: [Line] = []
    private(set) var currentIndex: Int = 0

    private var pendingIndex: Int?
    private var pendingFirstSeen: Date?

    // Tunables (stage-safe defaults)
    private let windowForward: Int = 28
    private let confirmWindow: TimeInterval = 0.25

    /// Only match against the last N words spoken (prevents matching older content).
    private let transcriptTailWords: Int = 32

    /// Require at least this many "prefix" words of the line to be found in order.
    /// (matching the opening words of a line is the best signal for progression)
    private let requiredPrefixMatches: Int = 3

    /// How many words from the beginning of a line we consider for matching.
    private let linePrefixCap: Int = 5

    /// Minimum confidence to accept a candidate (lower because we use confirmation).
    private let minScore: Double = 0.35

    init(lines: [Line]) {
        self.lines = lines
        self.currentIndex = 0
    }

    mutating func reset(to index: Int = 0) {
        currentIndex = max(0, min(index, max(lines.count - 1, 0)))
        pendingIndex = nil
        pendingFirstSeen = nil
    }

    mutating func jumpToBlock(blockId: UUID) {
        guard let idx = lines.firstIndex(where: { $0.blockId == blockId }) else { return }
        reset(to: idx)
    }

    mutating func ingestTranscript(_ transcript: String, now: Date = Date()) -> Int? {
        guard !lines.isEmpty else { return nil }

        let normalized = Self.normalize(transcript)
        var transcriptWords = normalized.split(separator: " ").map(String.init)
        guard !transcriptWords.isEmpty else { return nil }

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
            // Clear stale pending
            if let t = pendingFirstSeen, now.timeIntervalSince(t) > confirmWindow {
                pendingIndex = nil
                pendingFirstSeen = nil
            }
            return nil
        }

        // Never jump backwards
        if candidate < currentIndex { return nil }

        // Confirmation (anti-jitter)
        if let p = pendingIndex, let t = pendingFirstSeen {
            if p == candidate, now.timeIntervalSince(t) <= confirmWindow {
                if candidate != currentIndex {
                    currentIndex = candidate
                    pendingIndex = nil
                    pendingFirstSeen = nil
                    return currentIndex
                } else {
                    pendingIndex = nil
                    pendingFirstSeen = nil
                    return nil
                }
            } else {
                pendingIndex = candidate
                pendingFirstSeen = now
                return nil
            }
        } else {
            pendingIndex = candidate
            pendingFirstSeen = now
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
