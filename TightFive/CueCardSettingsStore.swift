import SwiftUI
import Observation

/// Settings store for Cue Card (Stage Mode) configuration
@Observable
class CueCardSettingsStore {
    static let shared = CueCardSettingsStore()
    
    // MARK: - Stage Mode Type
    
    /// Stage mode presentation type
    var stageModeType: StageModeType = .cueCards {
        didSet { UserDefaults.standard.set(stageModeType.rawValue, forKey: "cueCard_stageModeType") }
    }
    
    // MARK: - Auto-Advance Settings
    
    /// Enable automatic card advancement via speech recognition
    var autoAdvanceEnabled: Bool = true {
        didSet { UserDefaults.standard.set(autoAdvanceEnabled, forKey: "cueCard_autoAdvanceEnabled") }
    }
    
    /// Show phrase detection feedback UI
    var showPhraseFeedback: Bool = true {
        didSet { UserDefaults.standard.set(showPhraseFeedback, forKey: "cueCard_showPhraseFeedback") }
    }
    
    // MARK: - Display Settings
    
    /// Font size for cue cards (points)
    var fontSize: Double = 36.0 {
        didSet { UserDefaults.standard.set(fontSize, forKey: "cueCard_fontSize") }
    }
    
    /// Line spacing multiplier
    var lineSpacing: Double = 12.0 {
        didSet { UserDefaults.standard.set(lineSpacing, forKey: "cueCard_lineSpacing") }
    }
    
    /// Text color for cards
    var textColor: CueCardTextColor = .white {
        didSet { UserDefaults.standard.set(textColor.rawValue, forKey: "cueCard_textColor") }
    }
    
    // MARK: - Recognition Settings
    
    /// Sensitivity for exit phrase detection (0.0 - 1.0)
    /// Lower = more lenient (easier to trigger), Higher = stricter (harder to trigger)
    var exitPhraseSensitivity: Double = 0.6 {
        didSet { UserDefaults.standard.set(exitPhraseSensitivity, forKey: "cueCard_exitSensitivity") }
    }
    
    /// Sensitivity for anchor phrase detection (0.0 - 1.0)
    /// Lower = more lenient (easier to confirm), Higher = stricter (harder to confirm)
    var anchorPhraseSensitivity: Double = 0.5 {
        didSet { UserDefaults.standard.set(anchorPhraseSensitivity, forKey: "cueCard_anchorSensitivity") }
    }
    
    // MARK: - Advance Button Settings

    /// Color for manual advance buttons in Stage Mode
    var advanceButtonColor: AdvanceButtonColor = .white {
        didSet { UserDefaults.standard.set(advanceButtonColor.rawValue, forKey: "cueCard_advanceButtonColor") }
    }

    /// Size for manual advance buttons in Stage Mode
    var advanceButtonSize: AdvanceButtonSize = .medium {
        didSet { UserDefaults.standard.set(advanceButtonSize.rawValue, forKey: "cueCard_advanceButtonSize") }
    }

    // MARK: - Recording Settings

    /// Whether to record audio during Stage Mode performances (default: on)
    var recordingEnabled: Bool = true {
        didSet { UserDefaults.standard.set(recordingEnabled, forKey: "cueCard_recordingEnabled") }
    }

    // MARK: - Animation Settings

    /// Enable card transition animations
    var enableAnimations: Bool = true {
        didSet { UserDefaults.standard.set(enableAnimations, forKey: "cueCard_enableAnimations") }
    }

    /// Transition style
    var transitionStyle: CardTransitionStyle = .slide {
        didSet { UserDefaults.standard.set(transitionStyle.rawValue, forKey: "cueCard_transitionStyle") }
    }
    
    // MARK: - Initialization
    
    private init() {
        registerDefaults()
        loadFromUserDefaults()
    }
    
