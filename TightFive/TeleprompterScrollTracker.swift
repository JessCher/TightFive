import Foundation

/// Converts partial speech transcript into a stable "current line index".
/// Designed for live performance stability:
/// - Only searches forward (prevents jumping backward).
/// - Uses "ordered word match" so common overlap doesn't cause false jumps.
/// - Uses lightweight confirmation to prevent jitter.
struct TeleprompterScrollTracker {

    struct Line: Identifiable, Hashable {
        let id: UUID
        let text: String
        let normalizedWords: [String]
        let blockId: UUID?
        let blockIndex: Int
    }

    private(set) var lines: [Line] = []

    /// Current "spoken" line index
    private(set) var currentIndex: Int = 0

    // Jitter control
    private var pendingIndex: Int?
    private var pendingFirstSeen: Date?

    // Tunables
    private let windowForward: Int = 18
    private let minAdvance: Int = 0
    private let confirmWindow: TimeInterval = 0.45
    private let minScore: Double = 0.70

    init(lines: [Line]) {
        self.lines = lines
        self.currentIndex = 0
    }

    mutating func reset(to index: Int = 0) {
        currentIndex = max(0, min(index, lines.count - 1))
        pendingIndex = nil
        pendingFirstSeen = nil
    }

    mutating func jumpToBlock(blockId: UUID) {
        guard let idx = lines.firstIndex(where: { $0.blockId == blockId }) else { return }
        reset(to: idx)
    }

    mutating func ingestTranscript(_ transcript: String, now: Date = Date()) -> Int? {
        guard !lines.isEmpty else { return nil }

        let transcriptWords = Self.normalize(transcript).split(separator: " ").map(String.init)
        guard !transcriptWords.isEmpty else { return nil }

        let start = currentIndex
        let end = min(lines.count - 1, currentIndex + windowForward)

        var bestIndex: Int?
        var bestScore: Double = 0

        for idx in start...end {
            let score = Self.score(lineWords: lines[idx].normalizedWords, transcriptWords: transcriptWords)
            if score > bestScore {
                bestScore = score
                bestIndex = idx
            }
        }

        guard let candidate = bestIndex, bestScore >= minScore else {
            // clear stale pending
            if let pendingFirstSeen, now.timeIntervalSince(pendingFirstSeen) > confirmWindow {
                pendingIndex = nil
                self.pendingFirstSeen = nil
            }
            return nil
        }

        // Never jump backwards during live scroll tracking
        if candidate < currentIndex { return nil }

        // Require at least minAdvance forward movement (usually 0, but we keep knob)
        if candidate < currentIndex + minAdvance { return nil }

        // Confirmation against jitter: same candidate should repeat across partial updates
        if let pendingIndex, let pendingFirstSeen {
            if pendingIndex == candidate, now.timeIntervalSince(pendingFirstSeen) <= confirmWindow {
                if candidate != currentIndex {
                    currentIndex = candidate
                    self.pendingIndex = nil
                    self.pendingFirstSeen = nil
                    return currentIndex
                } else {
                    // already there
                    self.pendingIndex = nil
                    self.pendingFirstSeen = nil
                    return nil
                }
            } else {
                self.pendingIndex = candidate
                self.pendingFirstSeen = now
                return nil
            }
        } else {
            self.pendingIndex = candidate
            self.pendingFirstSeen = now
            return nil
        }
    }

    // MARK: - Matching

    private static func score(lineWords: [String], transcriptWords: [String]) -> Double {
        guard !lineWords.isEmpty else { return 0 }

        let matchedOrdered = orderedMatchCount(needle: lineWords, haystack: transcriptWords)
        let orderedRatio = Double(matchedOrdered) / Double(lineWords.count)

        if orderedRatio < 0.70 { return 0 }

        let consecutive = longestConsecutiveMatch(needle: lineWords, haystack: transcriptWords)
        let consecutiveRatio = Double(consecutive) / Double(lineWords.count)

        // Blend: ordered does most work, consecutive adds precision
        let blended = (orderedRatio * 0.75) + (consecutiveRatio * 0.25)
        return min(0.95, blended)
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
