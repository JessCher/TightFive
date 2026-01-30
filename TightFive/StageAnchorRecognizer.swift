import Foundation
import Speech
import AVFoundation
import Combine
import SwiftUI

/// Speech recognition for Stage Mode anchor phrase detection.
///
/// This recognizer is intentionally conservative:
/// - Anchors should *always* fire when spoken naturally.
/// - Anchors should *never* false-positive and jump the teleprompter unexpectedly.
///
/// Strategy
/// - We feed partial transcripts into `StageAnchorMatcher`, which:
///   - normalizes text,
///   - prefers whole-phrase boundary matches,
///   - uses ordered matching for longer anchors,
///   - and confirms a match across consecutive partial transcripts (two-hit confirm)
///
/// IMPORTANT: Two-hit confirm does **not** require the comedian to repeat the anchor.
/// It relies on multiple partial transcripts emitted by the speech recognizer.
final class StageAnchorRecognizer: ObservableObject {

    @MainActor @Published private(set) var isListening = false
    @MainActor @Published private(set) var lastTranscript = ""
    @MainActor @Published private(set) var error: RecognitionError?

    var onAnchorDetected: ((StageAnchor, Double) -> Void)?

    private let speechRecognizer: SFSpeechRecognizer?
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    private var anchors: [StageAnchor] = []
    private var detectedAnchorIds: Set<UUID> = []

    /// Stateful matcher that reduces false positives.
    private var matcher = StageAnchorMatcher(anchors: [])

    // Session management
    private var isRestarting = false
    private var restartWorkItem: DispatchWorkItem?

    // Buffer management
    private var transcriptBuffer = ""
    private var lastMatchTime: Date?

    /// Tiny post-fire debounce (secondary safety). Real cooldowns live in `StageAnchorMatcher`.
    private let matchCooldown: TimeInterval = 0.10

    enum RecognitionError: LocalizedError {
        case notAvailable
        case permissionDenied
        case audioConfigFailed
        case recognitionFailed(String)

        var errorDescription: String? {
            switch self {
            case .notAvailable:
                return "Speech recognition not available on this device."
            case .permissionDenied:
                return "Speech recognition permission denied."
            case .audioConfigFailed:
                return "Could not configure audio input."
            case .recognitionFailed(let message):
                return "Recognition failed: \(message)"
            }
        }
    }

