import SwiftUI
import SwiftData
import UIKit

struct StageModeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let setlist: Setlist
    var venue: String = ""

    @StateObject private var engine = StageTeleprompterEngine()
    @State private var tracker: TeleprompterScrollTracker

    @State private var showExitConfirmation = false
    @State private var showSaveConfirmation = false
    @State private var isInitialized = false

    @State private var isAutoScrollEnabled: Bool = true
    @State private var lastScrollUpdateAt: Date = .distantPast

    init(setlist: Setlist, venue: String = "") {
        self.setlist = setlist
        self.venue = venue
        let lines = StageModeView.buildLines(from: setlist)
        _tracker = State(initialValue: TeleprompterScrollTracker(lines: lines))
    }

    private var anchors: [StageAnchor] {
        setlist.stageAnchors.filter { $0.isEnabled && $0.isValid }
    }

    private var hasContent: Bool {
        !tracker.lines.isEmpty
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()

                if !hasContent {
                    emptyState
                } else {
                    VStack(spacing: 0) {
                        topBar(geometry: geometry)
                        teleprompterContent
                        bottomBar
                    }
                }

                if showExitConfirmation {
                    exitConfirmationOverlay
                }

                if showSaveConfirmation {
                    saveConfirmationOverlay
                }
            }
        }
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .onAppear { startSessionIfNeeded() }
        .onDisappear { engine.stop() }
        .onChange(of: engine.partialTranscript) { _, newValue in
            guard isAutoScrollEnabled else { return }
            handleTranscript(newValue)
        }
    }

    private func startSessionIfNeeded() {
        guard !isInitialized else { return }
        isInitialized = true

        engine.configureAnchors(anchors)
        engine.onAnchor = { anchor, confidence in
            handleAnchor(anchor, confidence: confidence)
        }

        Task {
            await engine.start(filenameBase: setlist.title)
        }
    }

    private func endSession() {
        if let result = engine.stopAndFinalize() {
            let performance = Performance(
                setlistId: setlist.id,
                setlistTitle: setlist.title,
                venue: venue,
                audioFilename: result.url.lastPathComponent,
                duration: result.duration,
                fileSize: result.fileSize
            )
            modelContext.insert(performance)
            try? modelContext.save()
            showSaveConfirmation = true
        } else {
            dismiss()
        }
    }

    // MARK: - UI

    private func topBar(geometry: GeometryProxy) -> some View {
        HStack(spacing: 16) {
            Button { showExitConfirmation = true } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }

            Spacer()

            if engine.isRunning {
                recordingIndicator
            }

            Spacer()

            Text(engine.formattedTime)
                .font(.system(size: 20, weight: .medium, design: .monospaced))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
        .padding(.horizontal, 20)
        .padding(.top, geometry.safeAreaInsets.top + 8)
        .padding(.bottom, 12)
        .background(
            LinearGradient(
                colors: [Color.black, Color.black.opacity(0.85), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)
        )
    }

    private var recordingIndicator: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.red)
                .frame(width: 10, height: 10)

            Text("REC")
                .font(.caption.weight(.bold))
                .foregroundStyle(.red)

            AudioLevelBar(level: engine.audioLevel)
                .frame(width: 40, height: 16)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.6))
        .clipShape(Capsule())
    }

    private var teleprompterContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    Text(setlist.title.uppercased())
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(TFTheme.yellow)
                        .kerning(2)
                        .padding(.bottom, 6)

                    Rectangle()
                        .fill(TFTheme.yellow.opacity(0.5))
                        .frame(height: 2)
                        .frame(maxWidth: 120)
                        .padding(.bottom, 14)

                    ForEach(Array(tracker.lines.enumerated()), id: \.element.id) { index, line in
                        lineRow(line, index: index)
                            .id(line.id)
                    }

                    Spacer(minLength: 120)
                }
                .padding(.horizontal, 28)
                .padding(.top, 18)
            }
            .scrollIndicators(.hidden)
            .overlay(alignment: .bottom) {
                contextWindow
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
            }
            .onChange(of: tracker.currentIndex) { _, _ in
                guard tracker.currentIndex >= 0, tracker.currentIndex < tracker.lines.count else { return }
                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo(tracker.lines[tracker.currentIndex].id, anchor: .center)
                }
                hapticFeedback()
            }
        }
    }

    private func lineRow(_ line: TeleprompterScrollTracker.Line, index: Int) -> some View {
        let isCurrent = index == tracker.currentIndex

        if line.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return AnyView(Spacer().frame(height: 10))
        }

        return AnyView(
            Text(line.text)
                .font(.system(size: 24, weight: .regular))
                .foregroundStyle(isCurrent ? .white : .white.opacity(0.85))
                .lineSpacing(10)
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isCurrent ? Color.white.opacity(0.12) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isCurrent ? TFTheme.yellow.opacity(0.55) : Color.clear, lineWidth: 1)
                )
        )
    }

    private var contextWindow: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: engine.isListening ? "waveform" : "waveform.slash")
                    .font(.caption)
                    .foregroundStyle(engine.isListening ? .green : .white.opacity(0.4))

                Text(engine.isListening ? "Listening" : "Not Listening")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(engine.isListening ? .green : .white.opacity(0.4))

                Spacer()

                if let msg = engine.errorMessage, !msg.isEmpty {
                    Text(msg)
                        .font(.caption2)
                        .foregroundStyle(.red.opacity(0.9))
                        .lineLimit(1)
                }
            }

            let current = tracker.lines[safe: tracker.currentIndex]?.text ?? ""

            let next = tracker.lines[safe: tracker.currentIndex + 1]?.text ?? ""

            VStack(alignment: .leading, spacing: 6) {
                Text(current)
                    .font(.system(size: 1, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                if !next.isEmpty {
                    Text(next)
                        .font(.system(size: 1, weight: .regular))
                        .foregroundStyle(.white.opacity(0.0))
                        .lineLimit(1)
                }
            }
        }
        .padding(10)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var bottomBar: some View {
        HStack(spacing: 18) {
            Button { isAutoScrollEnabled.toggle() } label: {
                HStack(spacing: 8) {
                    Image(systemName: isAutoScrollEnabled ? "sparkles" : "hand.raised.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text(isAutoScrollEnabled ? "Auto" : "Manual")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(isAutoScrollEnabled ? .black : .white.opacity(0.9))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(isAutoScrollEnabled ? TFTheme.yellow : Color.white.opacity(0.12))
                .clipShape(Capsule())
            }

            Spacer()

            Button {
                var mutable = tracker
                mutable.reset(to: max(0, tracker.currentIndex - 1))
                tracker = mutable
            } label: {
                Image(systemName: "chevron.up")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }

            Button {
                var mutable = tracker
                mutable.reset(to: min(tracker.lines.count - 1, tracker.currentIndex + 1))
                tracker = mutable
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.85), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Logic

    private func handleTranscript(_ transcript: String) {
        let now = Date()
        if now.timeIntervalSince(lastScrollUpdateAt) < 0.01 { return }
        lastScrollUpdateAt = now

        var mutable = tracker
        _ = mutable.ingestTranscript(transcript)
        tracker = mutable
    }

    private func handleAnchor(_ anchor: StageAnchor, confidence: Double) {
        let targetBlockId = anchor.blockReference.id
        var mutable = tracker
        mutable.jumpToBlock(blockId: targetBlockId)
        tracker = mutable

        engine.resetAnchorState()
        hapticFeedback()
    }

    private func hapticFeedback() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // MARK: - Overlays

    private var exitConfirmationOverlay: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture { showExitConfirmation = false }

            VStack(spacing: 18) {
                Text("End Performance?")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)

                Text("Your recording will be saved.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))

                HStack(spacing: 12) {
                    Button("Cancel") { showExitConfirmation = false }
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Capsule())

                    Button("End") {
                        showExitConfirmation = false
                        endSession()
                    }
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(TFTheme.yellow)
                    .clipShape(Capsule())
                }
            }
            .padding(22)
            .background(Color.black.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .padding(.horizontal, 24)
        }
    }

    private var saveConfirmationOverlay: some View {
        ZStack {
            Color.black.opacity(0.8).ignoresSafeArea()

            VStack(spacing: 14) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.green)

                Text("Performance Saved")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)

                Button("Done") { dismiss() }
                    .font(.headline)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(TFTheme.yellow)
                    .clipShape(Capsule())
                    .padding(.top, 6)
            }
            .padding(22)
            .background(Color.black.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .padding(.horizontal, 24)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 56))
                .foregroundStyle(.white.opacity(0.3))

            Text("No script content")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)

            Text("Add content to your setlist script first.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))

            Button("Go Back") { dismiss() }
                .font(.headline)
                .foregroundStyle(.black)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(TFTheme.yellow)
                .clipShape(Capsule())
        }
    }

    // MARK: - Lines

    private static func buildLines(from setlist: Setlist) -> [TeleprompterScrollTracker.Line] {
        var result: [TeleprompterScrollTracker.Line] = []

        for (blockIndex, block) in setlist.scriptBlocks.enumerated() {
            let blockId = block.id
            let text = blockPlainText(setlist: setlist, block: block)

            let cleaned = text
                .replacingOccurrences(of: "\r\n", with: "\n")
                .replacingOccurrences(of: "\r", with: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            // Break into chunks that are easy to match in speech (8–14 words)
            let rawUnits = cleaned
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            for unit in rawUnits {
                let chunks = chunkText(unit, targetWordsPerChunk: 12)
                for chunk in chunks {
                    let words = normalizeWords(chunk)
                    if words.isEmpty { continue }

                    result.append(
                        TeleprompterScrollTracker.Line(
                            id: UUID(),
                            text: chunk,
                            normalizedWords: words,
                            blockId: blockId,
                            blockIndex: blockIndex
                        )
                    )
                }
            }


            if !result.isEmpty {
                result.append(
                    TeleprompterScrollTracker.Line(
                        id: UUID(),
                        text: "",
                        normalizedWords: [],
                        blockId: blockId,
                        blockIndex: blockIndex
                    )
                )
            }
        }

        while let last = result.last,
              last.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            result.removeLast()
        }

        return result
    }

    private static func blockPlainText(setlist: Setlist, block: ScriptBlock) -> String {
        switch block {
        case .freeform(_, let rtfData):
            return NSAttributedString.fromRTF(rtfData)?.string ?? ""
        case .bit(_, let assignmentId):
            guard let assignment = setlist.assignments.first(where: { $0.id == assignmentId }) else { return "" }
            return assignment.plainText
        }
    }

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
    private static func chunkText(_ text: String, targetWordsPerChunk: Int) -> [String] {
        // Split by punctuation into sentences first
        let sentenceSeparators = CharacterSet(charactersIn: ".!?")
        var sentences: [String] = []
        var current = ""

        for ch in text {
            current.append(ch)
            if String(ch).rangeOfCharacter(from: sentenceSeparators) != nil {
                let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { sentences.append(trimmed) }
                current = ""
            }
        }

        let tail = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty { sentences.append(tail) }

        // If no punctuation found, treat as one sentence
        if sentences.isEmpty {
            sentences = [text.trimmingCharacters(in: .whitespacesAndNewlines)]
        }

        // Now chunk sentences by word count
        var chunks: [String] = []
        var bufferWords: [String] = []

        func flush() {
            let joined = bufferWords.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            if !joined.isEmpty { chunks.append(joined) }
            bufferWords.removeAll()
        }

        for s in sentences {
            let words = s.split(whereSeparator: \.isWhitespace).map(String.init)
            for w in words {
                bufferWords.append(w)
                if bufferWords.count >= targetWordsPerChunk {
                    flush()
                }
            }
            // sentence boundary → flush for readability
            flush()
        }

        return chunks
    }
}


// MARK: - AudioLevelBar

private struct AudioLevelBar: View {
    let level: Float
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: geo.size.height / 2)
                    .fill(Color.white.opacity(0.15))
                RoundedRectangle(cornerRadius: geo.size.height / 2)
                    .fill(Color.red.opacity(0.9))
                    .frame(width: max(2, CGFloat(level) * geo.size.width))
            }
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0 && index < count else { return nil }
        return self[index]
    }
}
