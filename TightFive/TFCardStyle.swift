import SwiftUI

extension View {
    func tfTexturedCard(cornerRadius: CGFloat = 20) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color("TFCard"))
            )
            // Chalk texture INSIDE the card
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        ImagePaint(image: Image("TFCardTexture"), scale: 0.7)
                    )
                    .opacity(0.22)              // 0.12–0.22 is the sweet spot
                    .blendMode(.softLight)
                    .clipped()
            )
            // Very subtle highlight lift
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        ImagePaint(image: Image("TFCardTexture"), scale: 1.4)
                    )
                    .opacity(0.05)              // 0.03–0.07
                    .blendMode(.screen)
                    .clipped()
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color("TFCardStroke").opacity(0.85), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.28), radius: 18, x: 0, y: 12)
    }
}
