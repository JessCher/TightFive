// WidgetIntegration.swift
// WidgetIntegration.swift
// TightFive
//
// Handles communication between the Quick Bit widget and the main app.
// Processes pending bits saved from the widget and syncs theme settings.
// Copyright © 2025 TightFive. All rights reserved.

import Foundation
import SwiftUI
import SwiftData
import WidgetKit
import Combine

// MARK: - Widget Integration Manager

/// Manages bidirectional communication between the main app and Quick Bit widget.
///
/// Responsibilities:
/// - Syncs theme settings to the widget's shared UserDefaults
/// - Processes pending Quick Bits saved from the widget
/// - Handles deep link navigation for Quick Bit capture
@MainActor
final class WidgetIntegrationManager: ObservableObject {
    
    /// Shared singleton instance
    static let shared = WidgetIntegrationManager()
    
    /// Published flag to trigger Quick Bit editor presentation
    @Published var shouldShowQuickBit = false
    
    /// Count of pending bits waiting to be processed
    @Published var pendingBitCount = 0
    
    /// Throttle widget reloads to once every 5 seconds minimum
    private var lastWidgetReloadTime: Date = .distantPast
    private let minimumReloadInterval: TimeInterval = 5.0
    
    private init() {}
    
    // MARK: - Widget Launch Flag Handling
    /// Checks if the widget requested launching the Quick Bit editor via shared defaults.
    /// If present, sets `shouldShowQuickBit` and clears the flag.
    func checkWidgetLaunchFlag() {
        guard let defaults = AppGroupConstants.sharedDefaults else { return }
        let key = AppGroupConstants.Keys.widgetRequestedQuickBitLaunch
        if defaults.bool(forKey: key) {
            // Clear the flag and request presentation
            defaults.set(false, forKey: key)
            shouldShowQuickBit = true
        }
    }
    
    // MARK: - Theme Synchronization
    
    /// Syncs current app theme settings to the widget's shared container.
    /// Call this whenever Quick Bit theme settings change.
    /// Throttled to prevent excessive reloads.
    func syncThemeToWidget() {
        #if DEBUG
        PerformanceMonitor.shared.trackFunction("Widget Theme Sync") {
            performSync()
        }
        #else
        performSync()
        #endif
    }
    
    private func performSync() {
        let settings = AppSettings.shared
        
        let config = WidgetThemeConfiguration(
            theme: mapTheme(settings.quickBitTheme),
            customColorHex: settings.quickBitCustomColorHex,
            gritEnabled: settings.quickBitGritEnabled,
            gritLayer1Hex: settings.quickBitGritLayer1ColorHex,
            gritLayer2Hex: settings.quickBitGritLayer2ColorHex,
            gritLayer3Hex: settings.quickBitGritLayer3ColorHex,
            gritLevel: settings.appGritLevel
        )
        
        config.saveToSharedDefaults()
        
        // Throttle widget reloads - only reload if enough time has passed
        let now = Date()
        if now.timeIntervalSince(lastWidgetReloadTime) >= minimumReloadInterval {
            WidgetCenter.shared.reloadAllTimelines()
            lastWidgetReloadTime = now
        }
        // If throttled, the widget will pick up changes on its next natural refresh
    }
    
    private func mapTheme(_ theme: TileCardTheme) -> WidgetThemeConfiguration.Theme {
        switch theme {
        case .darkGrit: return .darkGrit
        case .yellowGrit: return .yellowGrit
        case .custom: return .custom
        }
    }
    
    // MARK: - Pending Bit Processing
    
    /// Processes any Quick Bits that were saved from the widget.
    /// Call this on app launch and when returning from background.
    func processPendingBits(modelContext: ModelContext) {
        #if DEBUG
        PerformanceMonitor.shared.trackFunction("Process Pending Bits") {
            performProcessPendingBits(modelContext: modelContext)
        }
        #else
        performProcessPendingBits(modelContext: modelContext)
        #endif
    }
    
