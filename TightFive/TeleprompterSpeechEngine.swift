import Foundation
import Speech
import AVFoundation
import Combine
import SwiftUI

/// Continuous speech recognition engine for Teleprompter Stage Mode.
/// - Publishes partial transcripts continuously (no restarts).
/// - Also runs anchor detection via StageAnchorMatcher.
/// - Designed to be stable on stage (tail matching + cooldowns).
@MainActor
final class TeleprompterSpeechEngine: ObservableObject {

    @Published private(set) var isListening: Bool = false
    @Published private(set) var partialTranscript: String = ""
    @Published private(set) var errorMessage: String?

    var onAnchor: ((StageAnchor, Double) -> Void)?

    private let speechRecognizer: SFSpeechRecognizer?
    private var audioEngine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    private var matcher = StageAnchorMatcher(anchors: [])

    init(localeIdentifier: String = "en-US") {
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier))
    }

    func configureAnchors(_ anchors: [StageAnchor]) {
        matcher = StageAnchorMatcher(anchors: anchors)
    }

    func requestPermissionIfNeeded() async -> Bool {
        let status = SFSpeechRecognizer.authorizationStatus()
        if status == .authorized { return true }

        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { newStatus in
                continuation.resume(returning: newStatus == .authorized)
            }
        }
    }

    func start() async {
        errorMessage = nil

        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            errorMessage = "Speech recognition not available."
            return
        }

        let granted = await requestPermissionIfNeeded()
        guard granted else {
            errorMessage = "Speech permission not granted."
            return
        }

        do {
            try startSession()
            isListening = true
        } catch {
            errorMessage = "Speech start failed: \(error.localizedDescription)"
            cleanup()
        }
    }

    func stop() {
        isListening = false
        cleanup()
    }

    func resetAnchorState() {
        matcher.reset()
    }

    // MARK: - Private

    private func startSession() throws {
        cleanup()

        audioEngine = AVAudioEngine()
        guard let audioEngine else { throw NSError(domain: "TeleprompterSpeechEngine", code: 1) }

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(
            .playAndRecord,
            mode: .measurement,
            options: [.defaultToSpeaker, .allowBluetoothHFP, .mixWithOthers]
        )
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        request = SFSpeechAudioBufferRecognitionRequest()
        guard let request else { throw NSError(domain: "TeleprompterSpeechEngine", code: 2) }

        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false
        if #available(iOS 16.0, *) { request.taskHint = .dictation }

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        task = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            Task { @MainActor in
                if let error {
                    // Don’t hard-stop for common transient issues; surface message.
                    self.errorMessage = error.localizedDescription
                    return
                }

                guard let result else { return }

                let text = result.bestTranscription.formattedString
                self.partialTranscript = text

                // Anchor detection (safe and conservative via StageAnchorMatcher)
                if let match = self.matcher.ingest(transcript: text) {
                    self.onAnchor?(match.anchor, match.confidence)
                }
            }
        }
    }

    private func cleanup() {
        task?.cancel()
        task = nil

        request?.endAudio()
        request = nil

        if let engine = audioEngine {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }
        audioEngine = nil
    }
}
