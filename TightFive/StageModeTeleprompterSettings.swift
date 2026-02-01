import SwiftUI
import Observation

/// Settings store for Stage Mode Teleprompter configuration
@Observable
class StageModeTeleprompterSettings {
    static let shared = StageModeTeleprompterSettings()
    
    // MARK: - Display Settings
    
    /// Font size for teleprompter (points)
    var fontSize: Double = 34.0 {
        didSet { UserDefaults.standard.set(fontSize, forKey: "stageTeleprompter_fontSize") }
    }
    
    /// Line spacing
    var lineSpacing: Double = 14.0 {
        didSet { UserDefaults.standard.set(lineSpacing, forKey: "stageTeleprompter_lineSpacing") }
    }
    
    /// Text color for teleprompter
    var textColor: StageModeTeleprompterTextColor = .white {
        didSet { UserDefaults.standard.set(textColor.rawValue, forKey: "stageTeleprompter_textColor") }
    }
    
    /// Scroll speed (points per second)
    var scrollSpeed: Double = 40.0 {
        didSet { UserDefaults.standard.set(scrollSpeed, forKey: "stageTeleprompter_scrollSpeed") }
    }
    
    /// Context window height
    var contextWindowHeight: Double = 180.0 {
        didSet { UserDefaults.standard.set(contextWindowHeight, forKey: "stageTeleprompter_contextWindowHeight") }
    }
    
    /// Context window color
    var contextWindowColor: StageModeContextWindowColor = .yellow {
        didSet { UserDefaults.standard.set(contextWindowColor.rawValue, forKey: "stageTeleprompter_contextWindowColor") }
    }
    
    /// Auto-start scrolling
    var autoStartScrolling: Bool = true {
        didSet { UserDefaults.standard.set(autoStartScrolling, forKey: "stageTeleprompter_autoStart") }
    }
    
    private init() {
        registerDefaults()
        loadFromUserDefaults()
    }
    
    /// Load values from UserDefaults
    private func loadFromUserDefaults() {
        let defaults = UserDefaults.standard
        
        if let fontSizeValue = defaults.object(forKey: "stageTeleprompter_fontSize") as? Double {
            fontSize = fontSizeValue
        }
        
        if let lineSpacingValue = defaults.object(forKey: "stageTeleprompter_lineSpacing") as? Double {
            lineSpacing = lineSpacingValue
        }
        
        if let textColorRaw = defaults.string(forKey: "stageTeleprompter_textColor"),
           let textColorValue = StageModeTeleprompterTextColor(rawValue: textColorRaw) {
            textColor = textColorValue
        }
        
        if let scrollSpeedValue = defaults.object(forKey: "stageTeleprompter_scrollSpeed") as? Double {
            scrollSpeed = scrollSpeedValue
        }
        
        if let contextWindowHeightValue = defaults.object(forKey: "stageTeleprompter_contextWindowHeight") as? Double {
            contextWindowHeight = contextWindowHeightValue
        }
        
        if let contextWindowColorRaw = defaults.string(forKey: "stageTeleprompter_contextWindowColor"),
           let contextWindowColorValue = StageModeContextWindowColor(rawValue: contextWindowColorRaw) {
            contextWindowColor = contextWindowColorValue
        }
        
        autoStartScrolling = defaults.bool(forKey: "stageTeleprompter_autoStart")
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

