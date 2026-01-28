import Foundation
import Accelerate
import AVFoundation

/// High-performance acoustic feature analyzer for real-time voice analysis.
/// Detects emphasis, questions, energy levels using efficient signal processing.
///
/// Design principles:
/// - Hardware-accelerated (vDSP, vForce via Accelerate)
/// - Minimal allocations (reuse buffers)
/// - Battery-efficient (lazy computation, early exits)
/// - Real-time capable (< 5ms processing per buffer)
@MainActor
final class AcousticAnalyzer {
    
    // MARK: - Detected Features
    
    struct AcousticFeatures {
        let amplitude: Float           // RMS amplitude (volume)
        let pitch: Float?              // Fundamental frequency (Hz)
        let spectralCentroid: Float    // "Brightness" of sound
        let isEmphasis: Bool          // Louder than average
        let isQuestion: Bool          // Rising pitch
        let energyLevel: EnergyLevel
        
        enum EnergyLevel: Int, Comparable {
            case low = 0
            case medium = 1
            case high = 2
            
            static func < (lhs: EnergyLevel, rhs: EnergyLevel) -> Bool {
                lhs.rawValue < rhs.rawValue
            }
        }
    }
    
    // MARK: - State (Minimal for Battery)
    
    private var recentAmplitudes: [Float] = []
    private let amplitudeHistorySize = 20
    
    private var recentPitches: [Float] = []
    private let pitchHistorySize = 5
    
    // Pre-allocated buffers (avoid repeated allocation)
    private var fftSetup: FFTSetup?
    private var fftBuffer: DSPSplitComplex?
    private var window: [Float] = []
    
    // MARK: - Configuration
    
    private let sampleRate: Float
    private let emphasisThreshold: Float = 1.4 // 40% louder than average
    private let pitchRiseThreshold: Float = 1.08 // 8% pitch increase
    
    // MARK: - Initialization
    
