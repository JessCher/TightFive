import Foundation
import UIKit

enum DeveloperAccessControl {
    
    // Your personal device identifier(s)
    // To find your device identifier: Settings > General > About > scroll to "Identifier"
    // Or use: UIDevice.current.identifierForVendor?.uuidString
    private static let authorizedDeviceIdentifiers: Set<String> = [
        "YOUR-DEVICE-IDENTIFIER-HERE" // TODO: Replace with your actual device identifier
        // You can add multiple devices if needed:
        // "ANOTHER-DEVICE-IDENTIFIER",
        // "IPAD-DEVICE-IDENTIFIER"
    ]
    
    static var canAccessDevTools: Bool {
        #if DEBUG
        // In debug builds, only show dev tools on authorized devices
        return isAuthorizedDevice()
        #else
        // In production/release builds, never show dev tools
        return false
        #endif
    }
    
    private static func isAuthorizedDevice() -> Bool {
        // Get the device's vendor identifier
        guard let deviceID = UIDevice.current.identifierForVendor?.uuidString else {
            return false
        }
        
        // Check if this device is in the authorized list
        return authorizedDeviceIdentifiers.contains(deviceID)
    }
    
    /// Returns the current device identifier for setup purposes
    static func getCurrentDeviceIdentifier() -> String {
        return UIDevice.current.identifierForVendor?.uuidString ?? "Unknown"
    }
    
    static func enforceRuntimePolicy() {
        // If not authorized, disable all developer features
        if !canAccessDevTools {
            UserDefaults.standard.set(false, forKey: "performanceOverlayEnabled")
        }
    }
}
