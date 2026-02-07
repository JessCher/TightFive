import Foundation
import SwiftUI
import AVFoundation
import Combine
@preconcurrency import Speech

/// Engine for cue card-based Stage Mode with dual-phrase recognition.
///
/// **Architecture:**
/// - Display ONE card at a time (full screen, auto-scaled)
/// - Listen for EXIT phrase of current card → triggers transition to next
/// - Optionally validate with ANCHOR phrase of new card
/// - Manual swipe gestures for fallback control
///
/// **Recognition Strategy:**
/// - Bounded context: only current card's phrases matter
/// - Higher confidence from focused recognition
/// - Clear state machine: listening → exit detected → transition → listening
@MainActor
final class CueCardEngine: ObservableObject {
    
    // MARK: - Published State
    
    @Published private(set) var cards: [CueCard] = []
    @Published private(set) var currentCardIndex: Int = 0
    @Published private(set) var isRunning: Bool = false
    @Published private(set) var isListening: Bool = false
    @Published private(set) var partialTranscript: String = ""
    @Published private(set) var audioLevel: Float = 0
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var errorMessage: String?
    
    // Recognition feedback
    @Published private(set) var exitPhraseConfidence: Double = 0.0
    @Published private(set) var anchorPhraseConfidence: Double = 0.0
    @Published private(set) var lastDetectionType: DetectionType?
    
    enum DetectionType {
        case anchor
        case exit
    }
    
    // MARK: - Callbacks
    
    var onCardTransition: ((Int, CueCard) -> Void)?
    
    // MARK: - Audio & Recognition
    
    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var recordingURL: URL?
    
    // MARK: - Timers
    
    private var levelTimer: Timer?
    private var timeTimer: Timer?
    private var watchdogTimer: Timer?
    private var startDate: Date?
    
    // MARK: - Recognition State
    
    private var exitPhraseDetectedAt: Date?
    private let exitPhraseDebounce: TimeInterval = 1.5 // Wait 1.5s before allowing another exit detection

    /// Throttle audio level updates to reduce UI redraws (update every ~100ms instead of every buffer)
    private var audioLevelUpdateCounter: Int = 0
    private let audioLevelUpdateInterval: Int = 20  // Update every 20 buffers (~100ms at 256 samples/48kHz)

    // MARK: - Analytics
    
    private var analyticsDataPoints: [(timestamp: TimeInterval, confidence: Double, cardIndex: Int)] = []
    private var transitionTimestamps: [(from: Int, to: Int, timestamp: TimeInterval, wasAutomatic: Bool)] = []
    
    // MARK: - Initialization
    
