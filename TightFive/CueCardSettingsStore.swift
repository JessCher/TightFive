import SwiftUI
import Observation

/// Settings store for Cue Card (Stage Mode) configuration
@Observable
class CueCardSettingsStore {
    static let shared = CueCardSettingsStore()
    
    // MARK: - Stage Mode Type
    
    /// Stage mode presentation type
    var stageModeType: StageModeType {
        get {
            let rawValue = UserDefaults.standard.string(forKey: "cueCard_stageModeType") ?? "cueCards"
            return StageModeType(rawValue: rawValue) ?? .cueCards
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "cueCard_stageModeType") }
    }
    
    // MARK: - Auto-Advance Settings
    
    /// Enable automatic card advancement via speech recognition
    var autoAdvanceEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "cueCard_autoAdvanceEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "cueCard_autoAdvanceEnabled") }
    }
    
    /// Show phrase detection feedback UI
    var showPhraseFeedback: Bool {
        get { UserDefaults.standard.bool(forKey: "cueCard_showPhraseFeedback") }
        set { UserDefaults.standard.set(newValue, forKey: "cueCard_showPhraseFeedback") }
    }
    
    // MARK: - Display Settings
    
    /// Font size for cue cards (points)
    var fontSize: Double {
        get { 
            let value = UserDefaults.standard.double(forKey: "cueCard_fontSize")
            return value > 0 ? value : 36.0 // Default 36pt
        }
        set { UserDefaults.standard.set(newValue, forKey: "cueCard_fontSize") }
    }
    
    /// Line spacing multiplier
    var lineSpacing: Double {
        get {
            let value = UserDefaults.standard.double(forKey: "cueCard_lineSpacing")
            return value > 0 ? value : 12.0 // Default 12pt
        }
        set { UserDefaults.standard.set(newValue, forKey: "cueCard_lineSpacing") }
    }
    
    /// Text color for cards
    var textColor: CueCardTextColor {
        get {
            let rawValue = UserDefaults.standard.string(forKey: "cueCard_textColor") ?? "white"
            return CueCardTextColor(rawValue: rawValue) ?? .white
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "cueCard_textColor") }
    }
    
    // MARK: - Recognition Settings
    
    /// Sensitivity for exit phrase detection (0.0 - 1.0)
    var exitPhraseSensitivity: Double {
        get {
            let value = UserDefaults.standard.double(forKey: "cueCard_exitSensitivity")
            return value > 0 ? value : 0.6 // Default 60%
        }
        set { UserDefaults.standard.set(newValue, forKey: "cueCard_exitSensitivity") }
    }
    
    /// Sensitivity for anchor phrase detection (0.0 - 1.0)
    var anchorPhraseSensitivity: Double {
        get {
            let value = UserDefaults.standard.double(forKey: "cueCard_anchorSensitivity")
            return value > 0 ? value : 0.5 // Default 50%
        }
        set { UserDefaults.standard.set(newValue, forKey: "cueCard_anchorSensitivity") }
    }
    
    // MARK: - Animation Settings
    
    /// Enable card transition animations
    var enableAnimations: Bool {
        get { UserDefaults.standard.bool(forKey: "cueCard_enableAnimations") }
        set { UserDefaults.standard.set(newValue, forKey: "cueCard_enableAnimations") }
    }
    
    /// Transition style
    var transitionStyle: CardTransitionStyle {
        get {
            let rawValue = UserDefaults.standard.string(forKey: "cueCard_transitionStyle") ?? "slide"
            return CardTransitionStyle(rawValue: rawValue) ?? .slide
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "cueCard_transitionStyle") }
    }
    
    // MARK: - Initialization
    
    private init() {
        // Set defaults on first launch
        registerDefaults()
    }
    
    private func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            "cueCard_autoAdvanceEnabled": true,
            "cueCard_showPhraseFeedback": true,
            "cueCard_fontSize": 36.0,
            "cueCard_lineSpacing": 12.0,
            "cueCard_exitSensitivity": 0.6,
            "cueCard_anchorSensitivity": 0.5,
            "cueCard_enableAnimations": true
        ])
    }
    
    /// Reset all settings to defaults
    func resetToDefaults() {
        stageModeType = .cueCards
        autoAdvanceEnabled = true
        showPhraseFeedback = true
        fontSize = 36.0
        lineSpacing = 12.0
        textColor = .white
        exitPhraseSensitivity = 0.6
        anchorPhraseSensitivity = 0.5
        enableAnimations = true
        transitionStyle = .slide
    }
}

// MARK: - Supporting Types

enum StageModeType: String, CaseIterable, Identifiable {
    case cueCards = "cueCards"
    case script = "script"
    case teleprompter = "teleprompter"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .cueCards: return "Cue Cards"
        case .script: return "Script"
        case .teleprompter: return "Teleprompter"
        }
    }
    
    var description: String {
        switch self {
        case .cueCards: return "Voice-driven cards with anchor and exit phrases"
        case .script: return "Static scrollable script view"
        case .teleprompter: return "Auto-scrolling teleprompter view"
        }
    }
}

enum CueCardTextColor: String, CaseIterable, Identifiable {
    case white = "white"
    case yellow = "yellow"
    case green = "green"
    
    var id: String { rawValue }
    
    var color: Color {
        switch self {
        case .white: return .white
        case .yellow: return Color("TFYellow")
        case .green: return .green
        }
    }
    
    var displayName: String {
        rawValue.capitalized
    }
}

enum CardTransitionStyle: String, CaseIterable, Identifiable {
    case slide = "slide"
    case fade = "fade"
    case scale = "scale"
    
    var id: String { rawValue }
    
    var displayName: String {
        rawValue.capitalized
    }
}
