import SwiftUI

struct DynamicChalkboardBackground: View {
    // App settings for background customization - observe changes
    @Environment(AppSettings.self) private var settings

    // MARK: - Tunables
    private var dustCount: Int { settings.backgroundDustCount }
    private var clumpCount: Int { settings.backgroundCloudCount }

    var body: some View {
        content
            .ignoresSafeArea()
    }

    @ViewBuilder
    private var content: some View {
        let _ = settings.updateTrigger // Force observation of settings changes

        // Parallax offsets - adjusted by cloud offset settings
        let baseCloudOffsetX = CGFloat(settings.backgroundCloudOffsetX) * 100
        let baseCloudOffsetY = CGFloat(settings.backgroundCloudOffsetY) * 100

        let slowLayerOffset = CGSize(
            width: baseCloudOffsetX,
            height: baseCloudOffsetY
        )

        // Get cloud colors from settings
        let cloudColor1 = Color(hex: settings.backgroundCloudColor1Hex) ?? .tfYellow
        let cloudColor2 = Color(hex: settings.backgroundCloudColor2Hex) ?? .blue
        let cloudColor3 = Color(hex: settings.backgroundCloudColor3Hex) ?? .white

        ZStack {
            // 1. Base Tone (not customizable - stays default)
            Color("TFBackground")

            // 2. Chalk Speckles (Dust Layer)
            Canvas { ctx, size in
                var rng = SeededRandom(seed: 12345)
                let margin: CGFloat = 100

                for _ in 0..<dustCount {
                    let x = rng.next(in: -margin...(size.width + margin))
                    let y = rng.next(in: -margin...(size.height + margin))
                    let r = rng.next(in: CGFloat(0.4)...CGFloat(1.2))
                    let alpha = rng.next(in: 0.02...0.07)

                    let rect = CGRect(x: x, y: y, width: r, height: r)
                    ctx.fill(Path(ellipseIn: rect), with: .color(.white.opacity(alpha)))
                }
            }
            .opacity(settings.backgroundDustOpacity)
            .blendMode(.overlay)
            .drawingGroup()

            // 3. Soft Clumps (Cloud Layer)
            Canvas { ctx, size in
                var rng = SeededRandom(seed: 42)
                let margin: CGFloat = 150

                ctx.translateBy(x: slowLayerOffset.width, y: slowLayerOffset.height)

                for _ in 0..<clumpCount {
                    let cx = rng.next(in: -margin...(size.width + margin))
                    let cy = rng.next(in: -margin...(size.height + margin))
                    let base = rng.next(in: CGFloat(150.0)...CGFloat(400.0))

                    let rect = CGRect(x: cx - base/2, y: cy - base/2, width: base, height: base)

                    let gradient = Gradient(stops: [
                        .init(color: cloudColor1.opacity(0.18), location: 0.50),
                        .init(color: cloudColor2.opacity(0.03), location: 1.0),
                        .init(color: cloudColor3.opacity(0.03), location: 1.5),
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
            .opacity(settings.backgroundCloudOpacity)
            .blendMode(.softLight)
            .drawingGroup()

            // 4. Top Glow
            LinearGradient(
                colors: [
                    Color.white.opacity(0.30),
                    Color.white.opacity(0.03),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .center
            )
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
            .allowsHitTesting(false)
        }
        .scaleEffect(1.1)
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
