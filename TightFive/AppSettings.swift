import Foundation
import SwiftUI

/// User preferences for the app
@Observable
class AppSettings {
    /// Shared singleton instance
    static let shared = AppSettings()

    /// Internal trigger to force UI updates - read this in views to observe changes
    var updateTrigger: Int = 0
    
    /// iCloud Key-Value Store for syncing settings across devices
    private let cloudStore = NSUbiquitousKeyValueStore.default
    
    /// Local UserDefaults for immediate local storage and fallback
    private let localStore = UserDefaults.standard
    
    /// Pending sync task, used for debouncing
    private var pendingSyncTask: Task<Void, Never>?

    /// Tracks last sync time for throttling
    private var lastSyncTime: Date = Date.distantPast

    /// Force a UI update
    private func notifyChange() {
        updateTrigger += 1
    }
    
    /// Force refresh from iCloud (public method for app lifecycle)
    func forceRefresh() {
        cloudStore.synchronize()
        notifyChange()
    }

    /// Registers observation dependency for computed properties.
    /// The @Observable macro only tracks stored properties. Since all settings are
    /// computed (backed by iCloud KV Store), reading updateTrigger here ties the
    /// computed property access to a tracked stored property so SwiftUI views
    /// properly invalidate when settings change.
    private func observeChanges() {
        _ = updateTrigger
    }
    
    // MARK: - Storage Helpers
    
    /// Get a string value with proper cloud/local priority
    private func getString(forKey key: String, default defaultValue: String? = nil) -> String? {
        // Always check cloud first, then local, then default
        if let cloudValue = cloudStore.string(forKey: key) {
            // Sync to local for consistency
            if localStore.string(forKey: key) != cloudValue {
                localStore.set(cloudValue, forKey: key)
            }
            return cloudValue
        }
        
        if let localValue = localStore.string(forKey: key) {
            // If local exists but cloud doesn't, sync to cloud
            cloudStore.set(localValue, forKey: key)
            scheduleSyncIfNeeded()
            return localValue
        }
        
        return defaultValue
    }
    
    /// Set a string value with reliable sync
    private func setString(_ value: String, forKey key: String) {
        localStore.set(value, forKey: key)
        cloudStore.set(value, forKey: key)
        scheduleSyncIfNeeded()
    }
    
    /// Get a double value with proper cloud/local priority
    private func getDouble(forKey key: String) -> Double {
        if let cloudValue = cloudStore.object(forKey: key) as? Double {
            if localStore.double(forKey: key) != cloudValue {
                localStore.set(cloudValue, forKey: key)
            }
            return cloudValue
        }
        
        let localValue = localStore.double(forKey: key)
        if localValue != 0 || localStore.object(forKey: key) != nil {
            cloudStore.set(localValue, forKey: key)
            scheduleSyncIfNeeded()
            return localValue
        }
        
        return 0
    }
    
    /// Set a double value with reliable sync
    private func setDouble(_ value: Double, forKey key: String) {
        localStore.set(value, forKey: key)
        cloudStore.set(value, forKey: key)
        scheduleSyncIfNeeded()
    }
    
    /// Get a bool value with proper cloud/local priority
    private func getBool(forKey key: String) -> Bool {
        if let cloudValue = cloudStore.object(forKey: key) as? Bool {
            if localStore.bool(forKey: key) != cloudValue {
                localStore.set(cloudValue, forKey: key)
            }
            return cloudValue
        }
        
        let localValue = localStore.bool(forKey: key)
        if localStore.object(forKey: key) != nil {
            cloudStore.set(localValue, forKey: key)
            scheduleSyncIfNeeded()
            return localValue
        }
        
        return false
    }
    
    /// Set a bool value with reliable sync
    private func setBool(_ value: Bool, forKey key: String) {
        localStore.set(value, forKey: key)
        cloudStore.set(value, forKey: key)
        scheduleSyncIfNeeded()
    }
    
    /// Get an int value with proper cloud/local priority
    private func getInt(forKey key: String) -> Int {
        if let cloudValue = cloudStore.object(forKey: key) as? Int64 {
            let intValue = Int(cloudValue)
            if localStore.integer(forKey: key) != intValue {
                localStore.set(intValue, forKey: key)
            }
            return intValue
        }
        
        let localValue = localStore.integer(forKey: key)
        if localValue != 0 || localStore.object(forKey: key) != nil {
            cloudStore.set(Int64(localValue), forKey: key)
            scheduleSyncIfNeeded()
            return localValue
        }
        
        return 0
    }
    