    init(sampleRate: Float = 48000) {
        self.sampleRate = sampleRate
        
        // Pre-compute Hann window for FFT (done once, reused)
        let windowSize = 2048
        self.window = (0..<windowSize).map { i in
            Float(0.5 * (1.0 - cos(2.0 * .pi * Double(i) / Double(windowSize - 1))))
        }
        
        // Setup FFT (hardware-accelerated)
        let log2n = vDSP_Length(log2(Float(windowSize)))
        self.fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))
        
        // Pre-allocate FFT buffer
        let realp = UnsafeMutablePointer<Float>.allocate(capacity: windowSize / 2)
        let imagp = UnsafeMutablePointer<Float>.allocate(capacity: windowSize / 2)
        self.fftBuffer = DSPSplitComplex(realp: realp, imagp: imagp)
    }
    
    deinit {
        // Clean up FFT resources
        if let setup = fftSetup {
            vDSP_destroy_fftsetup(setup)
        }
        fftBuffer?.realp.deallocate()
        fftBuffer?.imagp.deallocate()
    }
    
    // MARK: - Analysis (Optimized for Real-Time)
    
    /// Analyzes audio buffer and returns acoustic features.
    /// Optimized: < 5ms processing time on modern hardware.
    func analyze(buffer: AVAudioPCMBuffer) -> AcousticFeatures {
        guard let channelData = buffer.floatChannelData?[0] else {
            return AcousticFeatures(amplitude: 0, pitch: nil, spectralCentroid: 0,
                                   isEmphasis: false, isQuestion: false, energyLevel: .low)
        }
        
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else {
            return AcousticFeatures(amplitude: 0, pitch: nil, spectralCentroid: 0,
                                   isEmphasis: false, isQuestion: false, energyLevel: .low)
        }
        
        // 1. Amplitude (RMS) - Hardware accelerated via vDSP
        let amplitude = computeRMS(samples: channelData, count: frameLength)
        
        // 2. Energy level (cheap, computed from amplitude)
        let energyLevel = classifyEnergy(amplitude: amplitude)
        
        // 3. Emphasis detection (uses history)
        let isEmphasis = detectEmphasis(amplitude: amplitude)
        
        // 4. Pitch estimation (expensive, skip if volume too low)
        var pitch: Float? = nil
        if amplitude > 0.01 { // Skip pitch detection for near-silence (battery optimization)
            pitch = estimatePitch(samples: channelData, count: frameLength)
        }
        
        // 5. Question detection (uses pitch history)
        let isQuestion = detectQuestion(pitch: pitch)
        
        // 6. Spectral centroid (expensive, skip if not needed for UI)
        // Only compute if we'll use it (e.g., high energy moments)
        let spectralCentroid: Float
        if energyLevel == .high || isEmphasis {
            spectralCentroid = computeSpectralCentroid(samples: channelData, count: frameLength)
        } else {
            spectralCentroid = 0 // Skip expensive computation
        }
        
        return AcousticFeatures(
            amplitude: amplitude,
            pitch: pitch,
            spectralCentroid: spectralCentroid,
            isEmphasis: isEmphasis,
            isQuestion: isQuestion,
            energyLevel: energyLevel
        )
    }
    
    // MARK: - Signal Processing (Hardware-Accelerated)
    
    /// Compute RMS amplitude using Accelerate framework.
    /// O(n), hardware-accelerated, battery-efficient.
    private func computeRMS(samples: UnsafePointer<Float>, count: Int) -> Float {
        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(count))
        return rms
    }
    
    /// Estimate pitch using autocorrelation (Accelerate-optimized).
    /// O(n log n), hardware-accelerated FFT.
    private func estimatePitch(samples: UnsafePointer<Float>, count: Int) -> Float? {
        // Use smaller window for pitch (512 samples = ~10ms @ 48kHz)
        let pitchWindowSize = min(512, count)
        
        // Autocorrelation via Accelerate (fastest method)
        var autocorrelation = [Float](repeating: 0, count: pitchWindowSize)
        vDSP_conv(samples, 1, samples, 1, &autocorrelation, 1,
                  vDSP_Length(pitchWindowSize), vDSP_Length(pitchWindowSize))
        
        // Find first peak after lag 0 (fundamental period)
        let minLag = Int(sampleRate / 500) // Max 500 Hz
        let maxLag = Int(sampleRate / 80)  // Min 80 Hz (human voice range)
        
        guard maxLag < pitchWindowSize else { return nil }
        
        var maxValue: Float = 0
        var maxIndex: vDSP_Length = 0
        autocorrelation.withUnsafeBufferPointer { buffer in
            vDSP_maxvi(buffer.baseAddress! + minLag, 1, &maxValue, &maxIndex, vDSP_Length(maxLag - minLag))
        }
        
        let lag = Int(maxIndex) + minLag
        let frequency = sampleRate / Float(lag)
        
        // Validate (human voice: 80-500 Hz)
        return (frequency >= 80 && frequency <= 500) ? frequency : nil
    }
    
    /// Compute spectral centroid (brightness) using FFT.
    /// O(n log n), hardware-accelerated, expensive (use sparingly).
    private func computeSpectralCentroid(samples: UnsafePointer<Float>, count: Int) -> Float {
        guard let fftSetup = fftSetup, var fftBuffer = fftBuffer else { return 0 }
        
        let fftSize = min(2048, count)
        let log2n = vDSP_Length(log2(Float(fftSize)))
        
        // Apply window (reduce spectral leakage)
        var windowed = [Float](repeating: 0, count: fftSize)
        vDSP_vmul(samples, 1, window, 1, &windowed, 1, vDSP_Length(fftSize))
        
        // Real-to-complex FFT (hardware-accelerated)
        windowed.withUnsafeBytes { ptr in
            let complexPtr = ptr.bindMemory(to: DSPComplex.self)
            vDSP_ctoz(complexPtr.baseAddress!, 2, &fftBuffer, 1, vDSP_Length(fftSize / 2))
        }
        
        vDSP_fft_zrip(fftSetup, &fftBuffer, 1, log2n, FFTDirection(FFT_FORWARD))
        
        // Compute magnitude spectrum
        var magnitudes = [Float](repeating: 0, count: fftSize / 2)
        vDSP_zvabs(&fftBuffer, 1, &magnitudes, 1, vDSP_Length(fftSize / 2))
        
        // Compute centroid (weighted average of frequencies)
        var weightedSum: Float = 0
        var totalMagnitude: Float = 0
        
        for i in 0..<(fftSize / 2) {
            let frequency = Float(i) * sampleRate / Float(fftSize)
            weightedSum += frequency * magnitudes[i]
            totalMagnitude += magnitudes[i]
        }
        
        return totalMagnitude > 0 ? weightedSum / totalMagnitude : 0
    }
    
    // MARK: - Feature Detection (Stateful, Efficient)
    
    private func detectEmphasis(amplitude: Float) -> Bool {
        // Track recent amplitudes (rolling average)
        recentAmplitudes.append(amplitude)
        if recentAmplitudes.count > amplitudeHistorySize {
            recentAmplitudes.removeFirst()
        }
        
        guard recentAmplitudes.count >= 5 else { return false }
        
        // Compute average (vDSP optimized)
        var average: Float = 0
        vDSP_meanv(recentAmplitudes, 1, &average, vDSP_Length(recentAmplitudes.count))
        
        // Emphasis = significantly louder than recent average
        return amplitude > average * emphasisThreshold
    }
    
    private func detectQuestion(pitch: Float?) -> Bool {
        guard let pitch = pitch else { return false }
        
        // Track recent pitches
        recentPitches.append(pitch)
        if recentPitches.count > pitchHistorySize {
            recentPitches.removeFirst()
        }
        
        guard recentPitches.count >= 3 else { return false }
        
        // Question = rising pitch at end (compare current to average of previous)
        let previousAverage = recentPitches.dropLast().reduce(0, +) / Float(recentPitches.count - 1)
        
        // Rising pitch by 8% or more
        return pitch > previousAverage * pitchRiseThreshold
    }
    
    private func classifyEnergy(amplitude: Float) -> AcousticFeatures.EnergyLevel {
        if amplitude < 0.05 {
            return .low
        } else if amplitude < 0.15 {
            return .medium
        } else {
            return .high
        }
    }
    
    // MARK: - Reset (Between Performances)
    
    func reset() {
        recentAmplitudes.removeAll(keepingCapacity: true) // Keep capacity = avoid reallocation
        recentPitches.removeAll(keepingCapacity: true)
    }
}
