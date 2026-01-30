import SwiftUI
import Combine

struct DynamicChalkboardBackground: View {
    /// When false, renders a static snapshot of the exact same background.
    /// (No TimelineView + no motion sampling)
    var isAnimated: Bool = true

    // Motion disabled; static background only
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Tunables (PERFORMANCE OPTIMIZED)
    private let dustCount = 800        // Reduced from 1200
    private let clumpCount = 80        // Reduced from 80
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
    }

    @ViewBuilder
    private func content(at date: Date) -> some View {
        let t = date.timeIntervalSinceReferenceDate
        let breathe = (isAnimated && !reduceMotion) ? (breatheAmplitude * CGFloat(sin(2 * .pi * breatheSpeed * t))) : 0

        // Smoothed tilt removed; static background only
        let tilt: CGPoint = .zero

        // Glow opacity (kept identical to animated version)
        let topGlowOpacity = 0.30 + Double(max(0, breathe) * CGFloat(0.06))

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
            .opacity(0.24 + breathe * 0.12)
            .blendMode(.overlay)
            .drawingGroup()

            // 3. Soft Clumps (Slow Layer)
            Canvas { ctx, size in
                var rng = SeededRandom(seed: 42)
                let margin: CGFloat = 150

                ctx.translateBy(x: slowLayerOffset.width, y: slowLayerOffset.height)

                let scaleCenter = CGPoint(x: size.width / 4, y: size.height / 1)
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
                        .init(color: .tfYellow.opacity(0.18), location: 0.50),
                        .init(color: .blue.opacity(0.03), location: 1.0),
                        .init(color: .white.opacity(0.03), location: 1.5),
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