    /// Set an int value with reliable sync
    private func setInt(_ value: Int, forKey key: String) {
        localStore.set(value, forKey: key)
        cloudStore.set(Int64(value), forKey: key)
        scheduleSyncIfNeeded()
    }
    
    /// Check if a value has been explicitly set (exists in either store)
    private func hasBeenSet(forKey key: String) -> Bool {
        return cloudStore.object(forKey: key) != nil || localStore.object(forKey: key) != nil
    }
    
    /// Schedule a debounced sync. Safe to call from any context.
    private func scheduleSyncIfNeeded() {
        // Cancel any in-flight debounce
        pendingSyncTask?.cancel()

        pendingSyncTask = Task { @MainActor in
            // Debounce: wait for writes to settle before syncing
            try? await Task.sleep(for: .milliseconds(500))

            guard !Task.isCancelled else { return }

            // Throttle: don't sync more than once per second
            let now = Date()
            guard now.timeIntervalSince(lastSyncTime) >= 1.0 else { return }
            lastSyncTime = now

            let synced = cloudStore.synchronize()
            print(synced ? "✅ iCloud settings synced successfully" : "⚠️ iCloud sync delayed or unavailable (offline?)")
        }
    }

    /// Bit card frame color for shareable cards (background/border)
    var bitCardFrameColor: BitCardFrameColor {
        get {
            observeChanges()
            guard let rawValue = getString(forKey: "bitCardFrameColor"),
                  let color = BitCardFrameColor(rawValue: rawValue) else {
                return .default
            }
            return color
        }
        set {
            setString(newValue.rawValue, forKey: "bitCardFrameColor")
            notifyChange()
        }
    }

    /// Bit card bottom bar color for shareable cards
    var bitCardBottomBarColor: BitCardFrameColor {
        get {
            observeChanges()
            guard let rawValue = getString(forKey: "bitCardBottomBarColor"),
                  let color = BitCardFrameColor(rawValue: rawValue) else {
                return .default
            }
            return color
        }
        set {
            setString(newValue.rawValue, forKey: "bitCardBottomBarColor")
            notifyChange()
        }
    }

    /// Bit window theme for the text area of shareable cards
    var bitWindowTheme: BitWindowTheme {
        get {
            observeChanges()
            guard let rawValue = getString(forKey: "bitWindowTheme"),
                  let theme = BitWindowTheme(rawValue: rawValue) else {
                return .chalkboard
            }
            return theme
        }
        set {
            setString(newValue.rawValue, forKey: "bitWindowTheme")
            notifyChange()
        }
    }

    /// Custom hex color for frame (when .custom is selected)
    var customFrameColorHex: String {
        get {
            observeChanges()
            return getString(forKey: "customFrameColorHex", default: "#3A3A3A") ?? "#3A3A3A"
        }
        set {
            setString(newValue, forKey: "customFrameColorHex")
            notifyChange()
        }
    }

    /// Custom hex color for bottom bar (when .custom is selected)
    var customBottomBarColorHex: String {
        get {
            observeChanges()
            return getString(forKey: "customBottomBarColorHex", default: "#3A3A3A") ?? "#3A3A3A"
        }
        set {
            setString(newValue, forKey: "customBottomBarColorHex")
            notifyChange()
        }
    }

    /// Grit level for shareable bit cards (0.0 = no grit, 1.0 = maximum grit)
    var bitCardGritLevel: Double {
        get {
            observeChanges()
            let value = getDouble(forKey: "bitCardGritLevel")
            // If never set, default to 1.0 (maximum grit)
            return value == 0 && !hasBeenSet(forKey: "bitCardGritLevelHasBeenSet") ? 1.0 : value
        }
        set {
            setDouble(newValue, forKey: "bitCardGritLevel")
            setBool(true, forKey: "bitCardGritLevelHasBeenSet")
            notifyChange()
        }
    }
    // MARK: - Bit Card Custom Grit Colors

    /// Enable custom grit for frame when using custom color
    var bitCardFrameGritEnabled: Bool {
        get {
            observeChanges()
            return getBool(forKey: "bitCardFrameGritEnabled")
        }
        set {
            setBool(newValue, forKey: "bitCardFrameGritEnabled")
            notifyChange()
        }
    }

