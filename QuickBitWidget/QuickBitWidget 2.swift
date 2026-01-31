// QuickBitWidget.swift
// QuickBitWidget Extension
//
// Home Screen widget for frictionless Quick Bit capture.
// Matches the in-app Quick Bit button styling with user customizations.
//
// **How it works:**
// When tapped, the widget opens the app directly to the Quick Bit editor
// using a deep link. This is the most frictionless approach possible within
// iOS platform constraints - widgets cannot display text input fields directly.
//
// For iOS 26, we use:
// - Deep link URL scheme to open Quick Bit editor instantly
// - Shared App Group for theme synchronization
// - Interactive widget with Button intent for future enhancements
//
// Copyright © 2025 TightFive. All rights reserved.

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Widget Entry

/// Timeline entry for the Quick Bit widget.
struct QuickBitEntry: TimelineEntry {
    let date: Date
    let configuration: WidgetThemeConfiguration
    let showLabel: Bool
    let recentlySaved: Bool  // Shows brief success state
    
    static var placeholder: QuickBitEntry {
        QuickBitEntry(
            date: Date(),
            configuration: .default,
            showLabel: true,
            recentlySaved: false
        )
    }
}

// MARK: - Timeline Provider

/// Provides timeline entries for the Quick Bit widget.
struct QuickBitProvider: AppIntentTimelineProvider {
    
    typealias Entry = QuickBitEntry
    typealias Intent = QuickBitWidgetConfigurationIntent
    
    func placeholder(in context: Context) -> QuickBitEntry {
        .placeholder
    }
    
    func snapshot(for configuration: QuickBitWidgetConfigurationIntent, in context: Context) async -> QuickBitEntry {
        QuickBitEntry(
            date: Date(),
            configuration: WidgetThemeConfiguration.loadFromSharedDefaults(),
            showLabel: configuration.showLabel,
            recentlySaved: false
        )
    }
    
    func timeline(for configuration: QuickBitWidgetConfigurationIntent, in context: Context) async -> Timeline<QuickBitEntry> {
        let config = WidgetThemeConfiguration.loadFromSharedDefaults()
        
        // Check if a bit was recently saved (within last 3 seconds)
        let recentlySaved = checkRecentSave()
        
        let entry = QuickBitEntry(
            date: Date(),
            configuration: config,
            showLabel: configuration.showLabel,
            recentlySaved: recentlySaved
        )
        
        // If recently saved, refresh quickly to clear the success state
        let nextUpdate: Date
        if recentlySaved {
            nextUpdate = Date().addingTimeInterval(3) // Refresh in 3 seconds
        } else {
            // Normal refresh every hour to pick up theme changes
            nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        }
        
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
    
    private func checkRecentSave() -> Bool {
        guard let defaults = AppGroupConstants.sharedDefaults else { return false }
        let timestamp = defaults.double(forKey: AppGroupConstants.Keys.pendingQuickBitTimestamp)
        guard timestamp > 0 else { return false }
        
        let saveDate = Date(timeIntervalSince1970: timestamp)
        return Date().timeIntervalSince(saveDate) < 3
    }
}

// MARK: - Widget View

/// The visual appearance of the Quick Bit widget button.
struct QuickBitWidgetView: View {
    
    let entry: QuickBitEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background with grit texture
                buttonBackground(size: geometry.size)
                
