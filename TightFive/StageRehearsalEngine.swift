import Foundation
import SwiftUI
import SwiftData
import Foundation
import AVFoundation
import Combine
@preconcurrency import Speech

/// Engine for Stage Rehearsal mode - all the recognition without recording.
///
/// **Purpose:**
/// - Test voice recognition before actual performance
/// - Verify anchor/exit phrase detection
/// - Check audio levels and microphone setup
/// - Build confidence with automatic transitions
/// - No recording, no performance saved
///
/// **Enhanced Feedback:**
/// - Real-time confidence scores for anchor/exit detection
/// - Audio level monitoring with visual feedback
/// - Per-card recognition analytics
/// - Transition success tracking
@MainActor
final class StageRehearsalEngine: ObservableObject {
    
    // MARK: - Published State
    
    @Published private(set) var cards: [CueCard] = []
    @Published private(set) var currentCardIndex: Int = 0
    @Published private(set) var isRunning: Bool = false
    @Published private(set) var isListening: Bool = false
    @Published private(set) var partialTranscript: String = ""
    @Published private(set) var audioLevel: Float = 0
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var errorMessage: String?
    
    // Enhanced recognition feedback for rehearsal
    @Published private(set) var exitPhraseConfidence: Double = 0.0
    @Published private(set) var anchorPhraseConfidence: Double = 0.0
    @Published private(set) var lastDetectionType: DetectionType?
    @Published private(set) var lastDetectionTimestamp: Date?
    
    // Audio quality indicators
    @Published private(set) var averageAudioLevel: Float = 0.0
    @Published private(set) var peakAudioLevel: Float = 0.0
    @Published private(set) var isAudioTooLow: Bool = false
    @Published private(set) var isAudioTooHigh: Bool = false
    
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
    
    // MARK: - Timers
    
    private var levelTimer: Timer?
    private var timeTimer: Timer?
    private var watchdogTimer: Timer?
    private var startDate: Date?
    
    // MARK: - Recognition State
    
    private var exitPhraseDetectedAt: Date?
    private let exitPhraseDebounce: TimeInterval = 1.5
    
    // MARK: - Rehearsal Analytics
    
    private(set) var analytics: RehearsalAnalytics = RehearsalAnalytics()
    
    // MARK: - Initialization
    
