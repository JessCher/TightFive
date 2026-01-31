import SwiftUI

struct MoreView: View {
    var body: some View {
        ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        // MARK: - HIDDEN: IconLogo
                        // Image("IconLogo")
                        //     .resizable()
                        //     .scaledToFit()
                        //     .frame(width: 80, height: 80)
                        
                        TightFiveWordmark(size: 20)
                        
                        Text("Version 1.0")
                            .appFont(.caption)
                            .foregroundStyle(TFTheme.text.opacity(0.5))
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
                        
                        NavigationLink {
                            TrashcanView()
                        } label: {
                            settingsCard(icon: "trash", title: "Trashcan", subtitle: "Recover deleted items")
                        }
                        
                        NavigationLink {
                            SettingsView()
                        } label: {
                            settingsCard(icon: "gear", title: "Settings", subtitle: "Customize your experience")
                        }
                        settingsCard(icon: "externaldrive", title: "Storage", subtitle: Performance.formattedTotalStorage)
                        settingsCard(icon: "questionmark.circle", title: "Help", subtitle: "Probably not coming")
                    }
                    .padding(.horizontal, 16)
                    
                    Spacer()
                    
                    VStack(spacing: 4) {
                        Text("Made for comedians with love")
                            .appFont(.caption)
                            .foregroundStyle(TFTheme.text.opacity(0.4))
                        
                        Text("2026 Jesse Cherry")
                            .appFont(.caption2)
                            .foregroundStyle(TFTheme.text.opacity(0.3))
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
    
    private func settingsCard(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            // MARK: - HIDDEN: Icons removed to match other tiles
            // ZStack {
            //     Circle()
            //         .fill(TFTheme.yellow.opacity(0.15))
            //         .frame(width: 44, height: 44)
            //     
            //     Image(systemName: icon)
            //         .font(.system(size: 18, weight: .semibold))
            //         .foregroundStyle(TFTheme.yellow)
            // }
            
            Spacer()
            
            VStack(alignment: .center, spacing: 4) {
                Text(title)
                    .appFont(.headline)
                    .foregroundStyle(TFTheme.text)
                
                Text(subtitle)
                    .appFont(.subheadline)
                    .foregroundStyle(TFTheme.text.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .tfDynamicCard(cornerRadius: 18)
    }
}

#Preview {
    MoreView()
}
