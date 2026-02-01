import SwiftUI
import Observation

/// Settings store for Stage Mode Teleprompter configuration
@Observable
class StageModeTeleprompterSettings {
    static let shared = StageModeTeleprompterSettings()
    
    // MARK: - Display Settings
    
    /// Font size for teleprompter (points)
    var fontSize: Double {
        get {
            let value = UserDefaults.standard.double(forKey: "stageTeleprompter_fontSize")
            return value > 0 ? value : 34.0 // Default 34pt
        }
        set { UserDefaults.standard.set(newValue, forKey: "stageTeleprompter_fontSize") }
    }
    
    /// Line spacing
    var lineSpacing: Double {
        get {
            let value = UserDefaults.standard.double(forKey: "stageTeleprompter_lineSpacing")
            return value > 0 ? value : 14.0 // Default 14pt
        }
        set { UserDefaults.standard.set(newValue, forKey: "stageTeleprompter_lineSpacing") }
    }
    
    /// Text color for teleprompter
    var textColor: StageModeTeleprompterTextColor {
        get {
            let rawValue = UserDefaults.standard.string(forKey: "stageTeleprompter_textColor") ?? "white"
            return StageModeTeleprompterTextColor(rawValue: rawValue) ?? .white
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "stageTeleprompter_textColor") }
    }
    
    /// Scroll speed (points per second)
    var scrollSpeed: Double {
        get {
            let value = UserDefaults.standard.double(forKey: "stageTeleprompter_scrollSpeed")
            return value > 0 ? value : 40.0 // Default 40 pts/sec
        }
        set { UserDefaults.standard.set(newValue, forKey: "stageTeleprompter_scrollSpeed") }
    }
    
    /// Context window height
    var contextWindowHeight: Double {
        get {
            let value = UserDefaults.standard.double(forKey: "stageTeleprompter_contextWindowHeight")
            return value > 0 ? value : 180.0 // Default 180pt
        }
        set { UserDefaults.standard.set(newValue, forKey: "stageTeleprompter_contextWindowHeight") }
    }
    
    /// Context window color
    var contextWindowColor: StageModeContextWindowColor {
        get {
            let rawValue = UserDefaults.standard.string(forKey: "stageTeleprompter_contextWindowColor") ?? "yellow"
            return StageModeContextWindowColor(rawValue: rawValue) ?? .yellow
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "stageTeleprompter_contextWindowColor") }
    }
    
    /// Auto-start scrolling
    var autoStartScrolling: Bool {
        get { UserDefaults.standard.bool(forKey: "stageTeleprompter_autoStart") }
        set { UserDefaults.standard.set(newValue, forKey: "stageTeleprompter_autoStart") }
    }
    
    private init() {
        registerDefaults()
    }
    
    private func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            "stageTeleprompter_fontSize": 34.0,
            "stageTeleprompter_lineSpacing": 14.0,
            "stageTeleprompter_scrollSpeed": 40.0,
            "stageTeleprompter_contextWindowHeight": 180.0,
            "stageTeleprompter_autoStart": true
        ])
    }
    
    /// Reset all settings to defaults
    func resetToDefaults() {
        fontSize = 34.0
        lineSpacing = 14.0
        textColor = .white
        scrollSpeed = 40.0
        contextWindowHeight = 180.0
        contextWindowColor = .yellow
        autoStartScrolling = true
    }
}

// MARK: - Supporting Types

enum StageModeTeleprompterTextColor: String, CaseIterable, Identifiable {
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

enum StageModeContextWindowColor: String, CaseIterable, Identifiable {
    case yellow = "yellow"
    case green = "green"
    case blue = "blue"
    case white = "white"
    case red = "red"
    case cyan = "cyan"
    case black = "black"
    
    var id: String { rawValue }
    
    var color: Color {
        switch self {
        case .yellow: return TFTheme.yellow
        case .green: return .green
        case .blue: return .blue
        case .white: return .white
        case .red: return .red
        case .cyan: return .cyan
        case .black: return .black
        }
    }
    
    var displayName: String {
        rawValue.capitalized
    }
}

