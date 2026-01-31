// AppGroupConstants.swift
// TightFive
//
// Shared constants for App Group communication between main app and widgets.
// Copyright © 2025 TightFive. All rights reserved.

import Foundation

/// Constants for App Group data sharing between main app and widget extensions.
///
/// **IMPORTANT**: The App Group identifier must match exactly in:
/// - Main app's entitlements file
/// - Widget extension's entitlements file
/// - Xcode project capabilities for both targets
///
/// To configure:
/// 1. Go to Signing & Capabilities for TightFive target
/// 2. Add "App Groups" capability
/// 3. Create group: "group.com.tightfive.app"
/// 4. Repeat for QuickBitWidget target
enum AppGroupConstants {
    
    // MARK: - App Group Identifier
    
    /// The shared App Group identifier.
    /// Must match the identifier in both targets' entitlements.
    static let suiteName = "group.com.tightfive.app"
    
    // MARK: - UserDefaults Keys
    
    /// Keys for UserDefaults stored in the shared container.
    enum Keys {
        /// Quick Bit theme (raw value of TileCardTheme)
        static let quickBitTheme = "widget.quickBitTheme"
        
        /// Custom color hex when theme is .custom
        static let quickBitCustomColorHex = "widget.quickBitCustomColorHex"
        
        /// Whether grit texture is enabled
        static let quickBitGritEnabled = "widget.quickBitGritEnabled"
        
        /// Grit layer 1 color hex
        static let quickBitGritLayer1Hex = "widget.quickBitGritLayer1Hex"
        
        /// Grit layer 2 color hex
        static let quickBitGritLayer2Hex = "widget.quickBitGritLayer2Hex"
        
        /// Grit layer 3 color hex
        static let quickBitGritLayer3Hex = "widget.quickBitGritLayer3Hex"
        
        /// App grit level (0.0 to 1.0)
        static let appGritLevel = "widget.appGritLevel"
        
        /// Pending Quick Bit text (for widget → app communication)
        static let pendingQuickBitText = "widget.pendingQuickBitText"
        
        /// Timestamp of pending Quick Bit
        static let pendingQuickBitTimestamp = "widget.pendingQuickBitTimestamp"
        
        /// Flag indicating widget requested Quick Bit editor launch
        static let widgetRequestedQuickBitLaunch = "widget.requestedQuickBitLaunch"
    }
    
    // MARK: - Shared UserDefaults
    
    /// UserDefaults instance for the shared App Group container.
    /// Returns nil if App Group is not properly configured.
    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }
    
    // MARK: - SwiftData Container URL
    
    /// URL for the shared SwiftData store in the App Group container.
    /// This allows the widget to read/write to the same database as the main app.
    static var sharedStoreURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: suiteName)?
            .appendingPathComponent("TightFive.store")
    }
    
    /// Directory URL for the shared App Group container.
    static var sharedContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suiteName)
    }
}

// MARK: - Widget Theme Configuration

/// Lightweight struct for passing theme configuration to the widget.
/// This avoids importing the full AppSettings in the widget extension.
struct WidgetThemeConfiguration: Codable, Equatable {
    
    enum Theme: String, Codable {
        case darkGrit
        case yellowGrit
        case custom
    }
    
    let theme: Theme
    let customColorHex: String
    let gritEnabled: Bool
    let gritLayer1Hex: String
    let gritLayer2Hex: String
    let gritLayer3Hex: String
    let gritLevel: Double
    
    /// Default Yellow Grit theme configuration
    static let `default` = WidgetThemeConfiguration(
        theme: .yellowGrit,
        customColorHex: "#F4C430",
        gritEnabled: true,
        gritLayer1Hex: "#8B4513",  // Brown
        gritLayer2Hex: "#000000",  // Black
        gritLayer3Hex: "#CC6600",  // Orange
        gritLevel: 1.0
    )
    
    /// Load configuration from shared UserDefaults
    static func loadFromSharedDefaults() -> WidgetThemeConfiguration {
        guard let defaults = AppGroupConstants.sharedDefaults else {
            return .default
        }
        
        let themeRaw = defaults.string(forKey: AppGroupConstants.Keys.quickBitTheme) ?? "yellowGrit"
        let theme = Theme(rawValue: themeRaw) ?? .yellowGrit
        
        return WidgetThemeConfiguration(
            theme: theme,
            customColorHex: defaults.string(forKey: AppGroupConstants.Keys.quickBitCustomColorHex) ?? "#F4C430",
            gritEnabled: defaults.object(forKey: AppGroupConstants.Keys.quickBitGritEnabled) as? Bool ?? true,
            gritLayer1Hex: defaults.string(forKey: AppGroupConstants.Keys.quickBitGritLayer1Hex) ?? "#8B4513",
            gritLayer2Hex: defaults.string(forKey: AppGroupConstants.Keys.quickBitGritLayer2Hex) ?? "#000000",
            gritLayer3Hex: defaults.string(forKey: AppGroupConstants.Keys.quickBitGritLayer3Hex) ?? "#CC6600",
            gritLevel: defaults.double(forKey: AppGroupConstants.Keys.appGritLevel).nonZeroOr(1.0)
        )
    }
    
    /// Save configuration to shared UserDefaults
    func saveToSharedDefaults() {
        guard let defaults = AppGroupConstants.sharedDefaults else { return }
        
        defaults.set(theme.rawValue, forKey: AppGroupConstants.Keys.quickBitTheme)
        defaults.set(customColorHex, forKey: AppGroupConstants.Keys.quickBitCustomColorHex)
        defaults.set(gritEnabled, forKey: AppGroupConstants.Keys.quickBitGritEnabled)
        defaults.set(gritLayer1Hex, forKey: AppGroupConstants.Keys.quickBitGritLayer1Hex)
        defaults.set(gritLayer2Hex, forKey: AppGroupConstants.Keys.quickBitGritLayer2Hex)
        defaults.set(gritLayer3Hex, forKey: AppGroupConstants.Keys.quickBitGritLayer3Hex)
        defaults.set(gritLevel, forKey: AppGroupConstants.Keys.appGritLevel)
    }
}

// MARK: - Helper Extensions

private extension Double {
    /// Returns self if non-zero, otherwise returns the default value.
    func nonZeroOr(_ defaultValue: Double) -> Double {
        self == 0 ? defaultValue : self
    }
}