    init(localeIdentifier: String = "en-US") {
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier))
    }
    
    // MARK: - Configuration
    
    func configure(cards: [CueCard]) {
        self.cards = cards
        self.currentCardIndex = 0
        self.analytics = RehearsalAnalytics()
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
    
    // MARK: - Lifecycle
    
    func start() async {
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
            try startPipeline(recognizer: recognizer)
            
            isRunning = true
            isListening = false
            currentCardIndex = 0
            
            analytics.sessionStartTime = Date()
        } catch {
            errorMessage = "Rehearsal engine start failed: \(error.localizedDescription)"
            stop()
        }
    }
    
    func stop() -> RehearsalAnalytics {
        isRunning = false
        isListening = false
        
        analytics.sessionEndTime = Date()
        analytics.totalDuration = currentTime
        
        levelTimer?.invalidate(); levelTimer = nil
        timeTimer?.invalidate(); timeTimer = nil
        watchdogTimer?.invalidate(); watchdogTimer = nil
        
        cancelRecognitionOnly()
        
        if let engine = audioEngine {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }
        audioEngine = nil
        
        startDate = nil
        
        audioLevel = 0
        currentTime = 0
        partialTranscript = ""
        exitPhraseConfidence = 0.0
        anchorPhraseConfidence = 0.0
        lastDetectionType = nil
        
        return analytics
    }
    
    // MARK: - Navigation
    
    func advanceToNextCard(automatic: Bool = false) {
        guard hasNextCard else { return }
        
        let oldIndex = currentCardIndex
        currentCardIndex += 1
        
        // Track transition analytics
        if let startDate = startDate {
            let timestamp = Date().timeIntervalSince(startDate)
            analytics.recordTransition(
                from: oldIndex,
                to: currentCardIndex,
                timestamp: timestamp,
                wasAutomatic: automatic,
                exitConfidence: automatic ? exitPhraseConfidence : nil
            )
        }
        
        if automatic {
            exitPhraseDetectedAt = Date()
            hapticFeedback(style: .medium)
            analytics.automaticTransitions += 1
        } else {
            hapticFeedback(style: .light)
            analytics.manualTransitions += 1
        }
        
        if let card = currentCard {
            onCardTransition?(currentCardIndex, card)
        }
        
        // Reset recognition confidence indicators
        exitPhraseConfidence = 0.0
        anchorPhraseConfidence = 0.0
        lastDetectionType = nil
        lastDetectionTimestamp = nil
    }
    
    func goToPreviousCard() {
        guard hasPreviousCard else { return }
        
        let oldIndex = currentCardIndex
        currentCardIndex -= 1
        
        analytics.manualTransitions += 1
        
        hapticFeedback(style: .light)
        
        if let card = currentCard {
            onCardTransition?(currentCardIndex, card)
        }
        
        // Reset recognition state
        exitPhraseConfidence = 0.0
        anchorPhraseConfidence = 0.0
        lastDetectionType = nil
        lastDetectionTimestamp = nil
        exitPhraseDetectedAt = nil
    }
    
    func jumpToCard(index: Int) {
        guard index >= 0, index < cards.count else { return }
        
        currentCardIndex = index
        analytics.manualTransitions += 1
        
        hapticFeedback(style: .light)
        
        if let card = currentCard {
            onCardTransition?(currentCardIndex, card)
        }
        
        // Reset recognition state
        exitPhraseConfidence = 0.0
        anchorPhraseConfidence = 0.0
        lastDetectionType = nil
        lastDetectionTimestamp = nil
        exitPhraseDetectedAt = nil
    }
    
    // MARK: - Audio Session
    
    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .spokenAudio,
            options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP, .mixWithOthers]
        )
        
        try session.setPreferredIOBufferDuration(0.005)
        try session.setPreferredSampleRate(48000)
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        
        print("🎤 Rehearsal audio configured: \(session.sampleRate)Hz, \(session.ioBufferDuration * 1000)ms buffer")
    }
    
    // MARK: - Pipeline (No Recording)
    
    private func startPipeline(recognizer: SFSpeechRecognizer) throws {
        teardownPipelineOnly()
        
        let engine = AVAudioEngine()
        self.audioEngine = engine
        
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        startRecognitionOnly(recognizer: recognizer)
        
        // Install tap for audio level monitoring (no recording)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 256, format: inputFormat) { [weak self] buffer, _ in
            guard let self else { return }
            
            // Send to speech recognizer
            self.recognitionRequest?.append(buffer)
            
            // Compute audio level
            let level = Self.computeLevel(from: buffer)
            Task { @MainActor in
                self.audioLevel = level
                self.updateAudioQualityIndicators(level: level)
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
                    
                    // Ignore expected errors
                    if ns.domain == "kAFAssistantErrorDomain", ns.code == 1110 { return }
                    if ns.domain == "kLSRErrorDomain", ns.code == 301 { return }
                    
                    self.errorMessage = error.localizedDescription
                    self.analytics.recognitionErrors += 1
                    return
                }
                
                guard let result else { return }
                
                self.isListening = true
                
                let text = result.bestTranscription.formattedString
                self.partialTranscript = text
                
                // Get average confidence from segments
                let segments = result.bestTranscription.segments
                let avgConfidence = segments.isEmpty ? 0.5 :
                    segments.map { $0.confidence }.reduce(0, +) / Float(segments.count)
                
                self.processTranscript(text, overallConfidence: Double(avgConfidence))
                
                // Track analytics
                self.analytics.totalTranscriptionsReceived += 1
                self.analytics.confidenceScores.append(Double(avgConfidence))
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
    
    private func processTranscript(_ transcript: String, overallConfidence: Double) {
        guard let card = currentCard else { return }
        
        // Check for exit phrase (triggers next card)
        let exitResult = card.matchesExitPhrase(transcript)
        exitPhraseConfidence = exitResult.confidence
        
        if exitResult.matches {
            // Debounce: don't trigger too soon after last detection
            if let lastDetection = exitPhraseDetectedAt {
                let timeSinceLastDetection = Date().timeIntervalSince(lastDetection)
                if timeSinceLastDetection < exitPhraseDebounce {
                    return
                }
            }
            
            lastDetectionType = .exit
            lastDetectionTimestamp = Date()
            
            print("✅ EXIT detected (confidence: \(String(format: "%.2f", exitResult.confidence)))")
            
            // Record exit phrase detection in analytics
            analytics.recordExitPhraseDetection(
                cardIndex: currentCardIndex,
                confidence: exitResult.confidence,
                transcript: transcript
            )
            
            advanceToNextCard(automatic: true)
            return
        }
        
        // Check for anchor phrase (confirmation we're in this card)
        let anchorResult = card.matchesAnchorPhrase(transcript)
        anchorPhraseConfidence = anchorResult.confidence
        
        if anchorResult.matches {
            lastDetectionType = .anchor
            lastDetectionTimestamp = Date()
            
            print("✅ ANCHOR confirmed (confidence: \(String(format: "%.2f", anchorResult.confidence)))")
            
            // Record anchor phrase detection in analytics
            analytics.recordAnchorPhraseDetection(
                cardIndex: currentCardIndex,
                confidence: anchorResult.confidence,
                transcript: transcript
            )
        }
        
        // Record per-card recognition data
        analytics.recordRecognitionAttempt(
            cardIndex: currentCardIndex,
            confidence: overallConfidence,
            exitConfidence: exitPhraseConfidence,
            anchorConfidence: anchorPhraseConfidence
        )
    }
    
    // MARK: - Audio Quality Monitoring
    
    private func updateAudioQualityIndicators(level: Float) {
        // Track peak
        if level > peakAudioLevel {
            peakAudioLevel = level
        }
        
        // Update rolling average
        let alpha: Float = 0.1 // Smoothing factor
        averageAudioLevel = alpha * level + (1 - alpha) * averageAudioLevel
        
        // Check thresholds
        isAudioTooLow = averageAudioLevel < 0.05
        isAudioTooHigh = averageAudioLevel > 0.85
        
        // Track in analytics
        analytics.audioLevelSamples.append(Double(level))
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

// MARK: - Rehearsal Analytics

struct RehearsalAnalytics {
    var sessionStartTime: Date?
    var sessionEndTime: Date?
    var totalDuration: TimeInterval = 0
    
    // Transition tracking
    var automaticTransitions: Int = 0
    var manualTransitions: Int = 0
    var transitions: [(from: Int, to: Int, timestamp: TimeInterval, wasAutomatic: Bool, exitConfidence: Double?)] = []
    
    // Recognition performance
    var totalTranscriptionsReceived: Int = 0
    var recognitionErrors: Int = 0
    var confidenceScores: [Double] = []
    
    // Per-card analytics
    struct CardAnalytics {
        var cardIndex: Int
        var anchorDetections: [(confidence: Double, transcript: String)] = []
        var exitDetections: [(confidence: Double, transcript: String)] = []
        var recognitionAttempts: [(confidence: Double, exitConf: Double, anchorConf: Double)] = []
        
        var bestAnchorConfidence: Double {
            anchorDetections.map { $0.confidence }.max() ?? 0.0
        }
        
        var bestExitConfidence: Double {
            exitDetections.map { $0.confidence }.max() ?? 0.0
        }
        
        var averageRecognitionConfidence: Double {
            guard !recognitionAttempts.isEmpty else { return 0.0 }
            return recognitionAttempts.map { $0.confidence }.reduce(0, +) / Double(recognitionAttempts.count)
        }
        
        var hadSuccessfulAnchor: Bool {
            !anchorDetections.isEmpty
        }
        
        var hadSuccessfulExit: Bool {
            !exitDetections.isEmpty
        }
    }
    
    var cardAnalytics: [Int: CardAnalytics] = [:]
    
    // Audio quality
    var audioLevelSamples: [Double] = []
    
    // MARK: - Recording Methods
    
    mutating func recordTransition(from: Int, to: Int, timestamp: TimeInterval, wasAutomatic: Bool, exitConfidence: Double?) {
        transitions.append((from: from, to: to, timestamp: timestamp, wasAutomatic: wasAutomatic, exitConfidence: exitConfidence))
    }
    
    mutating func recordAnchorPhraseDetection(cardIndex: Int, confidence: Double, transcript: String) {
        if cardAnalytics[cardIndex] == nil {
            cardAnalytics[cardIndex] = CardAnalytics(cardIndex: cardIndex)
        }
        cardAnalytics[cardIndex]?.anchorDetections.append((confidence: confidence, transcript: transcript))
    }
    
    mutating func recordExitPhraseDetection(cardIndex: Int, confidence: Double, transcript: String) {
        if cardAnalytics[cardIndex] == nil {
            cardAnalytics[cardIndex] = CardAnalytics(cardIndex: cardIndex)
        }
        cardAnalytics[cardIndex]?.exitDetections.append((confidence: confidence, transcript: transcript))
    }
    
    mutating func recordRecognitionAttempt(cardIndex: Int, confidence: Double, exitConfidence: Double, anchorConfidence: Double) {
        if cardAnalytics[cardIndex] == nil {
            cardAnalytics[cardIndex] = CardAnalytics(cardIndex: cardIndex)
        }
        cardAnalytics[cardIndex]?.recognitionAttempts.append((confidence: confidence, exitConf: exitConfidence, anchorConf: anchorConfidence))
    }
    
    // MARK: - Computed Properties
    
    var totalTransitions: Int {
        automaticTransitions + manualTransitions
    }
    
    var automaticTransitionPercentage: Double {
        guard totalTransitions > 0 else { return 0.0 }
        return Double(automaticTransitions) / Double(totalTransitions) * 100
    }
    
    var averageConfidence: Double {
        guard !confidenceScores.isEmpty else { return 0.0 }
        return confidenceScores.reduce(0, +) / Double(confidenceScores.count)
    }
    
    var averageAudioLevel: Double {
        guard !audioLevelSamples.isEmpty else { return 0.0 }
        return audioLevelSamples.reduce(0, +) / Double(audioLevelSamples.count)
    }
    
    var peakAudioLevel: Double {
        audioLevelSamples.max() ?? 0.0
    }
    
    var cardsWithSuccessfulRecognition: Int {
        cardAnalytics.values.filter { $0.hadSuccessfulAnchor || $0.hadSuccessfulExit }.count
    }
    
    var cardsWithProblems: [(cardIndex: Int, issues: [String])] {
        var problematicCards: [(Int, [String])] = []
        
        for (index, analytics) in cardAnalytics.sorted(by: { $0.key < $1.key }) {
            var issues: [String] = []
            
            if !analytics.hadSuccessfulAnchor {
                issues.append("Anchor phrase not detected")
            }
            
            if !analytics.hadSuccessfulExit {
                issues.append("Exit phrase not detected")
            }
            
            if analytics.averageRecognitionConfidence < 0.5 {
                issues.append("Low recognition confidence (\(Int(analytics.averageRecognitionConfidence * 100))%)")
            }
            
            if !issues.isEmpty {
                problematicCards.append((index, issues))
            }
        }
        
        return problematicCards
    }
    
    // MARK: - Recommendations
    
    var recommendations: [String] {
        var suggestions: [String] = []
        
        // Audio level recommendations
        if averageAudioLevel < 0.1 {
            suggestions.append("🎤 Audio levels are low. Speak louder or move closer to the microphone.")
        } else if averageAudioLevel > 0.8 {
            suggestions.append("🎤 Audio levels are high. You may be too close to the microphone or speaking too loudly.")
        }
        
        // Recognition confidence recommendations
        if averageConfidence < 0.5 {
            suggestions.append("🗣️ Overall recognition confidence is low. Ensure clear pronunciation and minimal background noise.")
        }
        
        // Automatic transition recommendations
        if totalTransitions > 3 && automaticTransitionPercentage < 30 {
            suggestions.append("🔄 Most transitions were manual. Consider refining your anchor and exit phrases for better automatic detection.")
        } else if automaticTransitionPercentage > 80 {
            suggestions.append("✅ Excellent automatic transition rate! Your phrases are working well.")
        }
        
        // Per-card recommendations
        let problematic = cardsWithProblems
        if !problematic.isEmpty && problematic.count <= 3 {
            for (cardIndex, issues) in problematic {
                let cardNum = cardIndex + 1
                suggestions.append("📝 Card \(cardNum): \(issues.joined(separator: ", "))")
            }
        } else if problematic.count > 3 {
            suggestions.append("📝 \(problematic.count) cards had recognition issues. Review anchor and exit phrases.")
        }
        
        return suggestions
    }
}
