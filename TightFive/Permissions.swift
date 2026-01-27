import Foundation
import AVFoundation
import Speech

enum Permissions {

    // MARK: Speech

    static func requestSpeechIfNeeded() async -> Bool {
        if SFSpeechRecognizer.authorizationStatus() == .authorized { return true }

        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    // MARK: Microphone

    /// Uses the newest supported mic permission API first.
    static func requestMicrophoneIfNeeded() async -> Bool {
        // Newer API path (preferred)
        if #available(iOS 17.0, *) {
            let status = AVAudioApplication.shared.recordPermission
            switch status {
            case .granted:
                return true
            case .denied:
                return false
            case .undetermined:
                return await withCheckedContinuation { continuation in
                    AVAudioApplication.requestRecordPermission { granted in
                        continuation.resume(returning: granted)
                    }
                }
            @unknown default:
                return false
            }
        } else {
            // Legacy fallback (kept only for completeness)
            let session = AVAudioSession.sharedInstance()
            switch session.recordPermission {
            case .granted:
                return true
            case .denied:
                return false
            case .undetermined:
                return await withCheckedContinuation { continuation in
                    session.requestRecordPermission { granted in
                        continuation.resume(returning: granted)
                    }
                }
            @unknown default:
                return false
            }
        }
    }
}
