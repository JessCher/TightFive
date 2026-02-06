import AppIntents

/// Provides app shortcuts for TightFive
/// These shortcuts allow users to perform actions via Siri
struct TightFiveAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: WriteQuickBitIntent(),
            phrases: [
                "Write a bit in \(.applicationName)",
                "Write a quick bit in \(.applicationName)",
                "Create a bit with \(.applicationName)",
                "Add a new bit to \(.applicationName)",
                "\(.applicationName) write a bit"
            ],
            shortTitle: "Write Bit",
            systemImageName: "mic.fill"
        )
        
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
    
    static var shortcutTileColor: ShortcutTileColor {
        .yellow
    }
}
