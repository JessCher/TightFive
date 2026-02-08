import SwiftUI

struct ContentView: View {
    @AppStorage("hasLaunchedBefore") private var hasLaunchedBefore = false
    @State private var showWelcome = false
    
    var body: some View {
        ZStack {
            RootTabs()
                .tfBackground()
                .withGlobalFont()
        }
        .onAppear {
            guard !hasLaunchedBefore else { return }
            hasLaunchedBefore = true
            showWelcome = true
        }
        .sheet(isPresented: $showWelcome) {
            FirstLaunchWelcomeView()
        }
    }
}
