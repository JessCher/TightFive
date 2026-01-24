import SwiftUI
import CoreMotion
import Combine

// MARK: - 1. Shared Motion Manager (Optimized)
final class SharedMotionManager: ObservableObject {
    static let shared = SharedMotionManager()
    
    @Published var pitch: Double = 0.0
    @Published var roll: Double = 0.0
    
    private let manager = CMMotionManager()
    private var isRunning = false
    private var activeViewCount = 0
    
    private init() {
        // Don't start automatically - wait for views to register
    }
    
    func startIfNeeded() {
        guard !isRunning, manager.isDeviceMotionAvailable else { return }
        
        activeViewCount += 1
        
        if activeViewCount == 1 {
            // SAFETY FIX: Reduced to 20 FPS (was 30) to prevent overheating
            manager.deviceMotionUpdateInterval = 1.0 / 20.0
            
            manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
                guard let self = self, let motion = motion else { return }
                
                // Smoothed animation
                withAnimation(.linear(duration: 0.15)) {
                    self.pitch = motion.attitude.pitch
                    self.roll = motion.attitude.roll
                }
            }
            isRunning = true
        }
    }
    
    func stopIfNeeded() {
        activeViewCount = max(0, activeViewCount - 1)
        
        if activeViewCount == 0 && isRunning {
            manager.stopDeviceMotionUpdates()
            isRunning = false
            
            // Reset to zero when stopped
            pitch = 0.0
            roll = 0.0
        }
    }
}

// MARK: - 2. The Dynamic Grit Component (Low Power Mode)
struct DynamicGritLayer: View {
    var density: Int
    var opacity: Double
    var speedMultiplier: CGFloat
    var seed: Int
    var particleColor: Color = .white // New parameter with default
    /// Set to false to freeze the grit in-place (no motion/animation).
    var isAnimated: Bool = false
    
    @ObservedObject private var motion = SharedMotionManager.shared
    
    var body: some View {
        Canvas { context, size in
            var rng = SeededRandomGenerator(seed: UInt64(seed))
            
            let maxTilt: Double = 0.5
            let rollSource = isAnimated ? motion.roll : 0.0
            let pitchSource = isAnimated ? motion.pitch : 0.0
            let clampedRoll = max(-maxTilt, min(maxTilt, rollSource))
            let clampedPitch = max(-maxTilt, min(maxTilt, pitchSource))
            
            // Optimized offset math
            let xOffset = CGFloat(clampedRoll) * speedMultiplier * 40
            let yOffset = CGFloat(clampedPitch) * speedMultiplier * 40
            
            context.translateBy(x: xOffset, y: yOffset)
            
            let w = size.width
            let h = size.height
            
            for _ in 0..<density {
                // Expanded bounds to prevent clipping during tilt
                let x = Double.random(in: -40...(w + 40), using: &rng)
                let y = Double.random(in: -40...(h + 40), using: &rng)
                let r = Double.random(in: 0.5...1.5, using: &rng)
                
                let rect = CGRect(x: x, y: y, width: r, height: r)
                context.fill(Path(ellipseIn: rect), with: .color(particleColor))
            }
        }
        .opacity(opacity)
        .blendMode(.overlay)
        // SAFETY FIX: Composites the view into an off-screen image before display
        // drastically reducing GPU strain for complex shapes.
        .drawingGroup()
        .allowsHitTesting(false)
        .onAppear {
            if isAnimated { motion.startIfNeeded() }
        }
        .onDisappear {
            if isAnimated { motion.stopIfNeeded() }
        }
    }
}

// MARK: - 3. The Card Modifier (Optimized)
struct DynamicCardModifier: ViewModifier {
    var color: Color
    var cornerRadius: CGFloat
    
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    color
                    
                    // SAFETY FIX: Reduced density from 800 -> 120
                    DynamicGritLayer(
                        density: 120,
                        opacity: 0.15,
                        speedMultiplier: 0.5,
                        seed: 1234
                    )
                    
                    // SAFETY FIX: Reduced density from 300 -> 60
                    DynamicGritLayer(
                        density: 60,
                        opacity: 0.35,
                        speedMultiplier: 1.2,
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

// MARK: - 4. View Extension
extension View {
    func tfDynamicCard(color: Color = Color("TFCard"), cornerRadius: CGFloat = 20) -> some View {
        self.modifier(DynamicCardModifier(color: color, cornerRadius: cornerRadius))
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
