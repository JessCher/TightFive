import SwiftUI

// MARK: - Static Grit Texture
struct StaticGritLayer: View {
    var density: Int
    var opacity: Double
    var seed: Int
    var particleColor: Color = .white
    
    var body: some View {
        Canvas { context, size in
            var rng = SeededRandomGenerator(seed: UInt64(seed))
            
            for _ in 0..<density {
                let x = Double.random(in: 0...size.width, using: &rng)
                let y = Double.random(in: 0...size.height, using: &rng)
                let r = Double.random(in: 0.5...1.5, using: &rng)
                
                let rect = CGRect(x: x, y: y, width: r, height: r)
                context.fill(Path(ellipseIn: rect), with: .color(particleColor))
            }
        }
        .opacity(opacity)
        .blendMode(.overlay)
        .drawingGroup()
        .allowsHitTesting(false)
    }
}

// MARK: - Textured Card Modifier
struct TexturedCardModifier: ViewModifier {
    var color: Color
    var cornerRadius: CGFloat
    
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    color
                    
                    StaticGritLayer(
                        density: 300,
                        opacity: 0.55,
                        seed: 1234,
                        particleColor: Color("TFYellow")
                    )
                    
                    StaticGritLayer(
                        density: 300,
                        opacity: 0.35,
                        seed: 5678
                    )
                    
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            RadialGradient(
                                colors: [.clear, .black.opacity(0.3)],
                                center: .center,
                                startRadius: 50,
                                endRadius: 400
                            )
                        )
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color("TFCardStroke"), lineWidth: 1.5)
                    .opacity(0.9)
                    .blendMode(.overlay)
            )
            .shadow(color: .black.opacity(0.8), radius: 10, x: 0, y: 8)
    }
}

// MARK: - View Extension
extension View {
    func tfDynamicCard(color: Color = Color("TFCard"), cornerRadius: CGFloat = 20) -> some View {
        self.modifier(TexturedCardModifier(color: color, cornerRadius: cornerRadius))
    }
}

// MARK: - Helper
private struct SeededRandomGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed }
    mutating func next() -> UInt64 {
        state = 6364136223846793005 &* state &+ 1442695040888963407
        return state
    }
}
