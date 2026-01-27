import Foundation
import Combine
import Speech
import AVFoundation

/// Single-pipeline Stage Mode engine:
/// - Captures mic ONCE via AVAudioEngine
/// - Feeds Speech recognition partial transcripts
/// - Detects Stage Anchors (StageAnchorMatcher)
/// - Records audio to disk (CAF PCM - reliable for real-time writing)
///
/// Fixes vs prior version:
/// - Forces on-device recognition when supported (huge reliability win)
/// - Supplies contextualStrings (anchor phrases) to improve recognition
/// - Adds a watchdog: if audio is present but transcript stays empty, restart recognition
@MainActor
final class StageTeleprompterEngine: ObservableObject {

    // MARK: - Published (UI)

    @Published private(set) var isRunning: Bool = false
    @Published private(set) var isListening: Bool = false
    @Published private(set) var partialTranscript: String = ""
    @Published private(set) var audioLevel: Float = 0
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var errorMessage: String?

    var onAnchor: ((StageAnchor, Double) -> Void)?

    // MARK: - Internals

    private let speechRecognizer: SFSpeechRecognizer?

    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?

    private var levelTimer: Timer?
    private var timeTimer: Timer?
    private var watchdogTimer: Timer?
    private var startDate: Date?

    private var matcher = StageAnchorMatcher(anchors: [])
    private var contextualStrings: [String] = []

    private var recordingURL: URL?

    /// Tap writes audio + appends to recognition request. We may swap the request during watchdog restarts.
    private let requestLock = NSLock()