    private func performProcessPendingBits(modelContext: ModelContext) {
        guard let defaults = AppGroupConstants.sharedDefaults else { return }
        
        // Get pending bits
        guard let pendingBits = defaults.stringArray(forKey: "widget.pendingQuickBits"),
              !pendingBits.isEmpty else {
            pendingBitCount = 0
            return
        }
        
        // Create Bit objects for each pending text
        for text in pendingBits {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            
            let bit = Bit(text: trimmed, status: .loose)
            modelContext.insert(bit)
        }
        
        // Save and clear pending bits
        do {
            try modelContext.save()
            
            // Clear the pending bits from shared defaults
            defaults.removeObject(forKey: "widget.pendingQuickBits")
            defaults.removeObject(forKey: AppGroupConstants.Keys.pendingQuickBitTimestamp)
            
            pendingBitCount = 0
            
            // Reload widget to clear success state (throttled)
            let now = Date()
            if now.timeIntervalSince(lastWidgetReloadTime) >= minimumReloadInterval {
                WidgetCenter.shared.reloadAllTimelines()
                lastWidgetReloadTime = now
            }
        } catch {
            print("Failed to save pending bits: \(error)")
        }
    }
    
    /// Checks and returns the count of pending bits without processing them.
    func checkPendingBitCount() -> Int {
        guard let defaults = AppGroupConstants.sharedDefaults,
              let pendingBits = defaults.stringArray(forKey: "widget.pendingQuickBits") else {
            return 0
        }
        return pendingBits.count
    }
    
    // MARK: - Deep Link Handling
    
    /// Handles a deep link URL from the widget.
    /// - Parameter url: The URL to handle
    /// - Returns: True if the URL was handled
    @discardableResult
    func handleDeepLink(_ url: URL) -> Bool {
        guard url.scheme == "tightfive" else { return false }
        
        switch url.host {
        case "quickbit":
            // Trigger Quick Bit editor presentation
            shouldShowQuickBit = true
            return true
            
        default:
            return false
        }
    }
}

// MARK: - App Settings Extension

extension AppSettings {
    
    /// Syncs Quick Bit theme settings to the widget.
    /// Call this after any Quick Bit theme-related setting changes.
    func syncQuickBitThemeToWidget() {
        Task { @MainActor in
            WidgetIntegrationManager.shared.syncThemeToWidget()
        }
    }
}

// MARK: - View Extension for Deep Links

extension View {
    
    /// Adds widget deep link handling to the view hierarchy.
    func handleWidgetDeepLinks() -> some View {
        self
            .onOpenURL { url in
                WidgetIntegrationManager.shared.handleDeepLink(url)
            }
    }
}

// MARK: - Scene Phase Widget Sync

/// View modifier that processes pending bits and syncs theme on scene phase changes.
struct WidgetSyncModifier: ViewModifier {
    
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @StateObject private var widgetManager = WidgetIntegrationManager.shared
    @Binding var showQuickBit: Bool
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                // Check for widget launch flag on initial appear
                widgetManager.checkWidgetLaunchFlag()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    // Check for Control Center widget launch flag
                    widgetManager.checkWidgetLaunchFlag()
                    
                    // Process any pending bits from widget
                    widgetManager.processPendingBits(modelContext: modelContext)
                    
                    // Sync theme to widget
                    widgetManager.syncThemeToWidget()
                }
            }
            .onChange(of: widgetManager.shouldShowQuickBit) { _, shouldShow in
                if shouldShow {
                    showQuickBit = true
                    widgetManager.shouldShowQuickBit = false
                }
            }
            .onOpenURL { url in
                widgetManager.handleDeepLink(url)
            }
    }
}

extension View {
    /// Adds widget synchronization to the view.
    /// 
    /// Usage:
    /// ```swift
    /// ContentView()
    ///     .syncWithWidget(showQuickBit: $showQuickBit)
    ///     .sheet(isPresented: $showQuickBit) {
    ///         QuickBitEditor()
    ///     }
    /// ```
    func syncWithWidget(showQuickBit: Binding<Bool>) -> some View {
        modifier(WidgetSyncModifier(showQuickBit: showQuickBit))
    }
}

