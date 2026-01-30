import Foundation
import SwiftUI

/// User preferences for the app
@Observable
class AppSettings {
    /// Shared singleton instance
    static let shared = AppSettings()
    
    /// Bit card frame color for shareable cards (background/border)
    var bitCardFrameColor: BitCardFrameColor {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: "bitCardFrameColor"),
                  let color = BitCardFrameColor(rawValue: rawValue) else {
                return .default
            }
            return color
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "bitCardFrameColor")
        }
    }
    
    /// Bit card bottom bar color for shareable cards
    var bitCardBottomBarColor: BitCardFrameColor {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: "bitCardBottomBarColor"),
                  let color = BitCardFrameColor(rawValue: rawValue) else {
                return .default
            }
            return color
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "bitCardBottomBarColor")
        }
    }
    
    /// Bit window theme for the text area of shareable cards
    var bitWindowTheme: BitWindowTheme {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: "bitWindowTheme"),
                  let theme = BitWindowTheme(rawValue: rawValue) else {
                return .chalkboard
            }
            return theme
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "bitWindowTheme")
        }
    }
    
    /// Custom hex color for frame (when .custom is selected)
    var customFrameColorHex: String {
        get {
            UserDefaults.standard.string(forKey: "customFrameColorHex") ?? "#3A3A3A"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "customFrameColorHex")
        }
    }
    
    /// Custom hex color for bottom bar (when .custom is selected)
    var customBottomBarColorHex: String {
        get {
            UserDefaults.standard.string(forKey: "customBottomBarColorHex") ?? "#3A3A3A"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "customBottomBarColorHex")
        }
    }
    
    private init() {}
}

/// Available frame colors for shareable bit cards
enum BitCardFrameColor: String, CaseIterable, Identifiable {
    case `default` = "default"
    case black = "black"
    case white = "white"
    case chalkboard = "chalkboard"
    case yellowGrit = "yellowGrit"
    case custom = "custom"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .default: return "Default"
        case .black: return "Black"
        case .white: return "White"
        case .chalkboard: return "Dark grit"
        case .yellowGrit: return "Yellow grit"
        case .custom: return "Custom Color"
        }
    }
    
    func color(customHex: String? = nil) -> Color {
        switch self {
        case .default: return Color("TFCard")
        case .black: return Color.black
        case .white: return Color.white
        case .chalkboard: return Color("TFCard")
        case .yellowGrit: return Color("TFYellow")
        case .custom: 
            if let hex = customHex {
                return Color(hex: hex) ?? Color("TFCard")
            }
            return Color("TFCard")
        }
    }
    
    /// Returns true if this color option should render with textured layers
    var hasTexture: Bool {
        switch self {
        case .chalkboard, .yellowGrit: return true
        default: return false
        }
    }
    
    /// Returns the appropriate texture theme for rendering
    var textureTheme: BitWindowTheme? {
        switch self {
        case .chalkboard: return .chalkboard
        case .yellowGrit: return .yellowGrit
        default: return nil
        }
    }
}
/// Available themes for the bit window (text area) on shareable cards
enum BitWindowTheme: String, CaseIterable, Identifiable {
    case chalkboard = "Dark Grit"
    case yellowGrit = "Yellow Grit"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .chalkboard: return "Chalkboard"
        case .yellowGrit: return "Yellow Grit"
        }
    }
    
    var description: String {
        switch self {
        case .chalkboard: return "Dark with subtle texture"
        case .yellowGrit: return "Warm yellow with grit"
        }
    }
}

// MARK: - Color Hex Extension
extension Color {
    /// Initialize a Color from a hex string (supports #RRGGBB format)
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        
        guard Scanner(string: hex).scanHexInt64(&int) else { return nil }
        
        let r, g, b: UInt64
        switch hex.count {
        case 6: // RGB (24-bit)
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            return nil
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
    
    /// Convert a Color to hex string (approximate, works for simple colors)
    func toHex() -> String? {
        guard let components = UIColor(self).cgColor.components,
              components.count >= 3 else {
            return nil
        }
        
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        
        return String(format: "#%02lX%02lX%02lX",
                     lroundf(r * 255),
                     lroundf(g * 255),
                     lroundf(b * 255))
    }
}

