import Foundation
import SwiftUI

/// Anchor phrase matching tuned for live Stage Mode.
///
/// Key behaviors
/// - **Whole-phrase boundary matching** for maximum precision.
/// - **Ordered matching** (words must appear in order) for longer anchors.
/// - **Two-hit confirmation** across consecutive partial transcripts (you do NOT speak twice).
/// - **Cooldowns** to avoid echo/retriggering.
struct StageAnchorMatcher {

    struct Match {
        let anchor: StageAnchor
        let confidence: Double
    }

    // MARK: - Tunables

    /// Only compare against the last N words of the transcript (keeps it “recent” and stable).
    private let transcriptTailWordCount: Int

    /// Within how long the same candidate must repeat to confirm.
    private let confirmWindow: TimeInterval

    /// Global cooldown after any match (prevents rapid double-fires).
    private let globalCooldown: TimeInterval

    /// Cooldown per anchor (prevents re-trigger from echoes/room noise).
    private let perAnchorCooldown: TimeInterval

    /// Short anchors are high-risk for false positives. Only allow strict phrase matches.
    private let shortAnchorMaxWords: Int
    private let shortAnchorMinChars: Int

    // MARK: - State

    private let candidates: [Candidate]
    private var pending: Pending?
    private var lastGlobalFireAt: Date?
    private var lastFireByAnchorId: [UUID: Date] = [:]

    // MARK: - Init

    init(
        anchors: [StageAnchor],
        transcriptTailWordCount: Int = 16,
        confirmWindow: TimeInterval = 0.50,
        globalCooldown: TimeInterval = 0.40,
        perAnchorCooldown: TimeInterval = 1.20,
        shortAnchorMaxWords: Int = 3,
        shortAnchorMinChars: Int = 10
    ) {
        self.transcriptTailWordCount = max(6, transcriptTailWordCount)
        self.confirmWindow = confirmWindow
        self.globalCooldown = globalCooldown
        self.perAnchorCooldown = perAnchorCooldown
        self.shortAnchorMaxWords = shortAnchorMaxWords
        self.shortAnchorMinChars = shortAnchorMinChars

        self.candidates = anchors
            .filter { $0.isEnabled && $0.isValid }
            .map { Candidate(anchor: $0) }
    }

    // MARK: - Public API

    mutating func ingest(transcript rawTranscript: String, now: Date = Date()) -> Match? {
        // Early global cooldown
        if let t = lastGlobalFireAt, now.timeIntervalSince(t) < globalCooldown {
            return nil
        }

        let tail = Self.tailWords(from: rawTranscript, maxWords: transcriptTailWordCount)
        let transcript = Self.normalize(tail)
        guard !transcript.isEmpty else { return nil }

        guard let best = findBestMatch(in: transcript) else {
            // Clear stale pending candidate
            if let pending, now.timeIntervalSince(pending.firstSeenAt) > confirmWindow {
                self.pending = nil
            }
            return nil
        }

        // Per-anchor cooldown
        if let t = lastFireByAnchorId[best.anchor.id], now.timeIntervalSince(t) < perAnchorCooldown {
            return nil
        }

        // Two-hit confirmation: same candidate must repeat across consecutive partials.
        if let pending {
            if pending.anchorId == best.anchor.id,
               now.timeIntervalSince(pending.firstSeenAt) <= confirmWindow {

                // Confirmed ✅
                self.pending = nil
                lastGlobalFireAt = now
                lastFireByAnchorId[best.anchor.id] = now
                return best
            } else {
                // Different candidate replaces pending
                self.pending = Pending(anchorId: best.anchor.id, firstSeenAt: now)
                return nil
            }
        } else {
            // Start pending
            self.pending = Pending(anchorId: best.anchor.id, firstSeenAt: now)
            return nil
        }
    }

    mutating func reset() {
        pending = nil
        lastGlobalFireAt = nil
        lastFireByAnchorId.removeAll()
    }

    // MARK: - Matching

    private func findBestMatch(in transcript: String) -> Match? {
        let transcriptWords = transcript.split(separator: " ").map(String.init)
        guard !transcriptWords.isEmpty else { return nil }

        var best: Match?

        for c in candidates {
            let score = c.score(
                against: transcript,
                transcriptWords: transcriptWords,
                shortAnchorMaxWords: shortAnchorMaxWords,
                shortAnchorMinChars: shortAnchorMinChars
            )

            guard score > 0 else { continue }

            if score >= c.dynamicThreshold {
                if best == nil || score > best!.confidence {
                    best = Match(anchor: c.anchor, confidence: score)
                }
            }
        }

        return best
    }

    // MARK: - Candidate

