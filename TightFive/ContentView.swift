import SwiftUI

struct ContentView: View {
    @Environment(AppSettings.self) private var appSettings
    
    var body: some View {
        RootTabs()
            .tfBackground()
            .withGlobalFont()
    }
}
