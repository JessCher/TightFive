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
                .tint(TFTheme.yellow)        // accent color across SwiftUI
        }
        .modelContainer(for: [Bit.self, Setlist.self])
    }
}