    var bitCardFrameGritLayer1ColorHex: String {
        get {
            observeChanges()
            return getString(forKey: "bitCardFrameGritLayer1ColorHex", default: "#8B4513") ?? "#8B4513"
        }
        set {
            setString(newValue, forKey: "bitCardFrameGritLayer1ColorHex")
            notifyChange()
        }
    }

    var bitCardFrameGritLayer2ColorHex: String {
        get {
            observeChanges()
            return getString(forKey: "bitCardFrameGritLayer2ColorHex", default: "#000000") ?? "#000000"
        }
        set {
            setString(newValue, forKey: "bitCardFrameGritLayer2ColorHex")
            notifyChange()
        }
    }

    var bitCardFrameGritLayer3ColorHex: String {
        get {
            observeChanges()
            return getString(forKey: "bitCardFrameGritLayer3ColorHex", default: "#CC6600") ?? "#CC6600"
        }
        set {
            setString(newValue, forKey: "bitCardFrameGritLayer3ColorHex")
            notifyChange()
        }
    }

    /// Enable custom grit for bottom bar when using custom color
    var bitCardBottomBarGritEnabled: Bool {
        get {
            observeChanges()
            return getBool(forKey: "bitCardBottomBarGritEnabled")
        }
        set {
            setBool(newValue, forKey: "bitCardBottomBarGritEnabled")
            notifyChange()
        }
    }

    var bitCardBottomBarGritLayer1ColorHex: String {
        get {
            observeChanges()
            return getString(forKey: "bitCardBottomBarGritLayer1ColorHex", default: "#8B4513") ?? "#8B4513"
        }
        set {
            setString(newValue, forKey: "bitCardBottomBarGritLayer1ColorHex")
            notifyChange()
        }
    }

    var bitCardBottomBarGritLayer2ColorHex: String {
        get {
            observeChanges()
            return getString(forKey: "bitCardBottomBarGritLayer2ColorHex", default: "#000000") ?? "#000000"
        }
        set {
            setString(newValue, forKey: "bitCardBottomBarGritLayer2ColorHex")
            notifyChange()
        }
    }

    var bitCardBottomBarGritLayer3ColorHex: String {
        get {
            observeChanges()
            return getString(forKey: "bitCardBottomBarGritLayer3ColorHex", default: "#CC6600") ?? "#CC6600"
        }
        set {
            setString(newValue, forKey: "bitCardBottomBarGritLayer3ColorHex")
            notifyChange()
        }
    }

    // MARK: - Bit Card Window (Text Area) Custom Settings

    /// Custom hex color for window (when using custom color)
    var customWindowColorHex: String {
        get {
            observeChanges()
            return getString(forKey: "customWindowColorHex", default: "#3A3A3A") ?? "#3A3A3A"
        }
        set {
            setString(newValue, forKey: "customWindowColorHex")
            notifyChange()
        }
    }

    /// Enable custom grit for window when using custom color
    var bitCardWindowGritEnabled: Bool {
        get {
            observeChanges()
            return getBool(forKey: "bitCardWindowGritEnabled")
        }
        set {
            setBool(newValue, forKey: "bitCardWindowGritEnabled")
            notifyChange()
        }
    }

    var bitCardWindowGritLayer1ColorHex: String {
        get {
            observeChanges()
            return getString(forKey: "bitCardWindowGritLayer1ColorHex", default: "#8B4513") ?? "#8B4513"
        }
        set {
            setString(newValue, forKey: "bitCardWindowGritLayer1ColorHex")
            notifyChange()
        }
    }

    var bitCardWindowGritLayer2ColorHex: String {
        get {
            observeChanges()
            return getString(forKey: "bitCardWindowGritLayer2ColorHex", default: "#000000") ?? "#000000"
        }
        set {
            setString(newValue, forKey: "bitCardWindowGritLayer2ColorHex")
            notifyChange()
        }
    }

    var bitCardWindowGritLayer3ColorHex: String {
        get {
            observeChanges()
            return getString(forKey: "bitCardWindowGritLayer3ColorHex", default: "#CC6600") ?? "#CC6600"
        }
        set {
            setString(newValue, forKey: "bitCardWindowGritLayer3ColorHex")
            notifyChange()
        }
    }

    // MARK: - Individual Grit Level Sliders for Each Section

