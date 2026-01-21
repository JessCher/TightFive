import SwiftUI

struct TightFiveWordmark: View {
    var size: CGFloat = 18

    var body: some View {
        HStack(spacing: 1) {
            Text("TIGHT")
                .font(.custom("Chalkduster", size: size))
                .foregroundStyle(.white)

            Text("FIVE")
                .font(.custom("Chalkduster", size: size))
                .foregroundStyle(Color("TFYellow"))
        }
        .kerning(1.2)
        .accessibilityLabel("TightFive")
    }
}
