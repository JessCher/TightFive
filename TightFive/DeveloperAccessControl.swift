import Foundation
import UIKit

enum DeveloperAccessControl {
    // Populate with your personal device IDFV(s) for strict ownership checks.
    private static let allowlistedIDFV: Set<String> = ["8DE6D2D0-E615-444F-AE11-453DD980A981", "00008103-000124D42629A01E"]

    // Fallback for local debug builds while IDFV list is being configured.
    private static let ownerNameTokens: [String] = ["jesse"]

    private static let localOwnerTokenKey = "tightfive.devtools.ownerToken"
    private static let localOwnerTokenValue = "tightfive-owner-jesse"
    

    static var canAccessDevTools: Bool {
        #if DEBUG
        return isOwnerDevice
        #else
        return false
        #endif
    }

    static func enforceRuntimePolicy() {
        guard canAccessDevTools else {
            UserDefaults.standard.set(false, forKey: "performanceOverlayEnabled")
            return
        }
    }

    private static var isOwnerDevice: Bool {
        if let idfv = UIDevice.current.identifierForVendor?.uuidString.uppercased(),
           allowlistedIDFV.contains(idfv) {
            return true
        }

        if let ownerToken = UserDefaults.standard.string(forKey: localOwnerTokenKey),
           ownerToken == localOwnerTokenValue {
            return true
        }

        let normalizedName = UIDevice.current.name.lowercased()
        return ownerNameTokens.contains(where: { normalizedName.contains($0.lowercased()) })
    }
}