    /// Frame grit level (0.0 = no grit, 1.0 = maximum grit)
    var bitCardFrameGritLevel: Double {
        get {
            observeChanges()
            let value = getDouble(forKey: "bitCardFrameGritLevel")
            return value == 0 && !hasBeenSet(forKey: "bitCardFrameGritLevelHasBeenSet") ? 1.0 : value
        }
        set {
            setDouble(newValue, forKey: "bitCardFrameGritLevel")
            setBool(true, forKey: "bitCardFrameGritLevelHasBeenSet")
            notifyChange()
        }
    }

    /// Bottom bar grit level (0.0 = no grit, 1.0 = maximum grit)
    var bitCardBottomBarGritLevel: Double {
        get {
            observeChanges()
            let value = getDouble(forKey: "bitCardBottomBarGritLevel")
            return value == 0 && !hasBeenSet(forKey: "bitCardBottomBarGritLevelHasBeenSet") ? 1.0 : value
        }
        set {
            setDouble(newValue, forKey: "bitCardBottomBarGritLevel")
            setBool(true, forKey: "bitCardBottomBarGritLevelHasBeenSet")
            notifyChange()
        }
    }

    /// Window grit level (0.0 = no grit, 1.0 = maximum grit)
    var bitCardWindowGritLevel: Double {
        get {
            observeChanges()
            let value = getDouble(forKey: "bitCardWindowGritLevel")
            return value == 0 && !hasBeenSet(forKey: "bitCardWindowGritLevelHasBeenSet") ? 1.0 : value
        }
        set {
            setDouble(newValue, forKey: "bitCardWindowGritLevel")
            setBool(true, forKey: "bitCardWindowGritLevelHasBeenSet")
            notifyChange()
        }
    }

    /// Grit level for app UI elements (tile cards, Quick Bit button, etc.)
    var appGritLevel: Double {
        get {
            observeChanges()
            let value = getDouble(forKey: "appGritLevel")
            // If never set, default to 1.0 (maximum grit)
            return value == 0 && !hasBeenSet(forKey: "appGritLevelHasBeenSet") ? 1.0 : value
        }
        set {
            setDouble(newValue, forKey: "appGritLevel")
            setBool(true, forKey: "appGritLevelHasBeenSet")
            notifyChange()
        }
    }

    /// Selected app font theme
    var appFont: AppFont {
        get {
            observeChanges()
            guard let rawValue = getString(forKey: "appFont"),
                  let font = AppFont(rawValue: rawValue) else {
                return .systemDefault
            }
            return font
        }
        set {
            setString(newValue.rawValue, forKey: "appFont")
            notifyChange()
        }
    }

    /// App font color (hex)
    var appFontColorHex: String {
        get {
            observeChanges()
            return getString(forKey: "appFontColorHex", default: "#FFFFFF") ?? "#FFFFFF" // Default white
        }
        set {
            setString(newValue, forKey: "appFontColorHex")
            notifyChange()
        }
    }

    /// App font size multiplier (1.0 = default, 0.8 = small, 1.2 = large)
    var appFontSizeMultiplier: Double {
        get {
            observeChanges()
            let value = getDouble(forKey: "appFontSizeMultiplier")
            // If never set, default to 1.0 (normal size)
            return value == 0 && !hasBeenSet(forKey: "appFontSizeMultiplierHasBeenSet") ? 1.0 : value
        }
        set {
            setDouble(newValue, forKey: "appFontSizeMultiplier")
            setBool(true, forKey: "appFontSizeMultiplierHasBeenSet")
            notifyChange()
        }
    }

    /// Global tile card theme (affects all tile cards in the app)
    var tileCardTheme: TileCardTheme {
        get {
            observeChanges()
            guard let rawValue = getString(forKey: "tileCardTheme"),
                  let theme = TileCardTheme(rawValue: rawValue) else {
                return .darkGrit
            }
            return theme
        }
        set {
            setString(newValue.rawValue, forKey: "tileCardTheme")
            notifyChange()
        }
    }

    /// Quick Bit button theme
    var quickBitTheme: TileCardTheme {
        get {
            observeChanges()
            guard let rawValue = getString(forKey: "quickBitTheme"),
                  let theme = TileCardTheme(rawValue: rawValue) else {
                return .yellowGrit
            }
            return theme
        }
        set {
            setString(newValue.rawValue, forKey: "quickBitTheme")
            notifyChange()
        }
    }

    /// Custom Quick Bit button background color (hex)
    var quickBitCustomColorHex: String {
        get {
            observeChanges()
            return getString(forKey: "quickBitCustomColorHex", default: "#F4C430") ?? "#F4C430"
        }
        set {
            setString(newValue, forKey: "quickBitCustomColorHex")
            notifyChange()
        }
    }

