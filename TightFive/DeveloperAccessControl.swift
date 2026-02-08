import Foundation
import UIKit

enum DeveloperAccessControl {

    static var canAccessDevTools: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    static func enforceRuntimePolicy() {
        #if !DEBUG
        UserDefaults.standard.set(false, forKey: "performanceOverlayEnabled")
        #endif
    }
}