    init(localeIdentifier: String = "en-US") {
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier))
    }
    
    // MARK: - Configuration
    
    func configure(cards: [CueCard]) {
        self.cards = cards
        self.currentCardIndex = 0
    }
    
    // MARK: - Computed Properties
    
    var currentCard: CueCard? {
        guard currentCardIndex >= 0, currentCardIndex < cards.count else { return nil }
        return cards[currentCardIndex]
    }
    
    var hasNextCard: Bool {
        currentCardIndex < cards.count - 1
    }
    
    var hasPreviousCard: Bool {
        currentCardIndex > 0
    }
    
    var progressFraction: Double {
        guard !cards.isEmpty else { return 0.0 }
        return Double(currentCardIndex) / Double(cards.count - 1)
    }
    
    var formattedTime: String {
        let minutes = Int(currentTime) / 60
        let seconds = Int(currentTime) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var formattedProgress: String {
        "\(currentCardIndex + 1) / \(cards.count)"
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
    
    // MARK: - Lifecycle
    
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
            currentCardIndex = 0
        } catch {
            errorMessage = "Cue card engine start failed: \(error.localizedDescription)"
            stop()
        }
    }
    
    func stopAndFinalize() -> (url: URL, duration: TimeInterval, fileSize: Int64, insights: [String])? {
        defer { stop() }
        
        guard let url = recordingURL else { return nil }
        
        audioFile = nil
        
        let duration = currentTime
        
        var fileSize: Int64 = 0
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? Int64 {
            fileSize = size
        }
        
        // Generate insights
        let insights = generateInsights()
        
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
        exitPhraseConfidence = 0.0
        anchorPhraseConfidence = 0.0
        lastDetectionType = nil
        
        analyticsDataPoints.removeAll()
        transitionTimestamps.removeAll()
    }
    
    // MARK: - Navigation
    
    func advanceToNextCard(automatic: Bool = false) {
        guard hasNextCard else { return }
        
        let oldIndex = currentCardIndex
        currentCardIndex += 1
        
        if let startDate = startDate {
            let timestamp = Date().timeIntervalSince(startDate)
            transitionTimestamps.append((from: oldIndex, to: currentCardIndex, timestamp: timestamp, wasAutomatic: automatic))
        }
        
        if automatic {
            exitPhraseDetectedAt = Date()
            hapticFeedback(style: .medium)
        } else {
            hapticFeedback(style: .light)
        }
        
        if let card = currentCard {
            onCardTransition?(currentCardIndex, card)
        }
        
        // Reset recognition confidence indicators
        exitPhraseConfidence = 0.0
        anchorPhraseConfidence = 0.0
        lastDetectionType = nil
    }
    
    func goToPreviousCard() {
        guard hasPreviousCard else { return }
        
        let oldIndex = currentCardIndex
        currentCardIndex -= 1
        
        if let startDate = startDate {
            let timestamp = Date().timeIntervalSince(startDate)
            transitionTimestamps.append((from: oldIndex, to: currentCardIndex, timestamp: timestamp, wasAutomatic: false))
        }
        
        hapticFeedback(style: .light)
        
        if let card = currentCard {
            onCardTransition?(currentCardIndex, card)
        }
        
        // Reset recognition confidence indicators
        exitPhraseConfidence = 0.0
        anchorPhraseConfidence = 0.0
        lastDetectionType = nil
        exitPhraseDetectedAt = nil // Allow exit detection on this card
    }
    
    func jumpToCard(index: Int) {
        guard index >= 0, index < cards.count else { return }
        
        let oldIndex = currentCardIndex
        currentCardIndex = index
        
        if let startDate = startDate {
            let timestamp = Date().timeIntervalSince(startDate)
            transitionTimestamps.append((from: oldIndex, to: currentCardIndex, timestamp: timestamp, wasAutomatic: false))
        }
        
        hapticFeedback(style: .light)
        
        if let card = currentCard {
            onCardTransition?(currentCardIndex, card)
        }
        
        // Reset recognition state
        exitPhraseConfidence = 0.0
        anchorPhraseConfidence = 0.0
        lastDetectionType = nil
        exitPhraseDetectedAt = nil
    }
    
    // MARK: - Audio Session
    
    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .spokenAudio,
            options: [.defaultToSpeaker, AVAudioSession.CategoryOptions.allowBluetoothHFP, .allowBluetoothA2DP, .mixWithOthers]
        )
        
        try session.setPreferredIOBufferDuration(0.005)
        try session.setPreferredSampleRate(48000)
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        
    }
    
    // MARK: - Pipeline
    
    private func startPipeline(filenameBase: String, recognizer: SFSpeechRecognizer) throws {
        teardownPipelineOnly()

        let shouldRecord = CueCardSettingsStore.shared.recordingEnabled

        let engine = AVAudioEngine()
        self.audioEngine = engine

        var converter: AVAudioConverter?

        if shouldRecord {
            try FileManager.default.createDirectory(
                at: Performance.recordingsDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )

            let safeBase = filenameBase.isEmpty ? "Performance" : filenameBase
            let filename = Performance.generateFilename(for: safeBase)
                .replacingOccurrences(of: ".caf", with: ".m4a")

            let url = Performance.recordingsDirectory.appendingPathComponent(filename)
            self.recordingURL = url

            let recordingFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: 48000,
                channels: 1,
                interleaved: false
            )!

            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 48000,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
                AVEncoderBitRateKey: 96000
            ]

            self.audioFile = try AVAudioFile(forWriting: url, settings: settings)

            let inputNode = engine.inputNode
            let inputFormat = inputNode.outputFormat(forBus: 0)

            guard let conv = AVAudioConverter(from: inputFormat, to: recordingFormat) else {
                throw NSError(domain: "CueCardEngine", code: -1,
                             userInfo: [NSLocalizedDescriptionKey: "Failed to create audio converter"])
            }
            converter = conv
        }

        startRecognitionOnly(recognizer: recognizer)

        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 256, format: inputFormat) { [weak self] buffer, _ in
            guard let self else { return }

            // Write to audio file only if recording is enabled
            if shouldRecord, let converter {
                let recordingFormat = converter.outputFormat
                let frameCapacity = AVAudioFrameCount(recordingFormat.sampleRate * Double(buffer.frameLength) / inputFormat.sampleRate)
                guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: recordingFormat, frameCapacity: frameCapacity) else { return }

                var error: NSError?
                let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
                    outStatus.pointee = .haveData
                    return buffer
                }

                converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)

                do { try self.audioFile?.write(from: convertedBuffer) }
                catch {
                    Task { @MainActor in
                        self.errorMessage = "Recording write failed: \(error.localizedDescription)"
                    }
                }
            }

            // Always feed speech recognition
            self.recognitionRequest?.append(buffer)

            // Meter (throttled to reduce UI redraws - ~10 updates/sec instead of ~200)
            self.audioLevelUpdateCounter += 1
            if self.audioLevelUpdateCounter >= self.audioLevelUpdateInterval {
                self.audioLevelUpdateCounter = 0
                let level = Self.computeLevel(from: buffer)
                Task { @MainActor in
                    self.audioLevel = level
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
    
    // MARK: - Recognition
    
    private func startRecognitionOnly(recognizer: SFSpeechRecognizer) {
        cancelRecognitionOnly()
        
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        
        if #available(iOS 16.0, *) {
            request.taskHint = .dictation
        }
        
        // Provide current card's phrases as contextual hints
        if let card = currentCard {
            request.contextualStrings = [card.anchorPhrase, card.exitPhrase]
        }
        
        recognitionRequest = request
        
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            Task { @MainActor in
                if let error {
                    let ns = error as NSError
                    
                    if ns.domain == "kAFAssistantErrorDomain", ns.code == 1110 { return }
                    if ns.domain == "kLSRErrorDomain", ns.code == 301 { return }
                    
                    self.errorMessage = error.localizedDescription
                    return
                }
                
                guard let result else { return }
                
                self.isListening = true
                
                let text = result.bestTranscription.formattedString
                self.partialTranscript = text
                
                self.processTranscript(text)
                
                // Analytics
                if let startDate = self.startDate {
                    let timestamp = Date().timeIntervalSince(startDate)
                    let segments = result.bestTranscription.segments
                    let avgConfidence = segments.isEmpty ? 0.5 :
                        segments.map { $0.confidence }.reduce(0, +) / Float(segments.count)
                    
                    self.analyticsDataPoints.append((
                        timestamp: timestamp,
                        confidence: Double(avgConfidence),
                        cardIndex: self.currentCardIndex
                    ))
                }
            }
        }
    }
    
    private func cancelRecognitionOnly() {
        recognitionTask?.cancel()
        recognitionTask = nil
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        isListening = false
    }
    
    // MARK: - Transcript Processing
    
    private func processTranscript(_ transcript: String) {
        guard let card = currentCard else { return }
        
        // Check for exit phrase (triggers next card)
        let exitResult = card.matchesExitPhrase(transcript)
        // Apply display boost to raw confidence for better visual feedback
        exitPhraseConfidence = boostConfidenceForDisplay(exitResult.confidence)
        
        if exitResult.matches {
            // Debounce: don't trigger too soon after last detection
            if let lastDetection = exitPhraseDetectedAt {
                let timeSinceLastDetection = Date().timeIntervalSince(lastDetection)
                if timeSinceLastDetection < exitPhraseDebounce {
                    return
                }
            }
            
            lastDetectionType = .exit
            advanceToNextCard(automatic: true)
            return
        }
        
        // Check for anchor phrase (confirmation we're in this card)
        let anchorResult = card.matchesAnchorPhrase(transcript)
        // Apply display boost to raw confidence for better visual feedback
        anchorPhraseConfidence = boostConfidenceForDisplay(anchorResult.confidence)
        
        if anchorResult.matches {
            lastDetectionType = .anchor
        }
    }
    
    // MARK: - Confidence Boosting
    
    /// Apply a display curve to raw confidence scores for better visual feedback.
    /// 
    /// The raw confidence is perfect for detection thresholds, but can appear low in UI.
    /// This function transforms the confidence for display purposes only, making successful
    /// matches appear more confident without affecting the underlying detection logic.
    ///
    /// - Parameter rawConfidence: The raw match confidence (0.0 - 1.0)
    /// - Returns: Boosted confidence for display (0.0 - 1.0)
    private func boostConfidenceForDisplay(_ rawConfidence: Double) -> Double {
        // Apply an exponential curve that:
        // - Keeps very low scores low (< 0.3 stays mostly the same)
        // - Boosts medium-to-high scores significantly (0.5 -> 0.75, 0.6 -> 0.85, 0.7 -> 0.92)
        // - Approaches 1.0 for high scores
        
        // Use a power curve: confidence^0.6 gives a nice boost
        let boosted = pow(rawConfidence, 0.6)
        
        // Additionally, if confidence is above the detection threshold, add a bonus
        // This makes successful detections show even higher confidence
        let exitThreshold = CueCardSettingsStore.shared.exitPhraseSensitivity
        let anchorThreshold = CueCardSettingsStore.shared.anchorPhraseSensitivity
        let threshold = min(exitThreshold, anchorThreshold)
        
        if rawConfidence >= threshold {
            // Add a bonus that scales with how far above threshold we are
            let aboveThreshold = (rawConfidence - threshold) / (1.0 - threshold)
            let bonus = aboveThreshold * 0.15 // Up to 15% bonus
            return min(boosted + bonus, 1.0)
        }
        
        return boosted
    }
    
    // MARK: - Timers
    
    private func startTimers(recognizer: SFSpeechRecognizer) {
        levelTimer?.invalidate()
        timeTimer?.invalidate()
        watchdogTimer?.invalidate()
        
        nonisolated(unsafe) let safeRecognizer = recognizer
        
        timeTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                if let start = self.startDate, self.isRunning {
                    self.currentTime = Date().timeIntervalSince(start)
                }
            }
        }
        if let t = timeTimer { RunLoop.main.add(t, forMode: .common) }
        
        watchdogTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self, safeRecognizer] _ in
            guard let self else { return }
            Task { @MainActor in
                guard self.isRunning else { return }
                guard let start = self.startDate else { return }
                
                let age = Date().timeIntervalSince(start)
                
                if age > 2.0, self.partialTranscript.isEmpty, self.audioLevel > 0.05 {
                    self.errorMessage = "Restarting speech…"
                    self.startRecognitionOnly(recognizer: safeRecognizer)
                }
            }
        }
        if let t = watchdogTimer { RunLoop.main.add(t, forMode: .common) }
    }
    
    // MARK: - Analytics
    
    private func generateInsights() -> [String] {
        var insights: [String] = []
        
        // Automatic transitions
        let automaticTransitions = transitionTimestamps.filter { $0.wasAutomatic }.count
        let totalTransitions = transitionTimestamps.count
        
        if totalTransitions > 0 {
            let autoPercentage = Double(automaticTransitions) / Double(totalTransitions) * 100
            insights.append("Automatic transitions: \(automaticTransitions)/\(totalTransitions) (\(Int(autoPercentage))%)")
        }
        
        // Average confidence
        if !analyticsDataPoints.isEmpty {
            let avgConfidence = analyticsDataPoints.map { $0.confidence }.reduce(0, +) / Double(analyticsDataPoints.count)
            insights.append("Average recognition confidence: \(Int(avgConfidence * 100))%")
        }
        
        return insights
    }
    
    // MARK: - Helpers
    
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
    
    private func hapticFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}
