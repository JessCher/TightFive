import SwiftUI
import Combine

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
    @Environment(AppSettings.self) private var appSettings
    
    func body(content: Content) -> some View {
        let _ = appSettings.updateTrigger // Force observation
        let theme = appSettings.tileCardTheme
        let gritLevel = appSettings.appGritLevel
        let customColor = Color(hex: appSettings.tileCardCustomColorHex) ?? theme.baseColor
        let gritEnabled = appSettings.tileCardGritEnabled
        let gritLayer1 = Color(hex: appSettings.tileCardGritLayer1ColorHex) ?? Color("TFYellow")
        let gritLayer2 = Color(hex: appSettings.tileCardGritLayer2ColorHex) ?? .white.opacity(0.3)
        let gritLayer3 = Color(hex: appSettings.tileCardGritLayer3ColorHex) ?? .white.opacity(0.1)
        
        content
            .background(
                ZStack {
                    // Use custom color if custom theme, otherwise use theme base color
                    if theme == .custom {
                        customColor
                        
                        // Apply custom grit layers if enabled
                        if gritEnabled && gritLevel > 0 {
                            StaticGritLayer(
                                density: appSettings.adjustedAppGritDensity(300),
                                opacity: 0.55,
                                seed: 1234,
                                particleColor: gritLayer1
                            )
                            
                            StaticGritLayer(
                                density: appSettings.adjustedAppGritDensity(300),
                                opacity: 0.35,
                                seed: 5678,
                                particleColor: gritLayer2
                            )
                            
                            StaticGritLayer(
                                density: appSettings.adjustedAppGritDensity(200),
                                opacity: 0.25,
                                seed: 9999,
                                particleColor: gritLayer3
                            )
                        }
                    } else {
                        // Use theme-based color
                        theme.baseColor
                        
                        // Apply grit layers based on theme and grit level
                        if gritLevel > 0 {
                            if theme == .darkGrit {
                                // Dark Grit theme layers
                                StaticGritLayer(
                                    density: appSettings.adjustedAppGritDensity(300),
                                    opacity: 0.55,
                                    seed: 1234,
                                    particleColor: Color("TFYellow")
                                )
                                
                                StaticGritLayer(
                                    density: appSettings.adjustedAppGritDensity(300),
                                    opacity: 0.35,
                                    seed: 5678
                                )
                            } else if theme == .yellowGrit {
                                // Yellow Grit theme layers
                                StaticGritLayer(
                                    density: appSettings.adjustedAppGritDensity(800),
                                    opacity: 0.85,
                                    seed: 7777,
                                    particleColor: .brown
                                )
                                
                                StaticGritLayer(
                                    density: appSettings.adjustedAppGritDensity(100),
                                    opacity: 0.88,
                                    seed: 8888,
                                    particleColor: .black
                                )
                                
                                StaticGritLayer(
                                    density: appSettings.adjustedAppGritDensity(400),
                                    opacity: 0.88,
                                    seed: 8888,
                                    particleColor: Color(red: 0.8, green: 0.4, blue: 0.0)
                                )
                            }
                        }
                    }
                    
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            RadialGradient(
                                colors: [.clear, .black.opacity(theme == .darkGrit ? 0.3 : 0.15)],
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
            .shadow(color: .black.opacity(0.6), radius: 4, x: 0, y: 2)
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
