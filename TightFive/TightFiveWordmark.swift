import SwiftUI

struct TightFiveWordmark: View {
    var size: CGFloat = 18

    var body: some View {
        HStack(spacing: 1) {
            ZStack {
                // Stroke layer (black outline)
                Text("TIGHT")
                    .font(.custom("Chalkduster", size: size))
                    .foregroundStyle(.black)
                    .offset(x: -1, y: -1)
                
                Text("TIGHT")
                    .font(.custom("Chalkduster", size: size))
                    .foregroundStyle(.black)
                    .offset(x: 1, y: -1)
                
                Text("TIGHT")
                    .font(.custom("Chalkduster", size: size))
                    .foregroundStyle(.black)
                    .offset(x: -1, y: 1)
                
                Text("TIGHT")
                    .font(.custom("Chalkduster", size: size))
                    .foregroundStyle(.black)
                    .offset(x: 1, y: 1)
                
                // Fill layer (white)
                Text("TIGHT")
                    .font(.custom("Chalkduster", size: size))
                    .foregroundStyle(.white)
            }

            ZStack {
                // Stroke layer (black outline)
                Text("FIVE")
                    .font(.custom("Chalkduster", size: size))
                    .foregroundStyle(.black)
                    .offset(x: -1, y: -1)
                
                Text("FIVE")
                    .font(.custom("Chalkduster", size: size))
                    .foregroundStyle(.black)
                    .offset(x: 1, y: -1)
                
                Text("FIVE")
                    .font(.custom("Chalkduster", size: size))
                    .foregroundStyle(.black)
                    .offset(x: -1, y: 1)
                
                Text("FIVE")
                    .font(.custom("Chalkduster", size: size))
                    .foregroundStyle(.black)
                    .offset(x: 1, y: 1)
                
                // Fill layer (yellow)
                Text("FIVE")
                    .font(.custom("Chalkduster", size: size))
                    .foregroundStyle(Color("TFYellow"))
            }
        }
        .kerning(1.2)
        .accessibilityLabel("TightFive")
    }
}