    init(localeIdentifier: String = "en-US") {
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier))
    }

    // MARK: - Permissions

    func requestSpeechPermissionIfNeeded() async -> Bool {
        let status = SFSpeechRecognizer.authorizationStatus()
        if status == .authorized { return true }

        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { newStatus in
                continuation.resume(returning: newStatus == .authorized)
            }
        }
    }

    // MARK: - Public API

    func configureAnchors(_ anchors: [StageAnchor]) {
        matcher = StageAnchorMatcher(anchors: anchors)
        contextualStrings = anchors
            .filter { $0.isEnabled && $0.isValid }
            .map { $0.phrase }
    }

    func resetAnchorState() {
        matcher.reset()
    }

    func start(filenameBase: String) async {
        errorMessage = nil

        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            errorMessage = "Speech recognition not available."
            return
        }

        let speechOK = await Permissions.requestSpeechIfNeeded()
        let micOK = await Permissions.requestMicrophoneIfNeeded()

        guard speechOK && micOK else {
            errorMessage = "Speech or microphone permission not granted."
            return
        }

        do {
            try configureAudioSession()
            try startPipeline(filenameBase: filenameBase, recognizer: recognizer)

            isRunning = true
            isListening = false
        } catch {
            errorMessage = "Stage engine start failed: \(error.localizedDescription)"
            stop()
        }
    }

    func stopAndFinalize() -> (url: URL, duration: TimeInterval, fileSize: Int64)? {
        defer { stop() }

        guard let url = recordingURL else { return nil }

        audioFile = nil

        let duration = currentTime

        var fileSize: Int64 = 0
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? Int64 {
            fileSize = size
        }

        return (url, duration, fileSize)
    }

    func stop() {
        isRunning = false
        isListening = false

        levelTimer?.invalidate(); levelTimer = nil
        timeTimer?.invalidate(); timeTimer = nil
        watchdogTimer?.invalidate(); watchdogTimer = nil

        cancelRecognitionOnly()

        if let engine = audioEngine {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }
        audioEngine = nil

        audioFile = nil
        recordingURL = nil
        startDate = nil

        audioLevel = 0
        currentTime = 0
        partialTranscript = ""
    }

    // MARK: - Audio Session

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .spokenAudio, // better for speech recognition than .measurement here
            options: [.defaultToSpeaker, .allowBluetoothHFP]
        )
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Pipeline

    private func startPipeline(filenameBase: String, recognizer: SFSpeechRecognizer) throws {
        teardownPipelineOnly()

        try FileManager.default.createDirectory(
            at: Performance.recordingsDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        let engine = AVAudioEngine()
        self.audioEngine = engine

        let safeBase = filenameBase.isEmpty ? "Performance" : filenameBase
        let filename = Performance.generateFilename(for: safeBase)
            .replacingOccurrences(of: ".m4a", with: ".caf")

        let url = Performance.recordingsDirectory.appendingPathComponent(filename)
        self.recordingURL = url

        // Prepare file using input format settings
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        self.audioFile = try AVAudioFile(forWriting: url, settings: format.settings)

        // Start recognition (request + task)
        startRecognitionOnly(recognizer: recognizer)

        // Tap mic once: record + speech + meter
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self else { return }

            // Record
            do { try self.audioFile?.write(from: buffer) }
            catch {
                Task { @MainActor in
                    self.errorMessage = "Recording write failed: \(error.localizedDescription)"
                }
            }

            // Feed speech (thread-safe if request is swapped by watchdog)
            self.requestLock.lock()
            let req = self.recognitionRequest
            self.requestLock.unlock()
            req?.append(buffer)

            // Meter
            let level = Self.computeLevel(from: buffer)
            Task { @MainActor in
                self.audioLevel = level
            }
        }

        engine.prepare()
        try engine.start()

        startDate = Date()
        startTimers(recognizer: recognizer)
    }

    private func teardownPipelineOnly() {
        levelTimer?.invalidate(); levelTimer = nil
        timeTimer?.invalidate(); timeTimer = nil
        watchdogTimer?.invalidate(); watchdogTimer = nil

        cancelRecognitionOnly()

        if let engine = audioEngine {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }
        audioEngine = nil

        audioFile = nil
        recordingURL = nil
        startDate = nil
    }

    // MARK: - Recognition control (restartable)

    private func startRecognitionOnly(recognizer: SFSpeechRecognizer) {
        cancelRecognitionOnly()

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true

        // BIG reliability win: on-device when supported
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        } else {
            request.requiresOnDeviceRecognition = false
        }

        if #available(iOS 16.0, *) {
            request.taskHint = .dictation
        }

        // Bias recognition toward your anchor phrases
        if !contextualStrings.isEmpty {
            request.contextualStrings = contextualStrings
        }

        requestLock.lock()
        recognitionRequest = request
        requestLock.unlock()

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            Task { @MainActor in
                if let error {
                    let ns = error as NSError

                    // Common benign errors:
                    // - "no speech detected"
                    // - timeouts/cancellations while still producing partials
                    if ns.domain == "kAFAssistantErrorDomain", ns.code == 1110 {
                        // Ignore. We often still get partial transcripts.
                        return
                    }
                    if ns.domain == "kLSRErrorDomain", ns.code == 301 {
                        // Canceled (often during transitions). Ignore.
                        return
                    }

                    self.errorMessage = error.localizedDescription
                    return
                }

                guard let result else { return }

                self.isListening = true

                let text = result.bestTranscription.formattedString
                self.partialTranscript = text

                if let match = self.matcher.ingest(transcript: text) {
                    self.onAnchor?(match.anchor, match.confidence)
                }
            }
        }
    }

    private func cancelRecognitionOnly() {
        recognitionTask?.cancel()
        recognitionTask = nil

        requestLock.lock()
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        requestLock.unlock()

        isListening = false
    }

    // MARK: - Timers

    private func startTimers(recognizer: SFSpeechRecognizer) {
        levelTimer?.invalidate()
        timeTimer?.invalidate()
        watchdogTimer?.invalidate()

        nonisolated(unsafe) let safeRecognizer = recognizer

        // Time
        timeTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                if let start = self.startDate, self.isRunning {
                    self.currentTime = Date().timeIntervalSince(start)
                }
            }
        }
        if let t = timeTimer { RunLoop.main.add(t, forMode: .common) }

        // Watchdog: if we clearly have audio but transcript stays empty, restart recognition only.
        watchdogTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self, safeRecognizer] _ in
            guard let self else { return }
            Task { @MainActor in
                guard self.isRunning else { return }
                guard let start = self.startDate else { return }

                let age = Date().timeIntervalSince(start)

                // If after 2 seconds we have audio but still no transcript, restart recognition.
                if age > 2.0, self.partialTranscript.isEmpty, self.audioLevel > 0.05 {
                    self.errorMessage = "Restarting speech…"
                    self.startRecognitionOnly(recognizer: safeRecognizer)
                }
            }
        }
        if let t = watchdogTimer { RunLoop.main.add(t, forMode: .common) }
    }

    // MARK: - Metering

    private static func computeLevel(from buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData?[0] else { return 0 }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return 0 }

        var sumSquares: Float = 0
        for i in 0..<frameLength {
            let s = channelData[i]
            sumSquares += s * s
        }

        let rms = sqrt(sumSquares / Float(frameLength))
        return min(max(rms * 6.0, 0), 1)
    }

    // MARK: - Formatting

    var formattedTime: String {
        let minutes = Int(currentTime) / 60
        let seconds = Int(currentTime) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