    /// Load values from UserDefaults
    private func loadFromUserDefaults() {
        let defaults = UserDefaults.standard
        
        if let stageModeTypeRaw = defaults.string(forKey: "cueCard_stageModeType"),
           let stageModeTypeValue = StageModeType(rawValue: stageModeTypeRaw) {
            stageModeType = stageModeTypeValue
        }
        
        autoAdvanceEnabled = defaults.bool(forKey: "cueCard_autoAdvanceEnabled")
        showPhraseFeedback = defaults.bool(forKey: "cueCard_showPhraseFeedback")
        
        if let fontSizeValue = defaults.object(forKey: "cueCard_fontSize") as? Double {
            fontSize = fontSizeValue
        }
        
        if let lineSpacingValue = defaults.object(forKey: "cueCard_lineSpacing") as? Double {
            lineSpacing = lineSpacingValue
        }
        
        if let textColorRaw = defaults.string(forKey: "cueCard_textColor"),
           let textColorValue = CueCardTextColor(rawValue: textColorRaw) {
            textColor = textColorValue
        }
        
        if let exitSensitivityValue = defaults.object(forKey: "cueCard_exitSensitivity") as? Double {
            exitPhraseSensitivity = exitSensitivityValue
        }
        
        if let anchorSensitivityValue = defaults.object(forKey: "cueCard_anchorSensitivity") as? Double {
            anchorPhraseSensitivity = anchorSensitivityValue
        }
        
        enableAnimations = defaults.bool(forKey: "cueCard_enableAnimations")

        if let transitionStyleRaw = defaults.string(forKey: "cueCard_transitionStyle"),
           let transitionStyleValue = CardTransitionStyle(rawValue: transitionStyleRaw) {
            transitionStyle = transitionStyleValue
        }

        if let advanceButtonColorRaw = defaults.string(forKey: "cueCard_advanceButtonColor"),
           let advanceButtonColorValue = AdvanceButtonColor(rawValue: advanceButtonColorRaw) {
            advanceButtonColor = advanceButtonColorValue
        }

        if let advanceButtonSizeRaw = defaults.string(forKey: "cueCard_advanceButtonSize"),
           let advanceButtonSizeValue = AdvanceButtonSize(rawValue: advanceButtonSizeRaw) {
            advanceButtonSize = advanceButtonSizeValue
        }

        if defaults.object(forKey: "cueCard_recordingEnabled") != nil {
            recordingEnabled = defaults.bool(forKey: "cueCard_recordingEnabled")
        }
    }
    
    private func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            "cueCard_autoAdvanceEnabled": true,
            "cueCard_showPhraseFeedback": true,
            "cueCard_fontSize": 36.0,
            "cueCard_lineSpacing": 12.0,
            "cueCard_exitSensitivity": 0.6,
            "cueCard_anchorSensitivity": 0.5,
            "cueCard_enableAnimations": true,
            "cueCard_recordingEnabled": true
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
        advanceButtonColor = .white
        advanceButtonSize = .medium
        recordingEnabled = true
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
    
    /// Check if this mode is available for a given setlist
    func isAvailable(for setlist: Setlist?) -> Bool {
        guard let setlist = setlist else { return true }
        
        switch self {
        case .cueCards:
            // Cue cards available if modular mode OR traditional mode with custom cards
            return setlist.currentScriptMode == .modular || setlist.hasCustomCueCards
        case .script, .teleprompter:
            // Script and teleprompter always available
            return true
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

enum AdvanceButtonColor: String, CaseIterable, Identifiable {
    case white = "white"
    case yellow = "yellow"
    case green = "green"
    case blue = "blue"
    case red = "red"
    case orange = "orange"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .white: return .white
        case .yellow: return Color("TFYellow")
        case .green: return .green
        case .blue: return .blue
        case .red: return .red
        case .orange: return .orange
        }
    }

    var displayName: String {
        rawValue.capitalized
    }
}
enum AdvanceButtonSize: String, CaseIterable, Identifiable {
    case small = "small"
    case medium = "medium"
    case large = "large"
    case extraLarge = "extraLarge"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        case .extraLarge: return "Extra Large"
        }
    }

    /// Button icon size (SF Symbol point size)
    var iconSize: CGFloat {
        switch self {
        case .small: return 20
        case .medium: return 28
        case .large: return 36
        case .extraLarge: return 44
        }
    }

    /// Button frame size
    var frameSize: CGFloat {
        switch self {
        case .small: return 44
        case .medium: return 60
        case .large: return 76
        case .extraLarge: return 92
        }
    }
}

