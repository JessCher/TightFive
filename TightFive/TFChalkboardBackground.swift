import SwiftUI

struct TFChalkboardBackground: View {
    var body: some View {
        ZStack {
            Color("TFBackground")

            // Must exist in Assets: TFChalkTexture
            Image("TFChalkTexture")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .opacity(0.55)
                .blendMode(.softLight)

            Image("TFChalkTexture")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .opacity(0.55)
                .blendMode(.screen)

            LinearGradient(
                colors: [
                    Color.white.opacity(0.15),
                    Color.white.opacity(0.03),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()

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
