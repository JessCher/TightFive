import SwiftUI
import Foundation
import Combine
@preconcurrency import Speech
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
    
    // MARK: - AI Features (Added)
    
    /// Acoustic analyzer for real-time feature detection
    private var acousticAnalyzer = AcousticAnalyzer()
    
    /// Callback for acoustic features (emphasis, questions, etc.)
    var onAcousticFeatures: ((AcousticAnalyzer.AcousticFeatures) -> Void)?
    
    /// Analytics data collection (for post-performance analysis)
    private var analyticsDataPoints: [(timestamp: TimeInterval, confidence: Double, lineIndex: Int)] = []
    
    /// Current line index (tracked for analytics)
    var currentLineIndex: Int = 0

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

    /// Throttle audio level updates to reduce UI redraws (update every ~100ms instead of every buffer)
    private var audioLevelUpdateCounter: Int = 0
    private let audioLevelUpdateInterval: Int = 20  // Update every 20 buffers (~100ms at 256 samples/48kHz)

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

    func stopAndFinalize() -> (url: URL, duration: TimeInterval, fileSize: Int64, insights: [PerformanceAnalytics.Insight])? {
        defer { stop() }

        guard let url = recordingURL else { return nil }

        audioFile = nil

        let duration = currentTime

        var fileSize: Int64 = 0
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? Int64 {
            fileSize = size
        }
        
        // MARK: - AI: Generate Performance Insights
        let insights = PerformanceAnalytics.analyze(
            transcript: partialTranscript,
            confidenceData: analyticsDataPoints,
            totalLines: max(1, currentLineIndex),
            duration: duration
        )
        
        return (url, duration, fileSize, insights)
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
        
        // Reset AI components
        acousticAnalyzer.reset()
        analyticsDataPoints.removeAll()
        currentLineIndex = 0
    }

    // MARK: - Audio Session

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .spokenAudio,
            options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP, .mixWithOthers]
        )
        
        // Request minimum latency for real-time performance
        try session.setPreferredIOBufferDuration(0.005) // 5ms buffer (elite tier)
        
        // Request highest sample rate available
        try session.setPreferredSampleRate(48000)
        
        // Activate with high priority
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
            .replacingOccurrences(of: ".caf", with: ".m4a") // Use compressed M4A

        let url = Performance.recordingsDirectory.appendingPathComponent(filename)
        self.recordingURL = url

        // Prepare file using input format settings
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        // Create optimal format for recording (AAC-LC, 48kHz, mono for voice)
        let recordingFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 48000,
            channels: 1,
            interleaved: false
        )!
        
        // Create AAC settings for high-quality compressed recording
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 48000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            AVEncoderBitRateKey: 96000 // 96kbps AAC-LC (broadcast quality)
        ]

        self.audioFile = try AVAudioFile(forWriting: url, settings: settings)

        // Start recognition (request + task)
        startRecognitionOnly(recognizer: recognizer)

        // Converter for format conversion (input → recording format)
        guard let converter = AVAudioConverter(from: inputFormat, to: recordingFormat) else {
            throw NSError(domain: "StageTeleprompterEngine", code: -1, 
                         userInfo: [NSLocalizedDescriptionKey: "Failed to create audio converter"])
        }

        // Tap mic with adaptive buffer size (256 frames = ~5ms at 48kHz for ultra-low latency)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 256, format: inputFormat) { [weak self] buffer, _ in
            guard let self else { return }

            // Convert to recording format
            let frameCapacity = AVAudioFrameCount(recordingFormat.sampleRate * Double(buffer.frameLength) / inputFormat.sampleRate)
            guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: recordingFormat, frameCapacity: frameCapacity) else { return }
            
            var error: NSError?
            let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }
            
            converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)
            
            // Record converted audio
            do { try self.audioFile?.write(from: convertedBuffer) }
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

            // Meter (throttled to reduce UI redraws - ~10 updates/sec instead of ~200)
            self.audioLevelUpdateCounter += 1
            if self.audioLevelUpdateCounter >= self.audioLevelUpdateInterval {
                self.audioLevelUpdateCounter = 0
                let level = Self.computeLevel(from: buffer)
                Task { @MainActor in
                    self.audioLevel = level
                }
            }

            // MARK: - AI: Acoustic Analysis (Real-time, battery-optimized)
            // Only analyze every 20th buffer (~100ms) to reduce CPU load
            if self.audioLevelUpdateCounter == 0 {
                Task { @MainActor in
                    let features = self.acousticAnalyzer.analyze(buffer: buffer)
                    self.onAcousticFeatures?(features)
                }
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
                
                // MARK: - AI: Analytics Data Collection
                // Collect confidence data for post-performance analysis
                if let startDate = self.startDate {
                    let timestamp = Date().timeIntervalSince(startDate)
                    // Use average confidence of segments (more stable than per-word)
                    let segments = result.bestTranscription.segments
                    let avgConfidence = segments.isEmpty ? 0.5 : 
                        segments.map { $0.confidence }.reduce(0, +) / Float(segments.count)
                    
                    self.analyticsDataPoints.append((
                        timestamp: timestamp,
                        confidence: Double(avgConfidence),
                        lineIndex: self.currentLineIndex
                    ))
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
