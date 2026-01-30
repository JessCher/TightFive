import Foundation
import SwiftUI
import Combine

/// User preferences for the app
@Observable
class AppSettings {
    /// Shared singleton instance
    static let shared = AppSettings()
    
    /// Internal trigger to force UI updates - read this in views to observe changes
    var updateTrigger: Int = 0
    
    /// Force a UI update
    private func notifyChange() {
        updateTrigger += 1
    }
    
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
    
    /// Grit level for shareable bit cards (0.0 = no grit, 1.0 = maximum grit)
    var bitCardGritLevel: Double {
        get {
            let value = UserDefaults.standard.double(forKey: "bitCardGritLevel")
            // If never set, default to 1.0 (maximum grit)
            return value == 0 && !UserDefaults.standard.bool(forKey: "bitCardGritLevelHasBeenSet") ? 1.0 : value
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "bitCardGritLevel")
            UserDefaults.standard.set(true, forKey: "bitCardGritLevelHasBeenSet")
        }
    }
    
    /// Grit level for app UI elements (tile cards, Quick Bit button, etc.)
    var appGritLevel: Double {
        get {
            let value = UserDefaults.standard.double(forKey: "appGritLevel")
            // If never set, default to 1.0 (maximum grit)
            return value == 0 && !UserDefaults.standard.bool(forKey: "appGritLevelHasBeenSet") ? 1.0 : value
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "appGritLevel")
            UserDefaults.standard.set(true, forKey: "appGritLevelHasBeenSet")
            notifyChange()
        }
    }
    
    /// Selected app font theme
    var appFont: AppFont {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: "appFont"),
                  let font = AppFont(rawValue: rawValue) else {
                return .systemDefault
            }
            return font
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "appFont")
            notifyChange()
        }
    }
    
    /// Global tile card theme (affects all tile cards in the app)
    var tileCardTheme: TileCardTheme {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: "tileCardTheme"),
                  let theme = TileCardTheme(rawValue: rawValue) else {
                return .darkGrit
            }
            return theme
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "tileCardTheme")
            notifyChange()
        }
    }
    
    /// Quick Bit button theme
    var quickBitTheme: TileCardTheme {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: "quickBitTheme"),
                  let theme = TileCardTheme(rawValue: rawValue) else {
                return .yellowGrit
            }
            return theme
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "quickBitTheme")
            notifyChange()
        }
    }
    
    /// Custom Quick Bit button background color (hex)
    var quickBitCustomColorHex: String {
        get {
            UserDefaults.standard.string(forKey: "quickBitCustomColorHex") ?? "#F4C430"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "quickBitCustomColorHex")
            notifyChange()
        }
    }
    
    /// Quick Bit grit enabled
    var quickBitGritEnabled: Bool {
        get {
            // Default to true if never set
            guard UserDefaults.standard.object(forKey: "quickBitGritEnabled") != nil else {
                return true
            }
            return UserDefaults.standard.bool(forKey: "quickBitGritEnabled")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "quickBitGritEnabled")
            notifyChange()
        }
    }
    
    /// Quick Bit grit layer 1 color (hex)
    var quickBitGritLayer1ColorHex: String {
        get {
            UserDefaults.standard.string(forKey: "quickBitGritLayer1ColorHex") ?? "#8B4513" // Brown
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "quickBitGritLayer1ColorHex")
            notifyChange()
        }
    }
    
    /// Quick Bit grit layer 2 color (hex)
    var quickBitGritLayer2ColorHex: String {
        get {
            UserDefaults.standard.string(forKey: "quickBitGritLayer2ColorHex") ?? "#000000" // Black
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "quickBitGritLayer2ColorHex")
            notifyChange()
        }
    }
    
    /// Quick Bit grit layer 3 color (hex)
    var quickBitGritLayer3ColorHex: String {
        get {
            UserDefaults.standard.string(forKey: "quickBitGritLayer3ColorHex") ?? "#CC6600" // Orange
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "quickBitGritLayer3ColorHex")
            notifyChange()
        }
    }
    
    // MARK: - Tile Card Customization
    
    /// Custom Tile Card background color (hex)
    var tileCardCustomColorHex: String {
        get {
            UserDefaults.standard.string(forKey: "tileCardCustomColorHex") ?? "#3A3A3A" // TFCard color
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "tileCardCustomColorHex")
            notifyChange()
        }
    }
    
    /// Tile Card grit enabled
    var tileCardGritEnabled: Bool {
        get {
            // Default to true if never set
            guard UserDefaults.standard.object(forKey: "tileCardGritEnabled") != nil else {
                return true
            }
            return UserDefaults.standard.bool(forKey: "tileCardGritEnabled")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "tileCardGritEnabled")
            notifyChange()
        }
    }
    
    /// Tile Card grit layer 1 color (hex)
    var tileCardGritLayer1ColorHex: String {
        get {
            UserDefaults.standard.string(forKey: "tileCardGritLayer1ColorHex") ?? "#F4C430" // Yellow
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "tileCardGritLayer1ColorHex")
            notifyChange()
        }
    }
    
    /// Tile Card grit layer 2 color (hex)
    var tileCardGritLayer2ColorHex: String {
        get {
            UserDefaults.standard.string(forKey: "tileCardGritLayer2ColorHex") ?? "#FFFFFF4D" // White with opacity
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "tileCardGritLayer2ColorHex")
            notifyChange()
        }
    }
    
    /// Tile Card grit layer 3 color (hex)
    var tileCardGritLayer3ColorHex: String {
        get {
            UserDefaults.standard.string(forKey: "tileCardGritLayer3ColorHex") ?? "#FFFFFF1A" // White with lower opacity
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "tileCardGritLayer3ColorHex")
            notifyChange()
        }
    }
    
    /// Returns true if any of the card elements are using a textured theme
    var hasAnyTexturedTheme: Bool {
        return bitCardFrameColor.hasTexture || 
               bitCardBottomBarColor.hasTexture || 
               bitWindowTheme == .chalkboard || 
               bitWindowTheme == .yellowGrit
    }
    
    /// Calculates the adjusted grit density for shareable bit cards
    /// - Parameter baseDensity: The maximum density value (at gritLevel = 1.0)
    /// - Returns: The scaled density value
    func adjustedBitCardGritDensity(_ baseDensity: Int) -> Int {
        return Int(Double(baseDensity) * bitCardGritLevel)
    }
    
    /// Calculates the adjusted grit density for app UI elements
    /// - Parameter baseDensity: The maximum density value (at gritLevel = 1.0)
    /// - Returns: The scaled density value
    func adjustedAppGritDensity(_ baseDensity: Int) -> Int {
        return Int(Double(baseDensity) * appGritLevel)
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
        case .chalkboard: return "Dark Grit"
        case .yellowGrit: return "Yellow Grit"
        case .custom: return "Custom Color"
        }
    }
    
    var description: String {
        switch self {
        case .default: return "Standard card background"
        case .black: return "Solid black"
        case .white: return "Solid white"
        case .chalkboard: return "Dark with subtle texture"
        case .yellowGrit: return "Warm yellow with grit"
        case .custom: return "Choose your own color"
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
        case .chalkboard: return "Dark Grit"
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

/// Available themes for tile cards and Quick Bit button
enum TileCardTheme: String, CaseIterable, Identifiable {
    case darkGrit = "darkGrit"
    case yellowGrit = "yellowGrit"
    case custom = "custom"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .darkGrit: return "Dark Grit"
        case .yellowGrit: return "Yellow Grit"
        case .custom: return "Custom"
        }
    }
    
    var description: String {
        switch self {
        case .darkGrit: return "Dark with subtle texture"
        case .yellowGrit: return "Warm yellow with grit"
        case .custom: return "Customize colors and texture"
        }
    }
    
    var baseColor: Color {
        switch self {
        case .darkGrit: return Color("TFCard")
        case .yellowGrit: return Color("TFYellow")
        case .custom: return Color("TFCard") // Fallback, should be overridden
        }
    }
}

