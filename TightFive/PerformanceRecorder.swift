import Foundation
import AVFoundation
import Combine
import SwiftUI

/// Audio recording service for Stage Mode performances.
///
/// Features:
/// - High-quality M4A recording
/// - Real-time audio level metering
/// - Proper lifecycle management
final class PerformanceRecorder: ObservableObject {
    
    @MainActor @Published private(set) var isRecording = false
    @MainActor @Published private(set) var currentTime: TimeInterval = 0
    @MainActor @Published private(set) var audioLevel: Float = 0
    @MainActor @Published private(set) var error: RecordingError?
    
    private var audioRecorder: AVAudioRecorder?
    private var levelTimer: Timer?
    private var timeTimer: Timer?
    private var recordingStartTime: Date?
    
    private(set) var currentFilename: String?
    private(set) var recordingURL: URL?
    
    enum RecordingError: LocalizedError {
        case permissionDenied
        case configurationFailed
        case recordingFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                return "Microphone access denied. Enable in Settings."
            case .configurationFailed:
                return "Could not configure audio session."
            case .recordingFailed(let message):
                return "Recording failed: \(message)"
            }
        }
    }
    
    init() {}
    
    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    
    var hasPermission: Bool {
        AVAudioApplication.shared.recordPermission == .granted
    }
    
    @MainActor
    func startRecording(filename: String) async -> Bool {
        error = nil
        
        if !hasPermission {
            let granted = await requestPermission()
            if !granted {
                error = .permissionDenied
                return false
            }
        }
        
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP, .mixWithOthers])
            try session.setActive(true)
        } catch {
            self.error = .configurationFailed
            return false
        }
        
        let url = Performance.recordingsDirectory.appendingPathComponent(filename)
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.prepareToRecord()
            
            guard audioRecorder?.record() == true else {
                self.error = .recordingFailed("Failed to start")
                return false
            }
            
            currentFilename = filename
            recordingURL = url
            recordingStartTime = Date()
            isRecording = true
            
            startTimers()
            return true
        } catch {
            self.error = .recordingFailed(error.localizedDescription)
            return false
        }
    }
    
    @MainActor
    func stopRecording() -> (url: URL, duration: TimeInterval, fileSize: Int64)? {
        guard isRecording, let recorder = audioRecorder, let url = recordingURL else {
            return nil
        }
        
        recorder.stop()
        stopTimers()
        
        isRecording = false
        audioLevel = 0
        
        let duration = currentTime
        currentTime = 0
        
        var fileSize: Int64 = 0
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? Int64 {
            fileSize = size
        }
        
        audioRecorder = nil
        currentFilename = nil
        recordingURL = nil
        recordingStartTime = nil
        
        return (url, duration, fileSize)
    }
    
    @MainActor
    func cancelRecording() {
        guard isRecording else { return }
        
        audioRecorder?.stop()
        stopTimers()
        
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
        }
        
        isRecording = false
        audioLevel = 0
        currentTime = 0
        
        audioRecorder = nil
        currentFilename = nil
        recordingURL = nil
        recordingStartTime = nil
    }
    
    @MainActor
    private func startTimers() {
        // Capture a weak reference to avoid capturing `self` strongly in a @Sendable context.
        weak let weakSelf = self

        // Reduced from 0.1s to 0.2s (5 updates/sec instead of 10) for better battery life
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
            // Ensure we hop to the main actor explicitly and avoid capturing `self` in the closure.
            if let strongSelf = weakSelf {
                Task { @MainActor in
                    strongSelf.updateAudioLevel()
                }
            }
        }
        if let timer = levelTimer {
            RunLoop.main.add(timer, forMode: .common)
        }

        timeTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if let strongSelf = weakSelf {
                Task { @MainActor in
                    strongSelf.updateTime()
                }
            }
        }
        if let timer = timeTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    @MainActor
    private func stopTimers() {
        levelTimer?.invalidate()
        levelTimer = nil
        timeTimer?.invalidate()
        timeTimer = nil
    }
    
    @MainActor
    private func updateAudioLevel() {
        guard let recorder = audioRecorder, isRecording else {
            audioLevel = 0
            return
        }
        recorder.updateMeters()
        let db = recorder.averagePower(forChannel: 0)
        let minDb: Float = -60
        let level = max(0, (db - minDb) / (-minDb))
        audioLevel = level
    }
    
    @MainActor
    private func updateTime() {
        guard let start = recordingStartTime, isRecording else { return }
        currentTime = Date().timeIntervalSince(start)
    }
    
    @MainActor
    var formattedTime: String {
        let minutes = Int(currentTime) / 60
        let seconds = Int(currentTime) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    deinit {
        levelTimer?.invalidate()
        timeTimer?.invalidate()
    }
}
