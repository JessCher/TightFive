// QuickBitControlWidget.swift
// QuickBitWidget Extension
//
// Control Center widget for iOS 18+ providing truly frictionless Quick Bit capture.
// This appears in Control Center and Lock Screen controls.
// Copyright © 2025 TightFive. All rights reserved.

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Control Widget (iOS 18+)

/// Control Center widget for Quick Bit capture.
/// Provides single-tap access from Control Center and Lock Screen.
@available(iOS 18.0, *)
struct QuickBitControlWidget: ControlWidget {
    
    static let kind: String = "com.tightfive.QuickBitControl"
    
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: OpenQuickBitIntent()) {
                Label("Quick Bit", systemImage: "lightbulb.fill")
            }
        }
        .displayName("Quick Bit")
        .description("Capture a comedy idea instantly")
    }
}

// MARK: - Open Quick Bit Intent

/// Intent that opens the app directly to Quick Bit editor.
@available(iOS 16.0, *)
struct OpenQuickBitIntent: AppIntent {
    
    static var title: LocalizedStringResource = "Open Quick Bit"
    static var description = IntentDescription("Opens TightFive to capture a Quick Bit")
    
    /// This intent should open the app
    static var openAppWhenRun: Bool = true
    
    @MainActor
    func perform() async throws -> some IntentResult {
        // The app will handle showing the Quick Bit editor via deep link
        // Set a flag in shared defaults that the app will check
        AppGroupConstants.sharedDefaults?.set(true, forKey: "widget.shouldOpenQuickBit")
        
        return .result()
    }
}

// MARK: - Lock Screen Widget

/// Lock Screen accessory widget for Quick Bit.
/// Provides a compact circular button on the Lock Screen.
struct QuickBitLockScreenWidget: Widget {
    
    let kind = "QuickBitLockScreenWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LockScreenProvider()) { entry in
            LockScreenWidgetView(entry: entry)
                .widgetURL(URL(string: "tightfive://quickbit"))
        }
        .configurationDisplayName("Quick Bit")
        .description("Capture ideas from your Lock Screen")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - Lock Screen Provider

struct LockScreenEntry: TimelineEntry {
    let date: Date
}

struct LockScreenProvider: TimelineProvider {
    
    func placeholder(in context: Context) -> LockScreenEntry {
        LockScreenEntry(date: Date())
    }
    
    func getSnapshot(in context: Context, completion: @escaping (LockScreenEntry) -> Void) {
        completion(LockScreenEntry(date: Date()))
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<LockScreenEntry>) -> Void) {
        let entry = LockScreenEntry(date: Date())
        // Lock Screen widgets don't need frequent updates
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
}

// MARK: - Lock Screen Widget View

struct LockScreenWidgetView: View {
    
    let entry: LockScreenEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .accessoryCircular:
            circularView
        case .accessoryRectangular:
            rectangularView
        case .accessoryInline:
            inlineView
        default:
            circularView
        }
    }
    
    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.primary)
        }
        .containerBackground(for: .widget) {
            Color.clear
        }
    }
    
    private var rectangularView: some View {
        HStack(spacing: 8) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 18, weight: .semibold))
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Quick Bit")
                    .font(.system(size: 14, weight: .semibold))
                Text("Capture an idea")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .containerBackground(for: .widget) {
            Color.clear
        }
    }
    
    private var inlineView: some View {
        Label("Quick Bit", systemImage: "lightbulb.fill")
            .containerBackground(for: .widget) {
                Color.clear
            }
    }
}

// MARK: - Previews

#Preview("Circular", as: .accessoryCircular) {
    QuickBitLockScreenWidget()
} timeline: {
    LockScreenEntry(date: .now)
}

#Preview("Rectangular", as: .accessoryRectangular) {
    QuickBitLockScreenWidget()
} timeline: {
    LockScreenEntry(date: .now)
}

#Preview("Inline", as: .accessoryInline) {
    QuickBitLockScreenWidget()
} timeline: {
    LockScreenEntry(date: .now)
}
