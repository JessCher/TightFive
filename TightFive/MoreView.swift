import SwiftUI

struct MoreView: View {
    var body: some View {
        ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                     TightFiveWordmark(size: 20)
                    }
                    .padding(.top, 20)
                    
                    VStack(spacing: 12) {
                        NavigationLink {
                            ProfileView()
                        } label: {
                            settingsCard(icon: "person.circle.fill", title: "Profile", subtitle: "Your comedian profile")
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

                        NavigationLink {
                            AboutView()
                        } label: {
                            settingsCard(icon: "info.circle", title: "About", subtitle: "Version, privacy, and feature help")
                        }

                        NavigationLink {
                            StorageInfoView()
                        } label: {
                            settingsCard(icon: "externaldrive", title: "Recording Storage", subtitle: Performance.formattedTotalStorage)
                        }
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                }
            }
            .tfBackground()
    }
    
    private func settingsCard(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
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