                // Button content (shows checkmark briefly after save)
                if entry.recentlySaved {
                    successContent
                } else {
                    buttonContent
                }
            }
        }
        .containerBackground(for: .widget) {
            Color.clear
        }
    }
    
    // MARK: - Background
    
    @ViewBuilder
    private func buttonBackground(size: CGSize) -> some View {
        let config = entry.configuration
        
        ZStack {
            // Base color
            baseColor
            
            // Grit layers (simplified for widget performance)
            if config.gritEnabled && config.gritLevel > 0 {
                WidgetGritLayer(
                    density: Int(300 * config.gritLevel),
                    opacity: 0.7,
                    seed: 1234,
                    color: Color(hex: config.gritLayer1Hex) ?? .brown,
                    size: size
                )
                
                WidgetGritLayer(
                    density: Int(200 * config.gritLevel),
                    opacity: 0.5,
                    seed: 5678,
                    color: Color(hex: config.gritLayer2Hex) ?? .black,
                    size: size
                )
                
                WidgetGritLayer(
                    density: Int(150 * config.gritLevel),
                    opacity: 0.4,
                    seed: 9012,
                    color: Color(hex: config.gritLayer3Hex) ?? Color(red: 0.8, green: 0.4, blue: 0.0),
                    size: size
                )
            }
            
            // Vignette overlay
            RadialGradient(
                colors: [.clear, .black.opacity(0.15)],
                center: .center,
                startRadius: 0,
                endRadius: max(size.width, size.height) * 0.7
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(strokeColor, lineWidth: 1)
        )
    }
    
    private var baseColor: Color {
        switch entry.configuration.theme {
        case .yellowGrit:
            return Color(hex: "#F4C430") ?? .yellow
        case .darkGrit:
            return Color(hex: "#2D2D2D") ?? .gray
        case .custom:
            return Color(hex: entry.configuration.customColorHex) ?? .yellow
        }
    }
    
    private var strokeColor: Color {
        switch entry.configuration.theme {
        case .darkGrit:
            return Color.white.opacity(0.15)
        default:
            return Color.black.opacity(0.1)
        }
    }
    
    private var cornerRadius: CGFloat {
        switch family {
        case .systemSmall:
            return 20
        case .systemMedium:
            return 22
        default:
            return 20
        }
    }
    
    // MARK: - Content
    
    @ViewBuilder
    private var buttonContent: some View {
        VStack(spacing: 4) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(textColor)
            
            if entry.showLabel && family != .accessoryCircular {
                Text("Quick Bit")
                    .font(.system(size: labelSize, weight: .bold, design: .rounded))
                    .foregroundStyle(textColor)
            }
        }
    }
    
    @ViewBuilder
    private var successContent: some View {
        VStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(textColor)
            
            if entry.showLabel && family != .accessoryCircular {
                Text("Saved!")
                    .font(.system(size: labelSize, weight: .bold, design: .rounded))
                    .foregroundStyle(textColor)
            }
        }
    }
    
    private var textColor: Color {
        switch entry.configuration.theme {
        case .yellowGrit, .custom:
            // Calculate luminance for custom colors
            if entry.configuration.theme == .custom {
                return luminanceBasedTextColor(for: entry.configuration.customColorHex)
            }
            return .black.opacity(0.85)
        case .darkGrit:
            return .white
        }
    }
    
    private func luminanceBasedTextColor(for hex: String) -> Color {
        guard let color = Color(hex: hex),
              let components = UIColor(color).cgColor.components,
              components.count >= 3 else {
            return .black.opacity(0.85)
        }
        
        let r = components[0]
        let g = components[1]
        let b = components[2]
        let luminance = 0.299 * r + 0.587 * g + 0.114 * b
        
        return luminance > 0.5 ? .black.opacity(0.85) : .white
    }
    
    private var iconSize: CGFloat {
        switch family {
        case .systemSmall:
            return entry.showLabel ? 24 : 32
        case .systemMedium:
            return 28
        case .accessoryCircular:
            return 20
        default:
            return 24
        }
    }
    
    private var labelSize: CGFloat {
        switch family {
        case .systemSmall:
            return 13
        case .systemMedium:
            return 15
        default:
            return 13
        }
    }
}

// MARK: - Widget Grit Layer

/// Simplified grit texture layer optimized for widget rendering.
/// Uses a deterministic pattern based on seed for consistent appearance.
struct WidgetGritLayer: View {
    let density: Int
    let opacity: Double
    let seed: Int
    let color: Color
    let size: CGSize
    
    var body: some View {
        Canvas { context, canvasSize in
            var rng = SeededRandomNumberGenerator(seed: UInt64(seed))
            
            let particleCount = min(density, 500) // Cap for performance
            
            for _ in 0..<particleCount {
                let x = CGFloat.random(in: 0..<canvasSize.width, using: &rng)
                let y = CGFloat.random(in: 0..<canvasSize.height, using: &rng)
                let particleSize = CGFloat.random(in: 0.5...2.0, using: &rng)
                
                let rect = CGRect(x: x, y: y, width: particleSize, height: particleSize)
                context.fill(Path(ellipseIn: rect), with: .color(color))
            }
        }
        .opacity(opacity)
    }
}

/// Deterministic random number generator for consistent grit patterns.
struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64
    
    init(seed: UInt64) {
        self.state = seed
    }
    
    mutating func next() -> UInt64 {
        // Xorshift64 algorithm
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

// MARK: - Widget Definition

struct QuickBitWidget: Widget {
    
    let kind: String = "QuickBitWidget"
    
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: QuickBitWidgetConfigurationIntent.self,
            provider: QuickBitProvider()
        ) { entry in
            QuickBitWidgetView(entry: entry)
                .widgetURL(URL(string: "tightfive://quickbit"))
        }
        .configurationDisplayName("Quick Bit")
        .description("Capture comedy ideas instantly")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

// MARK: - Color Extension

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
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    QuickBitWidget()
} timeline: {
    QuickBitEntry(date: .now, configuration: .default, showLabel: true, recentlySaved: false)
}

#Preview("Medium", as: .systemMedium) {
    QuickBitWidget()
} timeline: {
    QuickBitEntry(date: .now, configuration: .default, showLabel: true, recentlySaved: false)
}

#Preview("Dark Theme", as: .systemSmall) {
    QuickBitWidget()
} timeline: {
    QuickBitEntry(
        date: .now,
        configuration: WidgetThemeConfiguration(
            theme: .darkGrit,
            customColorHex: "#2D2D2D",
            gritEnabled: true,
            gritLayer1Hex: "#F4C430",
            gritLayer2Hex: "#FFFFFF",
            gritLayer3Hex: "#FFFFFF",
            gritLevel: 1.0
        ),
        showLabel: true,
        recentlySaved: false
    )
}
