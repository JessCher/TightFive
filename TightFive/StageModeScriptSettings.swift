import SwiftUI
import Observation

/// Settings store for Stage Mode Script configuration
@Observable
class StageModeScriptSettings {
    static let shared = StageModeScriptSettings()
    
    // MARK: - Display Settings
    
    /// Font size for script (points)
    var fontSize: Double = 24.0 {
        didSet { UserDefaults.standard.set(fontSize, forKey: "stageScript_fontSize") }
    }
    
    /// Line spacing
    var lineSpacing: Double = 10.0 {
        didSet { UserDefaults.standard.set(lineSpacing, forKey: "stageScript_lineSpacing") }
    }
    
    /// Text color for script
    var textColor: ScriptTextColor = .white {
        didSet { UserDefaults.standard.set(textColor.rawValue, forKey: "stageScript_textColor") }
    }
    
    private init() {
        registerDefaults()
        loadFromUserDefaults()
    }
    
    /// Load values from UserDefaults
    private func loadFromUserDefaults() {
        let defaults = UserDefaults.standard
        
        if let fontSizeValue = defaults.object(forKey: "stageScript_fontSize") as? Double {
            fontSize = fontSizeValue
        }
        
        if let lineSpacingValue = defaults.object(forKey: "stageScript_lineSpacing") as? Double {
            lineSpacing = lineSpacingValue
        }
        
        if let textColorRaw = defaults.string(forKey: "stageScript_textColor"),
           let textColorValue = ScriptTextColor(rawValue: textColorRaw) {
            textColor = textColorValue
        }
    }
    
    private func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            "stageScript_fontSize": 24.0,
            "stageScript_lineSpacing": 10.0
        ])
    }
    
    /// Reset all settings to defaults
    func resetToDefaults() {
        fontSize = 24.0
        lineSpacing = 10.0
        textColor = .white
    }
}

// MARK: - Supporting Types

enum ScriptTextColor: String, CaseIterable, Identifiable {
    case white = "white"
    case yellow = "yellow"
    case green = "green"
    case blue = "blue"
    case red = "red"
    case cyan = "cyan"
    case purple = "purple"
    
    var id: String { rawValue }
    
    var color: Color {
        switch self {
        case .white: return .white
        case .yellow: return TFTheme.yellow
        case .green: return .green
        case .blue: return .blue
        case .red: return .red
        case .cyan: return .cyan
        case .purple: return .purple
        }
    }
    
    var displayName: String {
        rawValue.capitalized
    }
}
