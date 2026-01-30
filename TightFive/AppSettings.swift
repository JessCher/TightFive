import Foundation
import SwiftUI

/// User preferences for the app
@Observable
class AppSettings {
    /// Shared singleton instance
    static let shared = AppSettings()
    
    /// Bit card frame color for shareable cards
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
    
    private init() {}
}

/// Available frame colors for shareable bit cards
enum BitCardFrameColor: String, CaseIterable, Identifiable {
    case `default` = "default"
    case red = "red"
    case black = "black"
    case green = "green"
    case blue = "blue"
    case purple = "purple"
    case brown = "brown"
    case white = "white"
    case yellow = "yellow"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .default: return "Default"
        case .red: return "Red"
        case .black: return "Black"
        case .green: return "Green"
        case .blue: return "Blue"
        case .purple: return "Purple"
        case .brown: return "Brown"
        case .white: return "White"
        case .yellow: return "Yellow"
        }
    }
    
    var color: Color {
        switch self {
        case .default: return Color("TFCard")
        case .red: return Color(red: 0.8, green: 0.2, blue: 0.2)
        case .black: return Color.black
        case .green: return Color(red: 0.2, green: 0.6, blue: 0.3)
        case .blue: return Color(red: 0.2, green: 0.4, blue: 0.8)
        case .purple: return Color(red: 0.6, green: 0.3, blue: 0.8)
        case .brown: return Color(red: 0.6, green: 0.4, blue: 0.3)
        case .white: return Color.white
        case .yellow: return Color(red: 1.0, green: 0.85, blue: 0.1)
        }
    }
}
