import SwiftUI

// MARK: - Font Extension for App-Wide Font Support

extension View {
    /// Applies the app's selected font with the specified size (with size multiplier applied)
    func appFont(size: CGFloat, weight: Font.Weight = .regular) -> some View {
        let selectedFont = AppSettings.shared.appFont
        let multiplier = AppSettings.shared.appFontSizeMultiplier
        let boldText = AppSettings.shared.boldText
        let adjustedSize = size * multiplier
        
        // Apply bold weight if bold text is enabled
        let finalWeight = boldText ? .bold : weight
        
        return self.font(selectedFont.font(size: adjustedSize).weight(finalWeight))
    }
    
    /// Applies the app's selected font using a text style (with size multiplier applied)
    func appFont(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> some View {
        let selectedFont = AppSettings.shared.appFont
        let multiplier = AppSettings.shared.appFontSizeMultiplier
        let boldText = AppSettings.shared.boldText
        
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
        
        // Apply bold weight if bold text is enabled
        let finalWeight = boldText ? .bold : weight
        
        return self.font(selectedFont.font(size: adjustedSize).weight(finalWeight))
    }
}

// MARK: - Text Extension for Direct Font Application

extension Text {
    /// Applies the app's selected font with the specified size (with size multiplier applied)
    func appFont(size: CGFloat, weight: Font.Weight = .regular) -> Text {
        let selectedFont = AppSettings.shared.appFont
        let multiplier = AppSettings.shared.appFontSizeMultiplier
        let boldText = AppSettings.shared.boldText
        let adjustedSize = size * multiplier
        
        // Apply bold weight if bold text is enabled
        let finalWeight = boldText ? .bold : weight
        
        return self.font(selectedFont.font(size: adjustedSize).weight(finalWeight))
    }
    
    /// Applies the app's selected font using a text style (with size multiplier applied)
    func appFont(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Text {
        let selectedFont = AppSettings.shared.appFont
        let multiplier = AppSettings.shared.appFontSizeMultiplier
        let boldText = AppSettings.shared.boldText
        
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
        
        // Apply bold weight if bold text is enabled
        let finalWeight = boldText ? .bold : weight
        
        return self.font(selectedFont.font(size: adjustedSize).weight(finalWeight))
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
    
    // Cache computed values to avoid repeated access
    private var fontColor: Color {
        Color(hex: appSettings.appFontColorHex) ?? .white
    }
    
    private var adjustedSize: CGFloat {
        17 * appSettings.appFontSizeMultiplier // Default body font
    }
    
    func body(content: Content) -> some View {
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

// MARK: - Accessibility View Modifiers
extension View {
    /// Applies animation with accessibility support (respects reduce motion)
    func accessibleAnimation<V: Equatable>(_ animation: Animation?, value: V) -> some View {
        let shouldAnimate = !AppSettings.shared.reduceMotion
        return self.animation(shouldAnimate ? animation : nil, value: value)
    }
    
    /// Applies animation with accessibility support (no binding value)
    func accessibleAnimation(_ animation: Animation?) -> some View {
        let shouldAnimate = !AppSettings.shared.reduceMotion
        return self.animation(shouldAnimate ? animation : nil)
    }
    
    /// Applies high contrast styling when enabled
    func accessibleContrast() -> some View {
        let highContrast = AppSettings.shared.highContrast
        return self.modifier(HighContrastModifier(enabled: highContrast))
    }
    
    /// Applies larger touch targets for buttons when enabled
    func accessibleTapTarget() -> some View {
        let largerTargets = AppSettings.shared.largerTouchTargets
        return self.modifier(LargerTouchTargetModifier(enabled: largerTargets))
    }
    
    /// Triggers haptic feedback if enabled
    func hapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        guard AppSettings.shared.hapticsEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
}

/// Modifier to increase contrast for better visibility
private struct HighContrastModifier: ViewModifier {
    let enabled: Bool
    
    func body(content: Content) -> some View {
        if enabled {
            content
                .brightness(0.05)
                .contrast(1.2)
        } else {
            content
        }
    }
}

/// Modifier to increase touch target sizes
private struct LargerTouchTargetModifier: ViewModifier {
    let enabled: Bool
    
    func body(content: Content) -> some View {
        if enabled {
            content
                .padding(4)
        } else {
            content
        }
    }
}

/// Button style that respects accessibility settings
struct AccessibleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .accessibleAnimation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .accessibleTapTarget()
            .onChange(of: configuration.isPressed) { oldValue, newValue in
                if newValue {
                    configuration.label.hapticFeedback(.light)
                }
            }
    }
}

// MARK: - Animation Helper

/// Executes withAnimation only if reduce motion is disabled
func withAccessibleAnimation<Result>(_ animation: Animation? = .default, _ body: () throws -> Result) rethrows -> Result {
    if AppSettings.shared.reduceMotion {
        return try body()
    } else {
        return try withAnimation(animation, body)
    }
}