    /// Quick Bit grit enabled
    var quickBitGritEnabled: Bool {
        get {
            observeChanges()
            // Default to true if never set
            guard hasBeenSet(forKey: "quickBitGritEnabled") else {
                return true
            }
            return getBool(forKey: "quickBitGritEnabled")
        }
        set {
            setBool(newValue, forKey: "quickBitGritEnabled")
            notifyChange()
        }
    }

    /// Quick Bit grit layer 1 color (hex)
    var quickBitGritLayer1ColorHex: String {
        get {
            observeChanges()
            return getString(forKey: "quickBitGritLayer1ColorHex", default: "#8B4513") ?? "#8B4513" // Brown
        }
        set {
            setString(newValue, forKey: "quickBitGritLayer1ColorHex")
            notifyChange()
        }
    }

    /// Quick Bit grit layer 2 color (hex)
    var quickBitGritLayer2ColorHex: String {
        get {
            observeChanges()
            return getString(forKey: "quickBitGritLayer2ColorHex", default: "#000000") ?? "#000000" // Black
        }
        set {
            setString(newValue, forKey: "quickBitGritLayer2ColorHex")
            notifyChange()
        }
    }

    /// Quick Bit grit layer 3 color (hex)
    var quickBitGritLayer3ColorHex: String {
        get {
            observeChanges()
            return getString(forKey: "quickBitGritLayer3ColorHex", default: "#CC6600") ?? "#CC6600" // Orange
        }
        set {
            setString(newValue, forKey: "quickBitGritLayer3ColorHex")
            notifyChange()
        }
    }

    // MARK: - Tile Card Customization

    /// Custom Tile Card background color (hex)
    var tileCardCustomColorHex: String {
        get {
            observeChanges()
            return getString(forKey: "tileCardCustomColorHex", default: "#3A3A3A") ?? "#3A3A3A" // TFCard color
        }
        set {
            setString(newValue, forKey: "tileCardCustomColorHex")
            notifyChange()
        }
    }

    /// Tile Card grit enabled
    var tileCardGritEnabled: Bool {
        get {
            observeChanges()
            // Default to true if never set
            guard hasBeenSet(forKey: "tileCardGritEnabled") else {
                return true
            }
            return getBool(forKey: "tileCardGritEnabled")
        }
        set {
            setBool(newValue, forKey: "tileCardGritEnabled")
            notifyChange()
        }
    }

    /// Tile Card grit layer 1 color (hex)
    var tileCardGritLayer1ColorHex: String {
        get {
            observeChanges()
            return getString(forKey: "tileCardGritLayer1ColorHex", default: "#F4C430") ?? "#F4C430" // Yellow
        }
        set {
            setString(newValue, forKey: "tileCardGritLayer1ColorHex")
            notifyChange()
        }
    }

    /// Tile Card grit layer 2 color (hex)
    var tileCardGritLayer2ColorHex: String {
        get {
            observeChanges()
            return getString(forKey: "tileCardGritLayer2ColorHex", default: "#FFFFFF4D") ?? "#FFFFFF4D" // White with opacity
        }
        set {
            setString(newValue, forKey: "tileCardGritLayer2ColorHex")
            notifyChange()
        }
    }

    /// Tile Card grit layer 3 color (hex)
    var tileCardGritLayer3ColorHex: String {
        get {
            observeChanges()
            return getString(forKey: "tileCardGritLayer3ColorHex", default: "#FFFFFF1A") ?? "#FFFFFF1A" // White with lower opacity
        }
        set {
            setString(newValue, forKey: "tileCardGritLayer3ColorHex")
            notifyChange()
        }
    }

    // MARK: - Background Customization

    /// Base background color (hex)
    var backgroundBaseColorHex: String {
        get {
            observeChanges()
            return getString(forKey: "backgroundBaseColorHex", default: "#3A3A3A") ?? "#3A3A3A" // TFBackground default
        }
        set {
            setString(newValue, forKey: "backgroundBaseColorHex")
            notifyChange()
        }
    }

