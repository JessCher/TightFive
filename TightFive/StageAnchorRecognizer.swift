import Foundation
import Speech
import AVFoundation
import Combine

/// Speech recognition for Stage Mode anchor phrase detection.
///
/// **CRITICAL FIXES FOR MULTI-ANCHOR DETECTION:**
/// - Immediate buffer clearing after match detection
/// - Proper session restart with cleanup delays
/// - Detected anchor reset after successful navigation
/// - Longer restart delays to prevent speech recognizer conflicts
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
    
    // Buffer management - CRITICAL: must clear immediately after match
    private var transcriptBuffer = ""
    private var lastMatchTime: Date?
    private let matchCooldown: TimeInterval = 0.3 // Very short - just prevent echo detection
    
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
    
    /// CRITICAL: Call this after navigation completes to allow detecting the NEXT anchor
    @MainActor
    func clearLastDetection() {
        print("🧹 clearLastDetection() called")
        print("   Before - detectedAnchorIds: \(detectedAnchorIds)")
        
        // FIXED: DO clear detectedAnchorIds to allow recognizing different anchors
        detectedAnchorIds.removeAll()
        transcriptBuffer = ""
        lastTranscript = ""
        lastMatchTime = nil // Clear cooldown - ready for next anchor after restart
        
        print("   After - detectedAnchorIds: \(detectedAnchorIds)")
        
        // CRITICAL: Must restart to clear Speech Recognition's internal transcript buffer
        // Without this, the transcript accumulates all previous speech and keeps matching old anchors
        if isListening && !isRestarting {
            print("   🔄 Restarting to clear accumulated transcript...")
            scheduleRestart(delay: 0.1) // Very short delay for fast response
        }
    }
    
    @MainActor
    func resetDetectedAnchors() {
        detectedAnchorIds.removeAll()
        transcriptBuffer = ""
        lastTranscript = ""
        lastMatchTime = nil
    }
    
    // MARK: - Private Methods
    
    private func startRecognitionSession() throws {
        // Clean up any existing session first
        cleanupRecognition()
        
        // Brief wait for cleanup - reduced for faster restart
        Thread.sleep(forTimeInterval: 0.05)
        
        // Create fresh audio engine
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            throw RecognitionError.audioConfigFailed
        }
        
        // Configure audio session for recording alongside playback
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, AVAudioSession.CategoryOptions.allowBluetoothHFP, .mixWithOthers])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else {
            throw RecognitionError.audioConfigFailed
        }
        
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false
        
        // CRITICAL: Set task hint for better continuous recognition
        if #available(iOS 16.0, *) {
            request.taskHint = .dictation
        }
        
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
        // Ignore results during restart
        if isRestarting {
            print("⏭️ Ignoring result during restart")
            return
        }
        
        if let error = error {
            let nsError = error as NSError
            
            print("⚠️ Recognition error: domain=\(nsError.domain), code=\(nsError.code), message=\(error.localizedDescription)")
            
            // Handle known non-fatal errors
            if nsError.domain == "kLSRErrorDomain" {
                if nsError.code == 301 {
                    // Request was canceled - this is expected during cleanup
                    print("ℹ️ Recognition canceled (expected), continuing session")
                    return
                }
            }
            
            // Handle kAFAssistantErrorDomain errors
            if nsError.domain == "kAFAssistantErrorDomain" {
                // Fatal errors that require restart:
                if nsError.code == 216 || nsError.code == 203 {
                    print("🔄 Fatal error, restarting...")
                    scheduleRestart(delay: 0.8)
                    return
                }
                // Non-fatal errors (1110 = no speech, 1107 = timeout)
                print("ℹ️ Non-fatal error, continuing session")
                return
            }
            
            // For unknown errors, log but try to restart
            print("🔄 Unknown error, restarting...")
            scheduleRestart(delay: 0.8)
            return
        }
        
        guard let result = result else { return }
        
        let transcript = result.bestTranscription.formattedString
        lastTranscript = transcript
        
        // Debug logging
        print("📝 Transcript: '\(transcript)' (isFinal: \(result.isFinal))")
        print("🕐 Cooldown check: \(String(describing: lastMatchTime)), active: \(lastMatchTime.map { Date().timeIntervalSince($0) < matchCooldown } ?? false)")
        
        // CRITICAL: Only check for matches if we're not in cooldown
        if let lastMatch = lastMatchTime, Date().timeIntervalSince(lastMatch) < matchCooldown {
            // Still in cooldown, ignore this transcript
            print("⏸️ In cooldown, ignoring")
            return
        }
        
        // Update buffer with latest transcript
        if !transcript.isEmpty {
            transcriptBuffer = transcript
            checkForAnchorMatch(in: transcriptBuffer)
        }
        
        // REMOVED: Don't auto-restart on final results
        // Let the recognition session continue indefinitely
        // Only restart when explicitly requested via clearLastDetection()
    }
    
    @MainActor
    private func checkForAnchorMatch(in transcript: String) {
        // CRITICAL: Check cooldown first
        if let lastMatch = lastMatchTime, Date().timeIntervalSince(lastMatch) < matchCooldown {
            print("⏸️ Cooldown active in checkForAnchorMatch")
            return
        }
        
        guard let match = anchors.findMatch(for: transcript, threshold: 0.5) else {
            return
        }
        
        print("🎯 Found potential match: \(match.anchor.phrase)")
        print("🔍 Detected IDs: \(detectedAnchorIds)")
        print("🆔 Match ID: \(match.anchor.id)")
        
        // CRITICAL: Check if already detected
        guard !detectedAnchorIds.contains(match.anchor.id) else {
            print("⛔️ Already detected, ignoring")
            return
        }
        
        print("✨ NEW ANCHOR DETECTED: \(match.anchor.phrase)")
        
        // Record detection
        detectedAnchorIds.insert(match.anchor.id)
        lastMatchTime = Date()
        
        // CRITICAL: Clear buffer IMMEDIATELY to prevent re-matching
        transcriptBuffer = ""
        lastTranscript = ""
        
        // Notify callback
        onAnchorDetected?(match.anchor, match.confidence)
        
        // DON'T restart here - let clearLastDetection() handle it
        // This prevents double-restart race conditions
    }
    
    @MainActor
    private func scheduleRestart(delay: TimeInterval = 0.8) {
        guard isListening && !isRestarting else {
            print("⚠️ scheduleRestart blocked: isListening=\(isListening), isRestarting=\(isRestarting)")
            return
        }
        
        print("🔄 Scheduling restart with delay: \(delay)s")
        isRestarting = true
        
        // Cancel any pending restart
        restartWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                guard let self = self, self.isListening else {
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
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            Task { @MainActor in
                                if self.isListening {
                                    self.scheduleRestart(delay: 1.0)
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
