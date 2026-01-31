// QuickBitIntent.swift
// TightFive (Shared)
//
// App Intent for capturing Quick Bits from the Home Screen widget.
// Uses iOS 17+ interactive widget capabilities with App Intents.
// Copyright © 2025 TightFive. All rights reserved.

import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Widget Configuration Intent

/// Intent for configuring the Quick Bit widget appearance.
/// This is used by the widget's AppIntentConfiguration.
struct QuickBitWidgetConfigurationIntent: WidgetConfigurationIntent {
    
    static var title: LocalizedStringResource = "Quick Bit Widget"
    static var description = IntentDescription("Configure your Quick Bit capture button")
    
    /// Whether to show the "Quick Bit" label below the icon
    @Parameter(title: "Show Label", default: true)
    var showLabel: Bool
}

// MARK: - App Shortcuts Provider

/// Provides Siri shortcuts for Quick Bit capture.
/// Allows users to say "Hey Siri, Quick Bit" to open the editor.
struct QuickBitShortcuts: AppShortcutsProvider {
    
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenQuickBitEditorIntent(),
            phrases: [
                "Quick bit in \(.applicationName)",
                "New comedy idea in \(.applicationName)",
                "Capture a quick bit with \(.applicationName)"
            ],
            shortTitle: "Quick Bit",
            systemImageName: "lightbulb.fill"
        )
    }
}

// MARK: - Open Quick Bit Editor Intent

/// Intent that opens the app directly to the Quick Bit editor.
/// Used by Control Center widget and Siri shortcuts.
struct OpenQuickBitEditorIntent: AppIntent {
    
    static var title: LocalizedStringResource = "Open Quick Bit"
    static var description = IntentDescription("Opens TightFive to capture a Quick Bit")
    
    /// This intent opens the app to the Quick Bit editor
    static var openAppWhenRun: Bool = true
    
    @MainActor
    func perform() async throws -> some IntentResult {
        // Set flag for app to show Quick Bit editor on launch
        AppGroupConstants.sharedDefaults?.set(true, forKey: "widget.shouldOpenQuickBit")
        return .result()
    }
}

