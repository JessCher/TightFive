import SwiftUI

struct MoreView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
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
                    
                    VStack(spacing: 12) {
                        NavigationLink {
                            ProfileView()
                        } label: {
                            settingsCard(icon: "person.circle.fill", title: "Profile", subtitle: "Your comedian profile")
                        }
                        
                        NavigationLink {
                            AnalyticsDashboardView()
                        } label: {
                            settingsCard(icon: "brain.head.profile", title: "Analytics", subtitle: "AI-powered insights")
                        }
                        
                        settingsCard(icon: "gear", title: "Settings", subtitle: "Coming soon")
                        settingsCard(icon: "externaldrive", title: "Storage", subtitle: Performance.formattedTotalStorage)
                        settingsCard(icon: "questionmark.circle", title: "Help", subtitle: "Probably not coming")
                    }
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
                .padding(.top, 14)
                .padding(.bottom, 28)
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
    
    private func settingsCard(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(TFTheme.yellow.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(TFTheme.yellow)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .tfDynamicCard(cornerRadius: 18)
    }
}

#Preview {
    MoreView()
}
