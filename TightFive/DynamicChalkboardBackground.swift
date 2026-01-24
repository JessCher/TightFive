import SwiftUI
import Combine
import CoreMotion

struct DynamicChalkboardBackground: View {
    /// When false, renders a static snapshot of the exact same background.
    /// (No TimelineView + no motion sampling)
    var isAnimated: Bool = true

    @StateObject private var motion = MotionSampler()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Tunables (PERFORMANCE OPTIMIZED)
    private let dustCount = 800        // Reduced from 1200
    private let clumpCount = 50        // Reduced from 80
    private let breatheSpeed = 0.25
    private let breatheAmplitude: CGFloat = 0.06
    
    // Cap at 20 FPS to reduce overheating (was 30)
    private let frameRate: TimeInterval = 1.0 / 20.0

    var body: some View {
        Group {
            if isAnimated && !reduceMotion {
                TimelineView(.periodic(from: .now, by: frameRate)) { context in
                    content(at: context.date)
                }
            } else {
                // Static snapshot that matches the "rest" state of the dynamic background.
                content(at: .distantPast)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            if isAnimated && !reduceMotion {
                motion.start(reduceMotion: reduceMotion)
            } else {
                motion.stop()
            }
        }
        .onChange(of: isAnimated) { _, newValue in
            if newValue && !reduceMotion {
                motion.start(reduceMotion: reduceMotion)
            } else {
                motion.stop()
            }
        }
        .onChange(of: reduceMotion) { _, newValue in
            if isAnimated && !newValue {
                motion.start(reduceMotion: newValue)
            } else {
                motion.stop()
            }
        }
        .onDisappear { motion.stop() }
    }

    @ViewBuilder
    private func content(at date: Date) -> some View {
        let t = date.timeIntervalSinceReferenceDate
        let breathe = (isAnimated && !reduceMotion) ? (breatheAmplitude * CGFloat(sin(2 * .pi * breatheSpeed * t))) : 0

        // Smoothed tilt
        let tilt: CGPoint = (isAnimated && !reduceMotion) ? motion.normalizedTilt : .zero

        // Glow opacity (kept identical to animated version)
        let topGlowOpacity = 0.20 + Double(max(0, breathe) * CGFloat(0.06))

        // Parallax offsets
        let fastLayerOffset = CGSize(width: tilt.x * 25, height: tilt.y * 25)
        let slowLayerOffset = CGSize(width: tilt.x * 40, height: tilt.y * 40)
        let vignetteOffset = CGSize(width: tilt.x * -15, height: tilt.y * -15)

        ZStack {
            // 1. Base Tone
            Color("TFBackground")

            // 2. Chalk Speckles (Fast Layer)
            Canvas { ctx, size in
                var rng = SeededRandom(seed: 12345)
                let margin: CGFloat = 100

                ctx.translateBy(x: fastLayerOffset.width, y: fastLayerOffset.height)

                for _ in 0..<dustCount {
                    let x = rng.next(in: -margin...(size.width + margin))
                    let y = rng.next(in: -margin...(size.height + margin))
                    let r = rng.next(in: CGFloat(0.4)...CGFloat(1.2))
                    let alpha = rng.next(in: 0.02...0.07)

                    let rect = CGRect(x: x, y: y, width: r, height: r)
                    ctx.fill(Path(ellipseIn: rect), with: .color(.white.opacity(alpha)))
                }
            }
            .opacity(0.18 + breathe * 0.12)
            .blendMode(.overlay)
            .drawingGroup()

            // 3. Soft Clumps (Slow Layer)
            Canvas { ctx, size in
                var rng = SeededRandom(seed: 42)
                let margin: CGFloat = 150

                ctx.translateBy(x: slowLayerOffset.width, y: slowLayerOffset.height)

                let scaleCenter = CGPoint(x: size.width / 2, y: size.height / 2)
                let scaleFactor: CGFloat = 1 + breathe * 0.15

                ctx.translateBy(x: scaleCenter.x, y: scaleCenter.y)
                ctx.scaleBy(x: scaleFactor, y: scaleFactor)
                ctx.translateBy(x: -scaleCenter.x, y: -scaleCenter.y)

                for _ in 0..<clumpCount {
                    let cx = rng.next(in: -margin...(size.width + margin))
                    let cy = rng.next(in: -margin...(size.height + margin))
                    let base = rng.next(in: CGFloat(150.0)...CGFloat(400.0))

                    let rect = CGRect(x: cx - base/2, y: cy - base/2, width: base, height: base)

                    let gradient = Gradient(stops: [
                        .init(color: .white.opacity(0.08), location: 0.0),
                        .init(color: .white.opacity(0.00), location: 1.0)
                    ])

                    ctx.fill(
                        Path(ellipseIn: rect),
                        with: .radialGradient(
                            gradient,
                            center: CGPoint(x: rect.midX, y: rect.midY),
                            startRadius: 0,
                            endRadius: base / 2
                        )
                    )
                }
            }
            .opacity(0.18)
            .blendMode(.softLight)
            .drawingGroup()

            // 4. Top Glow
            LinearGradient(
                colors: [
                    Color.white.opacity(topGlowOpacity),
                    Color.white.opacity(0.03),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .center
            )
            .offset(y: breathe * 8)
            .allowsHitTesting(false)

            // 5. Vignette
            RadialGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(0.60)
                ],
                center: .center,
                startRadius: 100,
                endRadius: 800
            )
            .offset(vignetteOffset)
            .allowsHitTesting(false)
        }
        .scaleEffect(1.1)
        .animation(.easeOut(duration: 0.2), value: tilt)
    }
}

// MARK: - Motion Manager (Optimized)

private final class MotionSampler: ObservableObject {
    @Published var normalizedTilt: CGPoint = .zero

    private let manager = CMMotionManager()
    private let queue = OperationQueue()
    private let maxTilt: Double = 0.35

    func start(reduceMotion: Bool) {
        #if targetEnvironment(simulator)
        return
        #endif
        
        guard !reduceMotion, manager.isDeviceMotionAvailable else { return }
        
        // PERFORMANCE: 20Hz update rate (was 30Hz) saves battery
        manager.deviceMotionUpdateInterval = 1.0 / 20.0
        
        manager.startDeviceMotionUpdates(to: queue) { [weak self] motion, _ in
            guard let self = self, let m = motion else { return }
            
            let pitch = max(-self.maxTilt, min(self.maxTilt, m.attitude.pitch))
            let roll  = max(-self.maxTilt, min(self.maxTilt, m.attitude.roll))
            
            let nx = roll / self.maxTilt
            let ny = pitch / self.maxTilt
            
            DispatchQueue.main.async {
                withAnimation(.linear(duration: 0.15)) { // Slightly longer animation
                    self.normalizedTilt = CGPoint(x: CGFloat(nx), y: CGFloat(ny))
                }
            }
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
        normalizedTilt = .zero // Reset when stopped
    }
}

// MARK: - Random Helper
private struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed &* 0x9E3779B97F4A7C15 }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    mutating func next(in range: ClosedRange<Double>) -> Double {
        let n = next()
        let unit = Double(n) / Double(UInt64.max)
        return range.lowerBound + (range.upperBound - range.lowerBound) * unit
    }

    mutating func next(in range: ClosedRange<CGFloat>) -> CGFloat {
        CGFloat(next(in: ClosedRange<Double>(uncheckedBounds: (Double(range.lowerBound), Double(range.upperBound)))))
    }
}
