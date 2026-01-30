import SwiftUI
import Combine

struct HomeView: View {
    @State private var showQuickBit = false
    @Environment(AppSettings.self) private var appSettings

    var body: some View {
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
                    // MARK: - HIDDEN: IconLogo
                    // Image("IconLogo")
                    //     .resizable()
                    //     .scaledToFit()
                    //     .frame(width: 50, height: 50)

                    TightFiveWordmark(size: 22)
                }
                .offset(x: -15)
            }

            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    MoreView()
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

    private var quickBitButton: some View {
        let _ = appSettings.updateTrigger // Force observation
        let theme = appSettings.quickBitTheme
        let gritLevel = appSettings.appGritLevel
        let customColor = Color(hex: appSettings.quickBitCustomColorHex) ?? theme.baseColor
        let gritEnabled = appSettings.quickBitGritEnabled
        let gritLayer1 = Color(hex: appSettings.quickBitGritLayer1ColorHex) ?? .brown
        let gritLayer2 = Color(hex: appSettings.quickBitGritLayer2ColorHex) ?? .black
        let gritLayer3 = Color(hex: appSettings.quickBitGritLayer3ColorHex) ?? Color(red: 0.8, green: 0.4, blue: 0.0)
        
        // Determine text color based on theme or custom color
        let textColor: Color = {
            if theme == .custom {
                // Calculate luminance for custom color
                if let components = UIColor(customColor).cgColor.components, components.count >= 3 {
                    let r = components[0]
                    let g = components[1]
                    let b = components[2]
                    let luminance = 0.299 * r + 0.587 * g + 0.114 * b
                    return luminance > 0.5 ? .black.opacity(0.85) : .white
                }
                return .white
            }
            return theme == .darkGrit ? .white : .black.opacity(0.85)
        }()
        
        return Button {
            showQuickBit = true
        } label: {
            ZStack {
                // Use custom color if custom theme, otherwise use theme base color
                if theme == .custom {
                    customColor
                    
                    // Apply custom grit layers if enabled
                    if gritEnabled && gritLevel > 0 {
                        StaticGritLayer(
                            density: appSettings.adjustedAppGritDensity(800),
                            opacity: 0.85,
                            seed: 9001,
                            particleColor: gritLayer1
                        )
                        
                        StaticGritLayer(
                            density: appSettings.adjustedAppGritDensity(100),
                            opacity: 0.88,
                            seed: 9002,
                            particleColor: gritLayer2
                        )
                        
                        StaticGritLayer(
                            density: appSettings.adjustedAppGritDensity(400),
                            opacity: 0.88,
                            seed: 9003,
                            particleColor: gritLayer3
                        )
                    }
                } else {
                    // Base color from theme
                    theme.baseColor
                    
                    // Apply grit layers based on grit enabled setting and grit level
                    if gritLevel > 0 {
                        if theme == .darkGrit {
                            // Dark Grit theme layers
                            StaticGritLayer(
                                density: appSettings.adjustedAppGritDensity(300),
                                opacity: 0.55,
                                seed: 1234,
                                particleColor: Color("TFYellow")
                            )
                            
                            StaticGritLayer(
                                density: appSettings.adjustedAppGritDensity(300),
                                opacity: 0.35,
                                seed: 5678
                            )
                        } else if theme == .yellowGrit {
                            // Yellow Grit theme layers
                            StaticGritLayer(
                                density: appSettings.adjustedAppGritDensity(800),
                                opacity: 0.85,
                                seed: 7777,
                                particleColor: .brown
                            )
                            
                            StaticGritLayer(
                                density: appSettings.adjustedAppGritDensity(100),
                                opacity: 0.88,
                                seed: 8888,
                                particleColor: .black
                            )
                            
                            StaticGritLayer(
                                density: appSettings.adjustedAppGritDensity(400),
                                opacity: 0.88,
                                seed: 8888,
                                particleColor: Color(red: 0.8, green: 0.4, blue: 0.0)
                            )
                        }
                    }
                }
                
                // Button text on top (adjust color based on background brightness)
                Text("Quick Bit")
                    .font(appSettings.appFont.font(size: 28).weight(.bold))
                    .foregroundStyle(textColor)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 125) // Explicit height for hero button
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color("TFCardStroke"), lineWidth: 1.5)
                    .opacity(0.9)
                    .blendMode(.overlay)
            )
            .shadow(color: .black.opacity(0.8), radius: 10, x: 0, y: 8)
            .shadow(color: customColor.opacity(0.15), radius: 12, x: 0, y: 0)
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
            // MARK: - HIDDEN: Custom Icons
            // Hiding: IconLooseBits, IconFinishedBits, IconSetlists, IconRunMode, IconShowNotes
            // Image(iconName)
            //     .renderingMode(.original)
            //     .resizable()
            //     .scaledToFit()
            //     .frame(width: 40, height: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .appFont(.headline, weight: .semibold)
                    .foregroundStyle(.white)
                
                Text(subtitle)
                    .appFont(.subheadline)
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

