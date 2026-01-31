// QuickBitWidgetBundle.swift
// QuickBitWidget Extension
//
// Widget bundle for TightFive widgets.
// Includes Home Screen, Lock Screen, and Control Center widgets.
// Copyright © 2025 TightFive. All rights reserved.

import WidgetKit
import SwiftUI

/// Bundle containing all TightFive widgets.
///
/// Available widgets:
/// - **QuickBitWidget**: Home Screen widget (Small, Medium sizes)
/// - **QuickBitLockScreenWidget**: Lock Screen widget (Circular, Rectangular, Inline)
/// - **QuickBitControlWidget**: Control Center widget (iOS 18+)
///
/// To add the widgets:
/// 1. Long press Home Screen → Edit → Add Widget → TightFive
/// 2. Settings → Control Center → Add Quick Bit
/// 3. Long press Lock Screen → Customize → Add Quick Bit
@main
struct QuickBitWidgetBundle: WidgetBundle {
    
    var body: some Widget {
        // Home Screen widget
        QuickBitWidget()
        
        // Lock Screen widget
        QuickBitLockScreenWidget()
        
        // Control Center widget (iOS 18+)
        if #available(iOS 18.0, *) {
            QuickBitControlWidget()
        }
    }
}

