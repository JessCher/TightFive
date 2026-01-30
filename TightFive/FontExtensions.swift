import SwiftUI

// MARK: - Font Extension for App-Wide Font Support

extension View {
    /// Applies the app's selected font with the specified size
    func tfFont(size: CGFloat, weight: Font.Weight = .regular) -> some View {
        let selectedFont = AppSettings.shared.appFont
        return self.font(selectedFont.font(size: size).weight(weight))
    }
    
    /// Applies the app's selected font using a text style
    func tfFont(_ style: Font.TextStyle) -> some View {
        let selectedFont = AppSettings.shared.appFont
        
        // Map text styles to approximate sizes
        let size: CGFloat = {
            switch style {
            case .largeTitle: return 34
            case .title: return 28
            case .title2: return 22
            case .title3: return 20
            case .headline: return 17
            case .body: return 17
            case .callout: return 16
            case .subheadline: return 15
            case .footnote: return 13
            case .caption: return 12
            case .caption2: return 11
            @unknown default: return 17
            }
        }()
        
        return self.font(selectedFont.font(size: size))
    }
}

// MARK: - Text Extension for Direct Font Application

extension Text {
    /// Applies the app's selected font with the specified size
    func tfFont(size: CGFloat, weight: Font.Weight = .regular) -> Text {
        let selectedFont = AppSettings.shared.appFont
        return self.font(selectedFont.font(size: size).weight(weight))
    }
}