    private struct Candidate {
        let anchor: StageAnchor
        let normalized: String
        let words: [String]

        init(anchor: StageAnchor) {
            self.anchor = anchor
            self.normalized = StageAnchorMatcher.normalize(anchor.phrase)
            self.words = normalized.split(separator: " ").map(String.init)
        }

        var dynamicThreshold: Double {
            // Short anchors must be extremely confident.
            if words.count <= 3 { return 0.92 }
            if words.count <= 5 { return 0.84 }
            if words.count <= 8 { return 0.78 }
            return 0.72
        }

        func score(
            against transcript: String,
            transcriptWords: [String],
            shortAnchorMaxWords: Int,
            shortAnchorMinChars: Int
        ) -> Double {

            guard !normalized.isEmpty else { return 0 }

            // 1) Best signal: whole-phrase boundary match.
            if StageAnchorMatcher.containsPhraseBoundary(transcript, phrase: normalized) {
                return 1.0
            }

            // 2) Short anchors are too risky for fuzziness.
            if words.count <= shortAnchorMaxWords || normalized.count < shortAnchorMinChars {
                return 0
            }

            // 3) Ordered match (words must appear in order, gaps allowed).
            let ordered = StageAnchorMatcher.orderedMatchCount(anchorWords: words, transcriptWords: transcriptWords)
            let orderedRatio = Double(ordered) / Double(max(words.count, 1))

            // Require meaningful ordered coverage before we even consider confidence.
            // This kills the “random overlap of common words” problem.
            if orderedRatio < 0.80 {
                return 0
            }

            // 4) Strengthen with consecutive-run check (prevents loose in-order matches).
            let consecutive = StageAnchorMatcher.longestConsecutiveMatch(anchorWords: words, transcriptWords: transcriptWords)

            // Minimum consecutive requirement scales with anchor length.
            let minConsecutive = max(2, min(5, Int(ceil(Double(words.count) * 0.45))))

            guard consecutive >= minConsecutive else {
                return 0
            }

            // Confidence favors consecutive coverage, with ordered coverage as a base.
            let consecutiveRatio = Double(consecutive) / Double(max(words.count, 1))
            let blended = (orderedRatio * 0.70) + (consecutiveRatio * 0.30)

            return min(0.95, blended)
        }
    }

    private struct Pending {
        let anchorId: UUID
        let firstSeenAt: Date
    }

    // MARK: - Text utilities

    private static func tailWords(from text: String, maxWords: Int) -> String {
        let tokens = normalize(text).split(separator: " ").map(String.init)
        guard tokens.count > maxWords else { return tokens.joined(separator: " ") }
        return tokens.suffix(maxWords).joined(separator: " ")
    }

    /// Normalizes for robust matching:
    /// - lowercased
    /// - diacritic-insensitive (café -> cafe)
    /// - punctuation removed
    /// - whitespace collapsed
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
                scalars.append(UnicodeScalar(32)) // space
            } else {
                // punctuation/symbols -> space
                scalars.append(UnicodeScalar(32))
            }
        }

        let cleaned = String(String.UnicodeScalarView(scalars))
        return cleaned
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func containsPhraseBoundary(_ text: String, phrase: String) -> Bool {
        // Cheap and reliable word-boundary simulation:
        // " take it to the closer " matches only whole-phrase boundaries.
        let paddedText = " \(text) "
        let paddedPhrase = " \(phrase) "
        return paddedText.contains(paddedPhrase)
    }

    private static func longestConsecutiveMatch(anchorWords: [String], transcriptWords: [String]) -> Int {
        guard !anchorWords.isEmpty, !transcriptWords.isEmpty else { return 0 }

        var best = 0

        for i in 0..<anchorWords.count {
            for j in 0..<transcriptWords.count {
                var run = 0
                while (i + run) < anchorWords.count,
                      (j + run) < transcriptWords.count,
                      anchorWords[i + run] == transcriptWords[j + run] {
                    run += 1
                }
                best = max(best, run)
            }
        }

        return best
    }

    /// Greedy ordered match count (words must appear in order, but may have gaps).
    /// Example: anchor ["take","it","to","the","closer"], transcript tail
    /// ["take","it","to","closer"] => 4 matched.
    private static func orderedMatchCount(anchorWords: [String], transcriptWords: [String]) -> Int {
        guard !anchorWords.isEmpty, !transcriptWords.isEmpty else { return 0 }

        var matched = 0
        var anchorIndex = 0

        for w in transcriptWords {
            if anchorIndex >= anchorWords.count { break }
            if w == anchorWords[anchorIndex] {
                matched += 1
                anchorIndex += 1
            }
        }

        return matched
    }
}