    /// Cloud count (renamed from clumps)
    var backgroundCloudCount: Int {
        get {
            observeChanges()
            let value = getInt(forKey: "backgroundCloudCount")
            return value == 0 && !hasBeenSet(forKey: "backgroundCloudCountHasBeenSet") ? 80 : value
        }
        set {
            setInt(newValue, forKey: "backgroundCloudCount")
            setBool(true, forKey: "backgroundCloudCountHasBeenSet")
            notifyChange()
        }
    }

    /// Cloud opacity
    var backgroundCloudOpacity: Double {
        get {
            observeChanges()
            let value = getDouble(forKey: "backgroundCloudOpacity")
            return value == 0 && !hasBeenSet(forKey: "backgroundCloudOpacityHasBeenSet") ? 0.18 : value
        }
        set {
            setDouble(newValue, forKey: "backgroundCloudOpacity")
            setBool(true, forKey: "backgroundCloudOpacityHasBeenSet")
            notifyChange()
        }
    }

    /// Cloud color 1 (yellow) - hex
    var backgroundCloudColor1Hex: String {
        get {
            observeChanges()
            return getString(forKey: "backgroundCloudColor1Hex", default: "#F4C430") ?? "#F4C430" // TFYellow
        }
        set {
            setString(newValue, forKey: "backgroundCloudColor1Hex")
            notifyChange()
        }
    }

    /// Cloud color 2 (blue) - hex
    var backgroundCloudColor2Hex: String {
        get {
            observeChanges()
            return getString(forKey: "backgroundCloudColor2Hex", default: "#0000FF") ?? "#0000FF" // Blue
        }
        set {
            setString(newValue, forKey: "backgroundCloudColor2Hex")
            notifyChange()
        }
    }

    /// Cloud color 3 (white) - hex
    var backgroundCloudColor3Hex: String {
        get {
            observeChanges()
            return getString(forKey: "backgroundCloudColor3Hex", default: "#FFFFFF") ?? "#FFFFFF" // White
        }
        set {
            setString(newValue, forKey: "backgroundCloudColor3Hex")
            notifyChange()
        }
    }

    /// Cloud horizontal offset (-1.0 to 1.0, representing left to right)
    var backgroundCloudOffsetX: Double {
        get {
            observeChanges()
            return getDouble(forKey: "backgroundCloudOffsetX")
        }
        set {
            setDouble(newValue, forKey: "backgroundCloudOffsetX")
            notifyChange()
        }
    }

    /// Cloud vertical offset (-1.0 to 1.0, representing top to bottom)
    var backgroundCloudOffsetY: Double {
        get {
            observeChanges()
            return getDouble(forKey: "backgroundCloudOffsetY")
        }
        set {
            setDouble(newValue, forKey: "backgroundCloudOffsetY")
            notifyChange()
        }
    }

    /// Dust particle count
    var backgroundDustCount: Int {
        get {
            observeChanges()
            let value = getInt(forKey: "backgroundDustCount")
            return value == 0 && !hasBeenSet(forKey: "backgroundDustCountHasBeenSet") ? 800 : value
        }
        set {
            setInt(newValue, forKey: "backgroundDustCount")
            setBool(true, forKey: "backgroundDustCountHasBeenSet")
            notifyChange()
        }
    }

    /// Dust opacity
    var backgroundDustOpacity: Double {
        get {
            observeChanges()
            let value = getDouble(forKey: "backgroundDustOpacity")
            return value == 0 && !hasBeenSet(forKey: "backgroundDustOpacityHasBeenSet") ? 0.24 : value
        }
        set {
            setDouble(newValue, forKey: "backgroundDustOpacity")
            setBool(true, forKey: "backgroundDustOpacityHasBeenSet")
            notifyChange()
        }
    }

