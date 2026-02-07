import SwiftUI

// MARK: - Haptic Feedback Manager

/// Centralized haptic feedback manager that respects accessibility settings
struct HapticManager {
    /// Trigger haptic feedback with the specified style
    /// - Parameter style: The impact style (light, medium, heavy, etc.)
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        guard AppSettings.shared.hapticsEnabled else { return }
        
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    
    /// Trigger selection haptic feedback
    static func selection() {
        guard AppSettings.shared.hapticsEnabled else { return }
        
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
    
    /// Trigger notification haptic feedback
    /// - Parameter type: The notification type (success, warning, error)
    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard AppSettings.shared.hapticsEnabled else { return }
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
}

// MARK: - Touch Target Size Modifier

extension View {
    /// Applies larger touch targets when the accessibility setting is enabled
    /// - Parameters:
    ///   - minSize: The minimum touch target size (default 44x44 per Apple HIG)
    ///   - largeSize: The larger touch target size when accessibility setting is on
    /// - Returns: A view with the appropriate touch target sizing
    func accessibleTouchTarget(minSize: CGFloat = 44, largeSize: CGFloat = 60) -> some View {
        self.modifier(AccessibleTouchTargetModifier(minSize: minSize, largeSize: largeSize))
    }
}

private struct AccessibleTouchTargetModifier: ViewModifier {
    let minSize: CGFloat
    let largeSize: CGFloat
    @State private var settings = AppSettings.shared
    
    func body(content: Content) -> some View {
        content
            .frame(minWidth: settings.largerTouchTargets ? largeSize : minSize,
                   minHeight: settings.largerTouchTargets ? largeSize : minSize)
    }
}

// MARK: - Sensory Feedback Modifier (SwiftUI Native)

extension View {
    /// Adds haptic feedback to a view interaction, respecting accessibility settings
    /// - Parameters:
    ///   - feedback: The sensory feedback style
    ///   - trigger: The value to observe for triggering feedback
    /// - Returns: A view with conditional sensory feedback
    func accessibleSensoryFeedback<T: Equatable>(
        _ feedback: SensoryFeedback,
        trigger: T
    ) -> some View {
        self.modifier(AccessibleSensoryFeedbackModifier(feedback: feedback, trigger: trigger))
    }
}

private struct AccessibleSensoryFeedbackModifier<T: Equatable>: ViewModifier {
    let feedback: SensoryFeedback
    let trigger: T
    @State private var settings = AppSettings.shared
    
    func body(content: Content) -> some View {
        if settings.hapticsEnabled {
            content.sensoryFeedback(feedback, trigger: trigger)
        } else {
            content
        }
    }
}

// MARK: - Button Style with Accessibility Features

struct AccessibleStyledButtonStyle: ButtonStyle {
    let baseColor: Color
    let accentColor: Color
    @State private var settings = AppSettings.shared
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, settings.largerTouchTargets ? 20 : 16)
            .padding(.vertical, settings.largerTouchTargets ? 16 : 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(baseColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(accentColor, lineWidth: configuration.isPressed ? 2 : 0)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { oldValue, newValue in
                if newValue {
                    HapticManager.impact(.light)
                }
            }
    }
}

// MARK: - Toggle with Haptic Feedback

struct AccessibleToggle: View {
    let title: String
    @Binding var isOn: Bool
    var tint: Color = Color("TFYellow")
    
    var body: some View {
        Toggle(title, isOn: $isOn)
            .tint(tint)
            .onChange(of: isOn) { oldValue, newValue in
                HapticManager.selection()
            }
    }
}

// MARK: - Example Usage Guide

/*
 
 HOW TO USE THESE ACCESSIBILITY HELPERS:
 
 1. HAPTIC FEEDBACK:
 
    Button("Delete") {
        HapticManager.impact(.heavy)
        deleteItem()
    }
 
    Button("Select") {
        HapticManager.selection()
        selectItem()
    }
 
    // Using SwiftUI's sensoryFeedback (iOS 17+):
    Button("Tap me") {
        triggerAction()
    }
    .accessibleSensoryFeedback(.impact, trigger: someValue)
 
 2. LARGER TOUCH TARGETS:
 
    Button("Small Button") {
        action()
    }
    .accessibleTouchTarget() // Applies 44pt min, 60pt when setting enabled
 
    // Custom sizes:
    Button("Custom Button") {
        action()
    }
    .accessibleTouchTarget(minSize: 50, largeSize: 70)
 
 3. ACCESSIBLE STYLED BUTTON:
 
    Button("Styled Button") {
        HapticManager.impact()
        performAction()
    }
    .buttonStyle(AccessibleStyledButtonStyle(
        baseColor: Color("TFCard"),
        accentColor: Color("TFYellow")
    ))
 
 4. ACCESSIBLE TOGGLE:
 
    AccessibleToggle(title: "Enable Feature", isOn: $isEnabled)
    
    // With custom tint:
    AccessibleToggle(title: "Dark Mode", isOn: $isDarkMode, tint: .blue)
 
 */