    init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }

    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    var hasPermission: Bool {
        SFSpeechRecognizer.authorizationStatus() == .authorized
    }

    @MainActor
    func startListening(for anchors: [StageAnchor]) async -> Bool {
        self.anchors = anchors.filter { $0.isEnabled && $0.isValid }
        self.matcher = StageAnchorMatcher(anchors: self.anchors)

        detectedAnchorIds.removeAll()
        transcriptBuffer = ""
        lastMatchTime = nil
        error = nil

        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            error = .notAvailable
            return false
        }

        if !hasPermission {
            let granted = await requestPermission()
            if !granted {
                error = .permissionDenied
                return false
            }
        }

        do {
            try startRecognitionSession()
            isListening = true
            return true
        } catch {
            self.error = .recognitionFailed(error.localizedDescription)
            return false
        }
    }

    @MainActor
    func stopListening() {
        isListening = false
        isRestarting = false
        restartWorkItem?.cancel()
        restartWorkItem = nil

        cleanupRecognition()
    }

    /// Call this after navigation completes to allow detecting the NEXT anchor.
    @MainActor
    func clearLastDetection() {
        print("🧹 clearLastDetection() called")
        print("   Before - detectedAnchorIds: \(detectedAnchorIds)")

        detectedAnchorIds.removeAll()
        transcriptBuffer = ""
        lastTranscript = ""
        lastMatchTime = nil
        matcher.reset()

        print("   After - detectedAnchorIds: \(detectedAnchorIds)")

        // CRITICAL: Restart to clear Speech Recognition's internal transcript buffer.
        // Without this, the transcript can accumulate and re-trigger old anchors.
        if isListening && !isRestarting {
            print("   🔄 Restarting to clear accumulated transcript...")
            scheduleRestart(delay: 0.10)
        }
    }

    @MainActor
    func resetDetectedAnchors() {
        detectedAnchorIds.removeAll()
        transcriptBuffer = ""
        lastTranscript = ""
        lastMatchTime = nil
        matcher.reset()
    }

    // MARK: - Private Methods

    private func startRecognitionSession() throws {
        cleanupRecognition()

        // Brief wait for cleanup - reduced for faster restart
        Thread.sleep(forTimeInterval: 0.05)

        audioEngine = AVAudioEngine()
        guard let audioEngine else {
            throw RecognitionError.audioConfigFailed
        }

        // Configure audio session for recording alongside playback
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(
            .playAndRecord,
            mode: .measurement,
            options: [.defaultToSpeaker, .allowBluetoothHFP, .mixWithOthers]
        )
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else {
            throw RecognitionError.audioConfigFailed
        }

        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false

        if #available(iOS 16.0, *) {
            request.taskHint = .dictation
        }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        guard recordingFormat.sampleRate > 0 && recordingFormat.channelCount > 0 else {
            throw RecognitionError.audioConfigFailed
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        guard let recognizer = speechRecognizer else {
            throw RecognitionError.notAvailable
        }

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            DispatchQueue.main.async {
                self?.handleRecognitionResult(result, error: error)
            }
        }
    }

    @MainActor
    private func handleRecognitionResult(_ result: SFSpeechRecognitionResult?, error: Error?) {
        // Ignore results during restart
        if isRestarting {
            print("⏭️ Ignoring result during restart")
            return
        }

        if let error {
            let nsError = error as NSError

            print("⚠️ Recognition error: domain=\(nsError.domain), code=\(nsError.code), message=\(error.localizedDescription)")

            // Handle known non-fatal errors
            if nsError.domain == "kLSRErrorDomain", nsError.code == 301 {
                print("ℹ️ Recognition canceled (expected), continuing session")
                return
            }

            // Handle kAFAssistantErrorDomain errors
            if nsError.domain == "kAFAssistantErrorDomain" {
                // Fatal errors that require restart:
                if nsError.code == 216 || nsError.code == 203 {
                    print("🔄 Fatal error, restarting...")
                    scheduleRestart(delay: 0.80)
                    return
                }
                // Non-fatal errors (1110 = no speech, 1107 = timeout)
                print("ℹ️ Non-fatal error, continuing session")
                return
            }

            // Unknown errors: try to restart
            print("🔄 Unknown error, restarting...")
            scheduleRestart(delay: 0.80)
            return
        }

        guard let result else { return }

        let transcript = result.bestTranscription.formattedString
        lastTranscript = transcript

        print("📝 Transcript: '\(transcript)' (isFinal: \(result.isFinal))")

        // Small debounce just to avoid immediate echo-triggering after navigation
        if let lastMatch = lastMatchTime, Date().timeIntervalSince(lastMatch) < matchCooldown {
            print("⏸️ In post-fire debounce, ignoring")
            return
        }

        if !transcript.isEmpty {
            transcriptBuffer = transcript
            checkForAnchorMatch(in: transcriptBuffer)
        }
    }

    @MainActor
    private func checkForAnchorMatch(in transcript: String) {
        // Post-fire debounce (secondary safety)
        if let lastMatch = lastMatchTime, Date().timeIntervalSince(lastMatch) < matchCooldown {
            return
        }

        // If we already fired and haven’t been cleared, do not detect anything else.
        // This ensures one clean navigation per spoken anchor.
        if !detectedAnchorIds.isEmpty {
            return
        }

        if let match = matcher.ingest(transcript: transcript) {
            print("✨ CONFIRMED ANCHOR: \(match.anchor.phrase) (confidence: \(match.confidence))")

            guard !detectedAnchorIds.contains(match.anchor.id) else { return }

            detectedAnchorIds.insert(match.anchor.id)
            lastMatchTime = Date()

            transcriptBuffer = ""
            lastTranscript = ""

            onAnchorDetected?(match.anchor, match.confidence)
        }
    }

    @MainActor
    private func scheduleRestart(delay: TimeInterval = 0.80) {
        guard isListening && !isRestarting else {
            print("⚠️ scheduleRestart blocked: isListening=\(isListening), isRestarting=\(isRestarting)")
            return
        }

        print("🔄 Scheduling restart with delay: \(delay)s")
        isRestarting = true

        restartWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                guard let self, self.isListening else {
                    print("❌ Restart cancelled - not listening")
                    self?.isRestarting = false
                    return
                }

                print("🔄 Executing restart...")

                do {
                    try self.startRecognitionSession()
                    self.isRestarting = false
                    print("✅ Restart complete - ready for next anchor")
                } catch {
                    print("❌ Restart failed: \(error)")
                    self.isRestarting = false

                    // If restart fails, try again after longer delay
                    if self.isListening {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.50) {
                            Task { @MainActor in
                                if self.isListening {
                                    self.scheduleRestart(delay: 1.00)
                                }
                            }
                        }
                    }
                }
            }
        }

        restartWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func cleanupRecognition() {
        recognitionTask?.cancel()
        recognitionTask = nil

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        if let engine = audioEngine {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }
        audioEngine = nil
    }

    deinit {
        restartWorkItem?.cancel()
    }
}
