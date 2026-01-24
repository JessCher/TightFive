import SwiftUI

struct RootTabs: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }

            LooseBitsView(mode: .all)
                .tabItem { Label("Bits", systemImage: "square.stack.3d.up.fill") }

            RunModeLauncherView()
                .tabItem { Label("Run Through", systemImage: "timer") }
            
            ShowNotesView()
                .tabItem { Label("Show Notes", systemImage: "note.text") }

            MorePlaceholderView()
                .tabItem { Label("More", systemImage: "ellipsis") }
        }
    }
}

private struct MorePlaceholderView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image("IconLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                    
                    TightFiveWordmark(size: 20)
                    
                    Text("Version 1.0")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.top, 20)
                
                VStack(spacing: 0) {
                    settingsRow(icon: "gear", title: "Settings", subtitle: "Coming soon")
                    
                    Divider().opacity(0.2)
                    
                    settingsRow(icon: "externaldrive", title: "Storage", subtitle: Performance.formattedTotalStorage)
                    
                    Divider().opacity(0.2)
                    
                    settingsRow(icon: "questionmark.circle", title: "Help", subtitle: "Probably not coming")
                }
                .background(Color("TFCard"))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color("TFCardStroke").opacity(0.6), lineWidth: 1)
                )
                .padding(.horizontal, 16)
                
                Spacer()
                
                VStack(spacing: 4) {
                    Text("Made for comedians with love")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
                    
                    Text("2026 Jesse Cherry")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.3))
                }
                .padding(.bottom, 20)
            }
            .navigationTitle("More")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    TFWordmarkTitle(title: "More", size: 22)
                }
            }
            .tfBackground()
        }
    }
    
    private func settingsRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(TFTheme.yellow)
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

#Preview {
    RootTabs()
}
