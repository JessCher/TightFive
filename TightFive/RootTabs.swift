import SwiftUI

struct RootTabs: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }

            LooseBitsView(mode: .all)
                .tabItem { Label("Bits", systemImage: "square.stack.3d.up.fill") }

            RunModeLauncherView()
                .tabItem { Label("Run Mode", systemImage: "timer") }

            MorePlaceholderView()
                .tabItem { Label("More", systemImage: "ellipsis") }
        }
    }
}

private struct MorePlaceholderView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView("More", systemImage: "ellipsis", description: Text("Coming soon."))
                .navigationTitle("More")
        }
        .tfBackground()
    }
}