    /// Returns true if any of the card elements are using a textured theme
    var hasAnyTexturedTheme: Bool {
        return bitCardFrameColor.hasTexture ||
               bitCardBottomBarColor.hasTexture ||
               bitWindowTheme.hasTexture ||
               (bitCardFrameColor == .custom && bitCardFrameGritEnabled) ||
               (bitCardBottomBarColor == .custom && bitCardBottomBarGritEnabled) ||
               (bitWindowTheme == .custom && bitCardWindowGritEnabled)
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

    /// Returns the app's custom font color
    var fontColor: Color {
        return Color(hex: appFontColorHex) ?? .white
    }

    // MARK: - Accessibility Settings

    /// Reduce motion - disables animations across the app
    var reduceMotion: Bool {
        get {
            observeChanges()
            return getBool(forKey: "accessibilityReduceMotion")
        }
        set {
            setBool(newValue, forKey: "accessibilityReduceMotion")
            notifyChange()
        }
    }

    /// High contrast mode - increases text/element contrast
    var highContrast: Bool {
        get {
            observeChanges()
            return getBool(forKey: "accessibilityHighContrast")
        }
        set {
            setBool(newValue, forKey: "accessibilityHighContrast")
            notifyChange()
        }
    }

    /// Enable haptic feedback throughout the app
    var hapticsEnabled: Bool {
        get {
            observeChanges()
            guard hasBeenSet(forKey: "accessibilityHapticsEnabled") else {
                return true // Default: on
            }
            return getBool(forKey: "accessibilityHapticsEnabled")
        }
        set {
            setBool(newValue, forKey: "accessibilityHapticsEnabled")
            notifyChange()
        }
    }

    /// Bold text throughout the app
    var boldText: Bool {
        get {
            observeChanges()
            return getBool(forKey: "accessibilityBoldText")
        }
        set {
            setBool(newValue, forKey: "accessibilityBoldText")
            notifyChange()
        }
    }

    /// Larger touch targets for buttons
    var largerTouchTargets: Bool {
        get {
            observeChanges()
            return getBool(forKey: "accessibilityLargerTouchTargets")
        }
        set {
            setBool(newValue, forKey: "accessibilityLargerTouchTargets")
            notifyChange()
        }
    }

    private init() {
        // Initial sync from iCloud on launch
        cloudStore.synchronize()
        
        // Migrate any local-only settings to iCloud
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.migrateLocalSettingsToCloud()
        }
        
        // Observe iCloud KV Store changes to sync from other devices
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: cloudStore,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            
            // Get the reason for the change
            let reason = notification.userInfo?[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int
            
            // Log the change reason
            switch reason {
            case NSUbiquitousKeyValueStoreServerChange:
                print("📱 iCloud settings changed from another device")
            case NSUbiquitousKeyValueStoreInitialSyncChange:
                print("📱 iCloud initial sync completed")
            case NSUbiquitousKeyValueStoreQuotaViolationChange:
                print("⚠️ iCloud KV storage quota exceeded")
            case NSUbiquitousKeyValueStoreAccountChange:
                print("📱 iCloud account changed")
            default:
                print("📱 iCloud settings changed (unknown reason)")
            }
            
            // Extract changed keys from notification
            if let changedKeys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] {
                print("  Updated keys: \(changedKeys.joined(separator: ", "))")
                
                // Copy all changed values from cloud to local store for immediate access.
                // Already on main queue (observer registered with queue: .main).
                for key in changedKeys {
                    if let stringValue = self.cloudStore.string(forKey: key) {
                        self.localStore.set(stringValue, forKey: key)
                    } else if let doubleValue = self.cloudStore.object(forKey: key) as? Double {
                        self.localStore.set(doubleValue, forKey: key)
                    } else if let boolValue = self.cloudStore.object(forKey: key) as? Bool {
                        self.localStore.set(boolValue, forKey: key)
                    } else if let intValue = self.cloudStore.object(forKey: key) as? Int64 {
                        self.localStore.set(Int(intValue), forKey: key)
                    }
                }
                
                self.notifyChange()
            }
        }
    }
    
    /// Migrate any local-only settings to iCloud
    private func migrateLocalSettingsToCloud() {
        let allKeys = [
            "bitCardFrameColor", "bitCardBottomBarColor", "bitWindowTheme",
            "customFrameColorHex", "customBottomBarColorHex", "customWindowColorHex",
            "bitCardGritLevel", "bitCardFrameGritLevel", "bitCardBottomBarGritLevel", "bitCardWindowGritLevel",
            "bitCardWindowGritLayer1", "bitCardWindowGritLayer2", "bitCardWindowGritLayer3",
            "bitCardFrameGritLayer1Density", "bitCardFrameGritLayer2Density", "bitCardFrameGritLayer3Density",
            "bitCardBottomBarGritLayer1Density", "bitCardBottomBarGritLayer2Density", "bitCardBottomBarGritLayer3Density",
            "bitCardFrameGritEnabled", "bitCardBottomBarGritEnabled", "bitCardWindowGritEnabled",
            "bitCardFrameGritLayer1ColorHex", "bitCardFrameGritLayer2ColorHex", "bitCardFrameGritLayer3ColorHex",
            "bitCardBottomBarGritLayer1ColorHex", "bitCardBottomBarGritLayer2ColorHex", "bitCardBottomBarGritLayer3ColorHex",
            "bitCardWindowGritLayer1ColorHex", "bitCardWindowGritLayer2ColorHex", "bitCardWindowGritLayer3ColorHex",
            "appGritLevel", "appFont", "appFontColorHex", "appFontSizeMultiplier",
            "tileCardTheme", "quickBitTheme", "quickBitCustomColorHex",
            "quickBitGritEnabled", "quickBitGritLayer1ColorHex", "quickBitGritLayer2ColorHex", "quickBitGritLayer3ColorHex",
            "tileCardCustomColorHex", "tileCardGritEnabled",
            "tileCardGritLayer1ColorHex", "tileCardGritLayer2ColorHex", "tileCardGritLayer3ColorHex",
            "backgroundBaseColorHex", "backgroundCloudCount", "backgroundCloudOpacity",
            "backgroundCloudColor1Hex", "backgroundCloudColor2Hex", "backgroundCloudColor3Hex",
            "backgroundCloudOffsetX", "backgroundCloudOffsetY",
            "backgroundDustCount", "backgroundDustOpacity",
            "accessibilityReduceMotion", "accessibilityHighContrast", "accessibilityHapticsEnabled",
            "accessibilityBoldText", "accessibilityLargerTouchTargets"
        ]
        
        for key in allKeys {
            // If local has value but cloud doesn't, migrate to cloud
            if localStore.object(forKey: key) != nil && cloudStore.object(forKey: key) == nil {
                if let stringValue = localStore.string(forKey: key) {
                    cloudStore.set(stringValue, forKey: key)
                } else if let doubleValue = localStore.object(forKey: key) as? Double {
                    cloudStore.set(doubleValue, forKey: key)
                } else if let boolValue = localStore.object(forKey: key) as? Bool {
                    cloudStore.set(boolValue, forKey: key)
                } else if let intValue = localStore.object(forKey: key) as? Int {
                    cloudStore.set(Int64(intValue), forKey: key)
                }
            }
        }
        
        // Force sync after migration
        cloudStore.synchronize()
        print("✅ Migrated local settings to iCloud")
    }
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
    case chalkboard = "chalkboard"
    case yellowGrit = "yellowGrit"
    case custom = "custom"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chalkboard: return "Dark Grit"
        case .yellowGrit: return "Yellow Grit"
        case .custom: return "Custom Color"
        }
    }

    var description: String {
        switch self {
        case .chalkboard: return "Dark with subtle texture"
        case .yellowGrit: return "Warm yellow with grit"
        case .custom: return "Choose your own color"
        }
    }

    func color(customHex: String? = nil) -> Color {
        switch self {
        case .chalkboard: return Color("TFCard")
        case .yellowGrit: return Color("TFYellow")
        case .custom:
            if let hex = customHex {
                return Color(hex: hex) ?? Color("TFCard")
            }
            return Color("TFCard")
        }
    }

    /// Returns true if this theme should render with textured layers
    var hasTexture: Bool {
        switch self {
        case .chalkboard, .yellowGrit: return true
        case .custom: return false
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
    /// Initialize a Color from a hex string (supports #RRGGBB and #RRGGBBAA formats)
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0

        guard Scanner(string: hex).scanHexInt64(&int) else { return nil }

        let r, g, b, a: UInt64
        switch hex.count {
        case 6: // RGB (24-bit)
            (r, g, b, a) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF, 0xFF)
        case 8: // RGBA (32-bit)
            (r, g, b, a) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            return nil
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    /// Convert a Color to hex string.
    /// Returns 8-character #RRGGBBAA when the color has meaningful transparency,
    /// otherwise returns 6-character #RRGGBB.
    func toHex() -> String? {
        #if canImport(UIKit)
        let native = UIColor(self)
        #else
        let native = NSColor(self)
        #endif

        guard let components = native.cgColor.components,
              components.count >= 3 else {
            return nil
        }

        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        let a = components.count >= 4 ? Float(components[3]) : 1.0

        if a < 1.0 {
            return String(format: "#%02lX%02lX%02lX%02lX",
                         lroundf(r * 255),
                         lroundf(g * 255),
                         lroundf(b * 255),
                         lroundf(a * 255))
        } else {
            return String(format: "#%02lX%02lX%02lX",
                         lroundf(r * 255),
                         lroundf(g * 255),
                         lroundf(b * 255))
        }
    }
}
