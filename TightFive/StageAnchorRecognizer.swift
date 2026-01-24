import Foundation
import Speech
import AVFoundation
import Combine

/// Speech recognition for Stage Mode anchor phrase detection.
///
/// Listens for anchor phrases and notifies when detected.
/// Handles continuous recognition with automatic restarts.
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
    
    // Session management
    private var isRestarting = false
    private var restartWorkItem: DispatchWorkItem?
    
    // Buffer for continuous recognition
    private var transcriptBuffer = ""
    private let bufferResetInterval: TimeInterval = 5.0
    private var bufferResetTimer: Timer?
    
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
        detectedAnchorIds.removeAll()
        transcriptBuffer = ""
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
            startBufferResetTimer()
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
        
        stopBufferResetTimer()
        cleanupRecognition()
    }
    
    @MainActor
    func resetDetectedAnchors() {
        detectedAnchorIds.removeAll()
    }
    
    // MARK: - Private Methods
    
    private func startRecognitionSession() throws {
        // Clean up any existing session first
        cleanupRecognition()
        
        // Create fresh audio engine
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            throw RecognitionError.audioConfigFailed
        }
        
        // Configure audio session for recording alongside playback
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetoothHFP, .mixWithOthers])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else {
            throw RecognitionError.audioConfigFailed
        }
        
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false
        
        // Set up audio tap
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Check format validity
        guard recordingFormat.sampleRate > 0 && recordingFormat.channelCount > 0 else {
            throw RecognitionError.audioConfigFailed
        }
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        
        // Start engine
        audioEngine.prepare()
        try audioEngine.start()
        
        // Start recognition task
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
        // Ignore errors during restart
        if isRestarting { return }
        
        if let error = error {
            let nsError = error as NSError
            
            // Ignore "no speech detected" errors - just restart
            if nsError.domain == "kAFAssistantErrorDomain" {
                if nsError.code == 1110 || nsError.code == 1107 {
                    scheduleRestart()
                    return
                }
            }
            
            // For other errors, log but try to continue
            print("Recognition error: \(error.localizedDescription)")
            scheduleRestart()
            return
        }
        
        guard let result = result else { return }
        
        let transcript = result.bestTranscription.formattedString
        lastTranscript = transcript
        
        // Add to buffer for better matching
        if !transcript.isEmpty {
            transcriptBuffer = transcript
            checkForAnchorMatch(in: transcriptBuffer)
        }
        
        // If final, schedule restart for continuous recognition
        if result.isFinal && isListening {
            scheduleRestart()
        }
    }
    
    @MainActor
    private func checkForAnchorMatch(in transcript: String) {
        guard let match = anchors.findMatch(for: transcript, threshold: 0.5) else {
            return
        }
        
        // Avoid duplicate detections
        guard !detectedAnchorIds.contains(match.anchor.id) else {
            return
        }
        
        detectedAnchorIds.insert(match.anchor.id)
        onAnchorDetected?(match.anchor, match.confidence)
        
        // Clear buffer after successful match to avoid re-triggering
        transcriptBuffer = ""
    }
    
    @MainActor
    private func scheduleRestart() {
        guard isListening && !isRestarting else { return }
        isRestarting = true
        
        // Cancel any pending restart
        restartWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                guard let self = self, self.isListening else {
                    self?.isRestarting = false
                    return
                }
                
                do {
                    try self.startRecognitionSession()
                    self.isRestarting = false
                } catch {
                    self.isRestarting = false
                    // If restart fails, try again after longer delay
                    if self.isListening {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            Task { @MainActor in
                                if self.isListening {
                                    self.scheduleRestart()
                                }
                            }
                        }
                    }
                }
            }
        }
        
        restartWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
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
    
    @MainActor
    private func startBufferResetTimer() {
        stopBufferResetTimer()
        bufferResetTimer = Timer.scheduledTimer(withTimeInterval: bufferResetInterval, repeats: true) { [weak self] _ in
            self?.transcriptBuffer = ""
        }
        if let timer = bufferResetTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    @MainActor
    private func stopBufferResetTimer() {
        bufferResetTimer?.invalidate()
        bufferResetTimer = nil
    }
    
    deinit {
        restartWorkItem?.cancel()
        bufferResetTimer?.invalidate()
    }
}
