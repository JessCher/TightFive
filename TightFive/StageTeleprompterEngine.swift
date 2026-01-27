import Foundation
import SwiftUI
import Speech
import AVFoundation

/// Single-pipeline engine for Stage Mode:
/// - Captures mic ONCE via AVAudioEngine
/// - Feeds Speech recognition (partial transcripts)
/// - Detects Stage Anchors (StageAnchorMatcher)
/// - Records audio to disk (CAF PCM - reliable + fast)
///
/// Why CAF? It's the most reliable format to write from AVAudioEngine in real-time.
/// (You can add an export-to-M4A step later if you want smaller files.)
@MainActor
final class StageTeleprompterEngine: ObservableObject {

    // MARK: - Published state (UI)

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
    private var startDate: Date?

    private var matcher = StageAnchorMatcher(anchors: [])

    private var recordingURL: URL?
    private var currentFilename: String?

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

    func requestMicPermissionIfNeeded() async -> Bool {
        let status = AVAudioApplication.shared.recordPermission
        if status == .granted { return true }

        return await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    // MARK: - Public API

    func configureAnchors(_ anchors: [StageAnchor]) {
        matcher = StageAnchorMatcher(anchors: anchors)
    }

    func resetAnchorState() {
        matcher.reset()
    }

    /// Start Stage Mode engine:
    /// - begins speech recognition + recording
    /// - writes audio to recordings directory
    func start(filenameBase: String) async {
        errorMessage = nil

        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            errorMessage = "Speech recognition not available."
            return
        }

        let speechOK = await requestSpeechPermissionIfNeeded()
        let micOK = await requestMicPermissionIfNeeded()
        guard speechOK && micOK else {
            errorMessage = "Speech or microphone permission not granted."
            return
        }

        do {
            try configureAudioSession()
            try startPipeline(filenameBase: filenameBase)
            isRunning = true
        } catch {
            errorMessage = "Stage engine start failed: \(error.localizedDescription)"
            stop()
        }
    }

    /// Stop and return recording metadata (if any).
    func stopAndFinalize() -> (url: URL, duration: TimeInterval, fileSize: Int64)? {
        defer { stop() }

        guard let url = recordingURL else { return nil }

        // finalize file
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

        levelTimer?.invalidate()
        levelTimer = nil
        timeTimer?.invalidate()
        timeTimer = nil

        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil

        if let engine = audioEngine {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }
        audioEngine = nil

        audioFile = nil
        recordingURL = nil
        currentFilename = nil
        startDate = nil
        audioLevel = 0
        currentTime = 0
    }

    // MARK: - Setup

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .measurement,
            options: [.defaultToSpeaker, .allowBluetoothHFP, .mixWithOthers]
        )
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func startPipeline(filenameBase: String) throws {
        // Clean any old pipeline
        stop()

        // Fresh engine
        let engine = AVAudioEngine()
        self.audioEngine = engine

        // Recording destination
        let filename = Performance.generateFilename(for: filenameBase)
            .replacingOccurrences(of: ".m4a", with: ".caf") // engine writes CAF reliably
        self.currentFilename = filename

        let url = Performance.recordingsDirectory.appendingPathComponent(filename)
        self.recordingURL = url

        // Speech request
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false
        if #available(iOS 16.0, *) { request.taskHint = .dictation }
        self.recognitionRequest = request

        // Prepare file settings using the engine's input format
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        // Write uncompressed PCM to CAF (very reliable under load)
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        self.audioFile = file

        // Tap mic ONCE: feed both speech recognition + recording + metering
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self else { return }

            // Write audio
            do {
                try self.audioFile?.write(from: buffer)
            } catch {
                Task { @MainActor in
                    self.errorMessage = "Recording write failed: \(error.localizedDescription)"
                }
            }

            // Feed speech
            self.recognitionRequest?.append(buffer)

            // Meter
            let level = Self.computeLevel(from: buffer)
            Task { @MainActor in
                self.audioLevel = level
            }
        }

        engine.prepare()
        try engine.start()

        startDate = Date()
        startTimers()

        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            Task { @MainActor in
                if let error {
                    // Don't hard-stop; surface message
                    self.errorMessage = error.localizedDescription
                    return
                }
                guard let result else { return }

                self.isListening = true
                let text = result.bestTranscription.formattedString
                self.partialTranscript = text

                // Anchors
                if let match = self.matcher.ingest(transcript: text) {
                    self.onAnchor?(match.anchor, match.confidence)
                }
            }
        }
    }

    private func startTimers() {
        weak var weakSelf = self

        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            guard let self = weakSelf else { return }
            Task { @MainActor in
                // audioLevel updates in tap; this timer just keeps UI cadence stable
                _ = self.audioLevel
            }
        }
        if let timer = levelTimer { RunLoop.main.add(timer, forMode: .common) }

        timeTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            guard let self = weakSelf else { return }
            Task { @MainActor in
                if let start = self.startDate, self.isRunning {
                    self.currentTime = Date().timeIntervalSince(start)
                }
            }
        }
        if let timer = timeTimer { RunLoop.main.add(timer, forMode: .common) }
    }

    // MARK: - Metering

    private static func computeLevel(from buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData?[0] else { return 0 }

        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return 0 }

        // RMS
        var sumSquares: Float = 0
        for i in 0..<frameLength {
            let sample = channelData[i]
            sumSquares += sample * sample
        }
        let rms = sqrt(sumSquares / Float(frameLength))

        // Map RMS to 0...1
        // (tuned to feel similar to the old recorder meter)
        let clamped = min(max(rms * 6.0, 0), 1)
        return clamped
    }

    // MARK: - Formatting

    var formattedTime: String {
        let minutes = Int(currentTime) / 60
        let seconds = Int(currentTime) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
