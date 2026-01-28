import SwiftUI

struct HomeView: View {
    @State private var showQuickBit = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    quickBitButton

                    VStack(spacing: 14) {
                        NavigationLink {
                            LooseBitsView(mode: .loose)
                        } label: {
                            HomeTile(title: "Loose Ideas",
                                     subtitle: "Save joke ideas for later.",
                                     iconName: "IconLooseBits")
                        }

                        NavigationLink {
                            LooseBitsView(mode: .finished)
                        } label: {
                            HomeTile(title: "Finished Bits",
                                     subtitle: "Refine your best stuff.",
                                     iconName: "IconFinishedBits")
                        }

                        NavigationLink {
                            SetlistsView()
                        } label: {
                            HomeTile(title: "Setlists",
                                     subtitle: "Build and run tight sets.",
                                     iconName: "IconSetlists")
                        }

                        NavigationLink {
                            RunModeLauncherView()
                        } label: {
                            HomeTile(title: "Run Through",
                                     subtitle: "Practice makes perfect.",
                                     iconName: "IconRunMode")
                        }

                        NavigationLink {
                            ShowNotesView()
                        } label: {
                            HomeTile(title: "Show Notes",
                                     subtitle: "Reflect on how shows went.",
                                     iconName: "IconShowNotes")
                        }
                    }

                    Spacer(minLength: 26)
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Image("IconLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 50, height: 50)

                        TightFiveWordmark(size: 22)
                    }
                    .offset(x: -15)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        MorePlaceholderView()
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color("TFYellow"))
                            .frame(width: 40, height: 40)
                            .background(Color.white.opacity(0.0))
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .tfBackground()
            .sheet(isPresented: $showQuickBit) {
                QuickBitEditor()
                    .presentationDetents([.medium, .large])
            }
        }
    }

    private var quickBitButton: some View {
        Button {
            showQuickBit = true
        } label: {
            ZStack {
                // Base yellow background
                Color("TFYellow")
                
                // Dynamic dust layers with BLACK particles for yellow background
                DynamicGritLayer(
                    density: 80,
                    opacity: 0.55,
                    speedMultiplier: 0.5,
                    seed: 7777,
                    particleColor: .black
                )
                
                DynamicGritLayer(
                    density: 50,
                    opacity: 0.88,
                    speedMultiplier: 1.0,
                    seed: 8888,
                    particleColor: .black
                )
                
                // Button text on top
                Text("Quick Bit")
                    .font(.title.weight(.bold))
                    .foregroundStyle(.black)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100) // Explicit height for hero button
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color("TFCardStroke"), lineWidth: 1.5)
                    .opacity(0.9)
                    .blendMode(.overlay)
            )
            .shadow(color: .black.opacity(0.8), radius: 10, x: 0, y: 8)
            .shadow(color: Color("TFYellow").opacity(0.15), radius: 12, x: 0, y: 0)
        }
    }
}

// MARK: - Tile

private struct HomeTile: View {
    let title: String
    let subtitle: String
    let iconName: String
    
    var body: some View {
        HStack(spacing: 14) {
            Image(iconName)
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.62))
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.tfYellow.opacity(0.34))
        }
        .padding(.vertical, 29)
        .padding(.horizontal, 16)
        .tfDynamicCard(cornerRadius: 20) // New dynamic generator
    }
}

