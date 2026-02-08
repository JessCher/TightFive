import SwiftUI

struct RootTabs: View {

    var body: some View {
        TabView {
            NavigationStack {
                HomeView()
            }
            .tabItem { Label("Home", systemImage: "house.fill") }

            NavigationStack {
                NotebookView()
            }
            .tabItem { Label("Notebook", systemImage: "book.fill") }
            
            NavigationStack {
                BitsTabView()
            }
            .tabItem { Label("Bits", systemImage: "square.stack.3d.up.fill") }

            NavigationStack {
                SetlistsView()
            }
            .tabItem { Label("Sets", systemImage: "microphone.fill") }

            NavigationStack {
                RunModeLauncherView()
            }
            .tabItem { Label("Run", systemImage: "timer") }
        }
        .tint(TFTheme.yellow)
    }
}

#Preview {
    RootTabs()
}

