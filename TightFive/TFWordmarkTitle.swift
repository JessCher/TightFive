import SwiftUI

struct TFWordmarkTitle: View {
    let title: String
    var size: CGFloat = 22

    private var parts: (String, String?) {
        // Split into words; color the last word with the accent color
        let words = title.split(separator: " ")
        guard let last = words.last else { return (title.uppercased(), nil) }
        if words.count == 1 {
            return (String(last).uppercased(), nil)
        } else {
            let firstPart = words.dropLast().joined(separator: " ")
            return (firstPart.uppercased(), String(last).uppercased())
        }
    }

    var body: some View {
        let (first, second) = parts
        HStack(spacing: 6) {
            ZStack {
                // Stroke layer (black outline)
                Text(first)
                    .font(.custom("Chalkduster", size: size))
                    .foregroundStyle(.black)
                    .offset(x: -1, y: -1)
                
                Text(first)
                    .font(.custom("Chalkduster", size: size))
                    .foregroundStyle(.black)
                    .offset(x: 1, y: -1)
                
                Text(first)
                    .font(.custom("Chalkduster", size: size))
                    .foregroundStyle(.black)
                    .offset(x: -1, y: 1)
                
                Text(first)
                    .font(.custom("Chalkduster", size: size))
                    .foregroundStyle(.black)
                    .offset(x: 1, y: 1)
                
                // Fill layer (white)
                Text(first)
                    .font(.custom("Chalkduster", size: size))
                    .foregroundStyle(.white)
            }
            
            if let second {
                ZStack {
                    // Stroke layer (black outline)
                    Text(second)
                        .font(.custom("Chalkduster", size: size))
                        .foregroundStyle(.black)
                        .offset(x: -1, y: -1)
                    
                    Text(second)
                        .font(.custom("Chalkduster", size: size))
                        .foregroundStyle(.black)
                        .offset(x: 1, y: -1)
                    
                    Text(second)
                        .font(.custom("Chalkduster", size: size))
                        .foregroundStyle(.black)
                        .offset(x: -1, y: 1)
                    
                    Text(second)
                        .font(.custom("Chalkduster", size: size))
                        .foregroundStyle(.black)
                        .offset(x: 1, y: 1)
                    
                    // Fill layer (yellow)
                    Text(second)
                        .font(.custom("Chalkduster", size: size))
                        .foregroundStyle(Color("TFYellow"))
                }
            }
        }
        .kerning(1.0)
        .accessibilityLabel(Text(title))
    }
}

#Preview {
    VStack(spacing: 16) {
        TFWordmarkTitle(title: "Loose Bits")
        TFWordmarkTitle(title: "Finished Bits")
        TFWordmarkTitle(title: "Set lists")
        TFWordmarkTitle(title: "Show Notes")
    }
    .padding()
    .background(Color.black)
}

