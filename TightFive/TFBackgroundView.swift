import SwiftUI

struct TFBackgroundView: View {
    var body: some View {
        ZStack {
            // Base
            TFChalkboardBackground()

            // Soft top glow (like the mock)
            LinearGradient(
                colors: [
                    Color.white.opacity(0.07),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .center
            )

            // Chalky vignette
            RadialGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(0.55)
                ],
                center: .center,
                startRadius: 120,
                endRadius: 620
            )

            // "Grit": subtle speckle overlay
            TFNoiseOverlay()
                .opacity(0.18)
                .blendMode(.overlay)
        }
        .ignoresSafeArea()
    }
}

private struct TFNoiseOverlay: View {
    var body: some View {
        GeometryReader { geo in
            let size = geo.size

            Canvas { context, _ in
                // Sparse field of tiny dots
                for _ in 0..<1400 {
                    let x = Double.random(in: 0...size.width)
                    let y = Double.random(in: 0...size.height)
                    let r = Double.random(in: 0.4...1.1)

                    let rect = CGRect(x: x, y: y, width: r, height: r)
                    context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(Double.random(in: 0.02...0.06))))
                }
            }
        }
        .drawingGroup() // performance
    }
}
