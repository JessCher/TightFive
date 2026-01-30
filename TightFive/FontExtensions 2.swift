import SwiftUI

// MARK: - Font Extension for App-Wide Font Support

extension View {
    /// Applies the app's selected font with the specified size (with size multiplier applied)
    func appFont(size: CGFloat, weight: Font.Weight = .regular) -> some View {
        let selectedFont = AppSettings.shared.appFont
        let multiplier = AppSettings.shared.appFontSizeMultiplier
        let adjustedSize = size * multiplier
        return self.font(selectedFont.font(size: adjustedSize).weight(weight))
    }
    
    /// Applies the app's selected font using a text style (with size multiplier applied)
    func appFont(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> some View {
        let selectedFont = AppSettings.shared.appFont
        let multiplier = AppSettings.shared.appFontSizeMultiplier
        
        // Map text styles to approximate sizes
        let baseSize: CGFloat = {
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
        
        let adjustedSize = baseSize * multiplier
        return self.font(selectedFont.font(size: adjustedSize).weight(weight))
    }
}

// MARK: - Text Extension for Direct Font Application

extension Text {
    /// Applies the app's selected font with the specified size (with size multiplier applied)
    func appFont(size: CGFloat, weight: Font.Weight = .regular) -> Text {
        let selectedFont = AppSettings.shared.appFont
        let multiplier = AppSettings.shared.appFontSizeMultiplier
        let adjustedSize = size * multiplier
        return self.font(selectedFont.font(size: adjustedSize).weight(weight))
    }
    
    /// Applies the app's selected font using a text style (with size multiplier applied)
    func appFont(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Text {
        let selectedFont = AppSettings.shared.appFont
        let multiplier = AppSettings.shared.appFontSizeMultiplier
        
        let baseSize: CGFloat = {
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
        
        let adjustedSize = baseSize * multiplier
        return self.font(selectedFont.font(size: adjustedSize).weight(weight))
    }
}

// MARK: - Global Font Color Environment

/// Environment key for the app's selected font color
struct AppFontColorKey: EnvironmentKey {
    static let defaultValue: Color = .white
}

extension EnvironmentValues {
    var appFontColor: Color {
        get { self[AppFontColorKey.self] }
        set { self[AppFontColorKey.self] = newValue }
    }
}

// MARK: - Global Font Environment

/// Environment key for the app's selected font
struct AppFontKey: EnvironmentKey {
    static let defaultValue: AppFont = .systemDefault
}

extension EnvironmentValues {
    var appFont: AppFont {
        get { self[AppFontKey.self] }
        set { self[AppFontKey.self] = newValue }
    }
}

/// View modifier that applies the global app font to all text in its hierarchy
struct GlobalFontModifier: ViewModifier {
    @Environment(AppSettings.self) private var appSettings
    
    func body(content: Content) -> some View {
        let fontColor = Color(hex: appSettings.appFontColorHex) ?? .white
        let multiplier = appSettings.appFontSizeMultiplier
        let adjustedSize = 17 * multiplier // Default body font
        
        return content
            .environment(\.appFont, appSettings.appFont)
            .environment(\.appFontColor, fontColor)
            .font(appSettings.appFont.font(size: adjustedSize))
    }
}

extension View {
    /// Applies the global app font to all views in the hierarchy
    func withGlobalFont() -> some View {
        modifier(GlobalFontModifier())
    }
    
    /// Applies the app's custom font color
    func appFontColor() -> some View {
        let color = AppSettings.shared.fontColor
        return self.foregroundStyle(color)
    }
}

