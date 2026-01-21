import SwiftUI
import Combine
import CoreImage
import CoreImage.CIFilterBuiltins

@MainActor
final class TFChalkTextureGenerator: ObservableObject {
    @Published var image: UIImage?

    private let context = CIContext(options: [.useSoftwareRenderer: false])
    private var lastSize: CGSize = .zero

    func generateIfNeeded(for size: CGSize) {
        // Only regenerate if size meaningfully changed
        guard abs(size.width - lastSize.width) > 2 || abs(size.height - lastSize.height) > 2 else { return }
        lastSize = size

        // Generate once per size
        image = makeChalkTexture(size: size)
    }

    /// Best-effort display scale derived from current traits; avoid UIScreen.main (deprecated on iOS 26)
    private func currentDisplayScale(for size: CGSize) -> CGFloat {
        // Prefer trait-based scale when available
        if #available(iOS 17.0, *) {
            let scale = UITraitCollection.current.displayScale
            if scale > 0 { return scale }
        }
        // Fallback: infer a reasonable scale based on common device classes
        // If size is large (likely iPad or external display), assume 2.0; else 3.0 for dense iPhones.
        if max(size.width, size.height) > 1200 { return 2.0 }
        return 3.0
    }

    private func makeChalkTexture(size: CGSize) -> UIImage {
        let scale = currentDisplayScale(for: size)
        let w = max(Int(size.width * scale), 1200)
        let h = max(Int(size.height * scale), 1200)

        // Base random noise
        let random = CIFilter.randomGenerator().outputImage!
        var img = random.cropped(to: CGRect(x: 0, y: 0, width: w, height: h))

        // Turn speckle into "chalk dust" by blurring + contrast shaping
        let blur = CIFilter.gaussianBlur()
        blur.inputImage = img
        blur.radius = 8.0
        img = blur.outputImage!.cropped(to: CGRect(x: 0, y: 0, width: w, height: h))

        let baseControls = CIFilter.colorControls()
        baseControls.inputImage = img
        baseControls.saturation = 0
        baseControls.contrast = 1.35
        baseControls.brightness = 0.00
        img = baseControls.outputImage!.cropped(to: CGRect(x: 0, y: 0, width: w, height: h))

        // Create a second noise layer that becomes "clumps" (no direction)
        let clumpNoise = CIFilter.randomGenerator().outputImage!
            .cropped(to: CGRect(x: 0, y: 0, width: w, height: h))

        // Heavy blur makes big cloudy shapes
        let clumpBlur = CIFilter.gaussianBlur()
        clumpBlur.inputImage = clumpNoise
        clumpBlur.radius = 22.0
        var clumps = clumpBlur.outputImage!.cropped(to: CGRect(x: 0, y: 0, width: w, height: h))

        // Push contrast so the clumps have character
        let clumpControls = CIFilter.colorControls()
        clumpControls.inputImage = clumps
        clumpControls.saturation = 0
        clumpControls.contrast = 1.75
        clumpControls.brightness = -0.08
        clumps = clumpControls.outputImage!.cropped(to: CGRect(x: 0, y: 0, width: w, height: h))

        // Blend base dust + clumps with Soft Light (chalky)
        let soft = CIFilter.softLightBlendMode()
        soft.inputImage = clumps
        soft.backgroundImage = img
        img = soft.outputImage!.cropped(to: CGRect(x: 0, y: 0, width: w, height: h))

        // Render
        guard let cg = context.createCGImage(img, from: img.extent) else {
            return UIImage()
        }
        return UIImage(cgImage: cg)
    }
}
