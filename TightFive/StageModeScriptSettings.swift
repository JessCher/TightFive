import SwiftUI
import Observation

/// Settings store for Stage Mode Script configuration
@Observable
class StageModeScriptSettings {
    static let shared = StageModeScriptSettings()
    
    // MARK: - Display Settings
    
    /// Font size for script (points)
    var fontSize: Double {
        get {
            let value = UserDefaults.standard.double(forKey: "stageScript_fontSize")
            return value > 0 ? value : 24.0 // Default 24pt
        }
        set { UserDefaults.standard.set(newValue, forKey: "stageScript_fontSize") }
    }
    
    /// Line spacing
    var lineSpacing: Double {
        get {
            let value = UserDefaults.standard.double(forKey: "stageScript_lineSpacing")
            return value > 0 ? value : 10.0 // Default 10pt
        }
        set { UserDefaults.standard.set(newValue, forKey: "stageScript_lineSpacing") }
    }
    
    /// Text color for script
    var textColor: ScriptTextColor {
        get {
            let rawValue = UserDefaults.standard.string(forKey: "stageScript_textColor") ?? "white"
            return ScriptTextColor(rawValue: rawValue) ?? .white
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "stageScript_textColor") }
    }
    
    private init() {
        registerDefaults()
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