/// Available font themes for the app
enum AppFont: String, CaseIterable, Identifiable {
    case systemDefault = "system"
    case helveticaNeue = "HelveticaNeue"
    case georgia = "Georgia"
    case menlo = "Menlo"
    case palatino = "Palatino"
    case timesNewRoman = "Times New Roman"
    case trebuchet = "Trebuchet MS"
    case verdana = "Verdana"
    case courier = "Courier"
    case avenir = "Avenir"
    case baskerville = "Baskerville"
    case americanTypewriter = "American Typewriter"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .systemDefault: return "System Default"
        case .helveticaNeue: return "Helvetica Neue"
        case .georgia: return "Georgia"
        case .menlo: return "Menlo"
        case .palatino: return "Palatino"
        case .timesNewRoman: return "Times New Roman"
        case .trebuchet: return "Trebuchet MS"
        case .verdana: return "Verdana"
        case .courier: return "Courier"
        case .avenir: return "Avenir"
        case .baskerville: return "Baskerville"
        case .americanTypewriter: return "American Typewriter"
        }
    }
    
    var description: String {
        switch self {
        case .systemDefault: return "iOS system font (San Francisco)"
        case .helveticaNeue: return "Clean, modern sans-serif"
        case .georgia: return "Classic, readable serif"
        case .menlo: return "Monospaced, technical"
        case .palatino: return "Elegant serif, great for reading"
        case .timesNewRoman: return "Traditional serif, formal"
        case .trebuchet: return "Friendly sans-serif"
        case .verdana: return "Web-optimized sans-serif"
        case .courier: return "Classic monospaced"
        case .avenir: return "Geometric sans-serif, stylish"
        case .baskerville: return "Refined serif, sophisticated"
        case .americanTypewriter: return "Classic typewriter style"
        }
    }
    
    var category: String {
        switch self {
        case .systemDefault, .helveticaNeue, .trebuchet, .verdana, .avenir:
            return "Sans-Serif"
        case .georgia, .palatino, .timesNewRoman, .baskerville:
            return "Serif"
        case .menlo, .courier, .americanTypewriter:
            return "Monospaced"
        }
    }
    
    /// Returns a Font for the given size
    func font(size: CGFloat) -> Font {
        if self == .systemDefault {
            return .system(size: size)
        } else {
            return .custom(rawValue, size: size)
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

