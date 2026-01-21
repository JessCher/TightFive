import SwiftUI

struct RootTabs: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }

            LooseBitsView(mode: .all)
                .tabItem { Label("Bits", systemImage: "square.stack.3d.up.fill") }

            RunModePlaceholderView()
                .tabItem { Label("Run Mode", systemImage: "timer") }

            MorePlaceholderView()
                .tabItem { Label("More", systemImage: "ellipsis") }
        }
    }
}

private struct RunModePlaceholderView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView("Run Mode", systemImage: "timer", description: Text("Coming soon."))
                .navigationTitle("Run Mode")
        }
    }
}

private struct MorePlaceholderView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView("More", systemImage: "ellipsis", description: Text("Coming soon."))
                .navigationTitle("More")
        }
    }
}
