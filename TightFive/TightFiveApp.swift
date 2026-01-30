import SwiftUI
import SwiftData

@main
struct TightFiveApp: App {
    init() {
        TFTheme.applySystemAppearance()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(TFTheme.yellow)
                .environment(AppSettings.shared)
        }
        .modelContainer(for: [
            Bit.self,
            Setlist.self,
            BitVariation.self,
            SetlistAssignment.self,
            Performance.self,
            UserProfile.self
        ])
    }
}
