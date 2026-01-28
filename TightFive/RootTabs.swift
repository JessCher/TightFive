import SwiftUI

struct RootTabs: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }

            LooseBitsView(mode: .all)
                .tabItem { Label("Bits", systemImage: "square.stack.3d.up.fill") }

            SetlistsView()
                .tabItem { Label("Setlists", systemImage: "list.bullet") }
            
            RunModeLauncherView()
                .tabItem { Label("Run Through", systemImage: "timer") }
            
            ShowNotesView()
                .tabItem { Label("Show Notes", systemImage: "note.text") }
        }
        .tint(TFTheme.yellow)
    }
}

#Preview {
    RootTabs()
}

