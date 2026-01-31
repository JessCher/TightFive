import SwiftUI

struct RootTabs: View {
    var body: some View {
        TabView {
            NavigationStack {
                HomeView()
            }
            .tabItem { Label("Home", systemImage: "house.fill") }

            NavigationStack {
                BitsTabView()
            }
            .tabItem { Label("Bits", systemImage: "square.stack.3d.up.fill") }

            NavigationStack {
                SetlistsView()
            }
            .tabItem { Label("Setlists", systemImage: "list.bullet") }
            
            NavigationStack {
                RunModeLauncherView()
            }
            .tabItem { Label("Run Through", systemImage: "timer") }
            
            NavigationStack {
                ShowNotesView()
            }
            .tabItem { Label("Show Notes", systemImage: "note.text") }
        }
        .tint(TFTheme.yellow)
    }
}

#Preview {
    RootTabs()
}

