import SwiftUI

struct TFBackground: View {
    var body: some View {
        ZStack {
            Color("TFBackground")

            // Chalk texture: softLight keeps it visible on dark backgrounds
            Image("TFChalkTexture")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .opacity(0.55)
                .blendMode(.softLight)

            // Tiny highlight lift so the grit reads (this is the trick)
            Image("TFChalkTexture")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .opacity(0.10)
                .blendMode(.screen)

            // Top glow (mock-like)
            LinearGradient(
                colors: [
                    Color.white.opacity(0.10),
                    Color.white.opacity(0.03),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()

            // Vignette
            RadialGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(0.60)
                ],
                center: .center,
                startRadius: 140,
                endRadius: 750
            )
            .ignoresSafeArea()
        }
        .allowsHitTesting(false)
    }
}
