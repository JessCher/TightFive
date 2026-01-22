import SwiftUI
import Combine
import CoreMotion

struct DynamicChalkboardBackground: View {
    @StateObject private var motion = MotionSampler()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Tunables
    private let dustCount = 2000       // tiny speckles
    private let clumpCount = 99      // big soft clouds
    private let breatheSpeed = 0.25   // Hz (cycles per second)
    private let breatheAmplitude: CGFloat = 0.06

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let breathe = reduceMotion ? 0 as CGFloat : breatheAmplitude * CGFloat(sin(2 * .pi * breatheSpeed * t))
            let tilt = reduceMotion ? .zero : motion.normalizedTilt
            let topGlowOpacity = 0.20 + Double(max(0, breathe) * CGFloat(0.06))

            ZStack {
                // Base board tone
                Color("TFBackground")

                // Breathing chalk speckles (fast layer)
                Canvas { ctx, size in
                    let seed = UInt64(t.rounded(.towardZero))  // seed per frame (fast jitter)
                    var rng = SeededRandom(seed: seed)
                    let margin: CGFloat = 60

                    for _ in 0..<dustCount {
                        let x = rng.next(in: -margin...(size.width + margin))
                        let y = rng.next(in: -margin...(size.height + margin))

                        // Subtle parallax with tilt
                        let px = x + tilt.x * 10
                        let py = y + tilt.y * 10

                        let r = rng.next(in: CGFloat(0.4)...CGFloat(1.1))
                        let alpha = rng.next(in: 0.02...0.06)

                        let rect = CGRect(x: px, y: py, width: r, height: r)
                        ctx.fill(Path(ellipseIn: rect), with: .color(.white.opacity(alpha)))
                    }
                }
                .opacity(0.18 + breathe * 0.12)
                .blendMode(.overlay)
                .drawingGroup()

                // Soft clumps (slow layer)
                Canvas { ctx, size in
                    var rng = SeededRandom(seed: 42) // stable layout; we animate transform only
                    let margin: CGFloat = 80

                    for _ in 0..<clumpCount {
                        let cx = rng.next(in: -margin...(size.width + margin))
                        let cy = rng.next(in: -margin...(size.height + margin))
                        let base = rng.next(in: CGFloat(180.0)...CGFloat(420.0))

                        // Breathing + parallax
                        let scale: CGFloat = 1 + breathe * 0.15
                        let offset = CGSize(width: tilt.x * 20, height: tilt.y * 20)

                        let rect = CGRect(
                            x: cx - base/2 + offset.width,
                            y: cy - base/2 + offset.height,
                            width: base * scale,
                            height: base * scale
                        )

                        // Radial soft spot
                        let gradient = Gradient(stops: [
                            .init(color: .white.opacity(0.10), location: 0.0),
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

                // Top glow (breathes slightly)
                LinearGradient(
                    colors: [
                        Color.white.opacity(topGlowOpacity),
                        Color.white.opacity(0.03),
                        Color.clear
                    ],
                    startPoint: .top, endPoint: .center
                )
                .offset(y: breathe * 8)

                // Vignette (subtle parallax)
                RadialGradient(
                    colors: [
                        Color.clear,
                        Color.black.opacity(0.55)
                    ],
                    center: .center,
                    startRadius: 140,
                    endRadius: 750
                )
                .offset(x: tilt.x * -12, y: tilt.y * -12)
                .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea()
        .onAppear { motion.start(reduceMotion: reduceMotion) }
        .onDisappear { motion.stop() }
    }
}

// MARK: - Motion

private final class MotionSampler: ObservableObject {
    @Published var normalizedTilt: CGPoint = .zero

    private let manager = CMMotionManager()
    private let queue = OperationQueue()
    private let maxTilt: Double = 0.25 // radians clamp for normalization

    func start(reduceMotion: Bool) {
#if targetEnvironment(simulator)
        return
#endif
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" { return }
        guard !reduceMotion else { return }
        if manager.isDeviceMotionAvailable {
            manager.deviceMotionUpdateInterval = 1.0/30.0
            manager.startDeviceMotionUpdates(to: queue) { [weak self] motion, _ in
                guard let self, let m = motion else { return }
                // Use attitude pitch/roll, clamp, and normalize to [-1, 1]
                let pitch = max(-maxTilt, min(maxTilt, m.attitude.pitch))
                let roll  = max(-maxTilt, min(maxTilt, m.attitude.roll))
                let nx = roll / maxTilt
                let ny = pitch / maxTilt
                DispatchQueue.main.async {
                    withAnimation(.easeOut(duration: 0.15)) {
                        self.normalizedTilt = CGPoint(x: CGFloat(nx), y: CGFloat(ny))
                    }
                }
            }
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
    }
}

// MARK: - Random helpers

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

