import Foundation
import Speech
import AVFoundation
import Combine
import SwiftUI

@MainActor
class SpeechRecognizer: ObservableObject {
    @Published var transcript: String = ""
    @Published var isRecording: Bool = false
    @Published var permissionStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    
    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    
    init() {
        checkPermissions()
    }
    
    func checkPermissions() {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                self.permissionStatus = status
            }
        }
    }
    
    func startTranscribing() {
        guard !isRecording else { return }
        
        // Reset
        transcript = ""
        
        // Configure Audio Session
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try? audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        request = SFSpeechAudioBufferRecognitionRequest()
        let inputNode = audioEngine.inputNode
        
        guard let request = request else { return }
        request.shouldReportPartialResults = true
        
        // Start Task
        task = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                self.transcript = result.bestTranscription.formattedString
            }
            
            if error != nil || (result?.isFinal ?? false) {
                self.stopTranscribing()
            }
        }
        
        // Start Engine
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }
        
        audioEngine.prepare()
        try? audioEngine.start()
        
        isRecording = true
    }
    
    func stopTranscribing() {
        guard isRecording else { return }
        
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        
        isRecording = false
        
        // Reset audio session
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}
