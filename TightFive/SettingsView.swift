import SwiftUI

struct SettingsView: View {
    @State private var selectedFrameColor: BitCardFrameColor = AppSettings.shared.bitCardFrameColor
    @State private var selectedBottomBarColor: BitCardFrameColor = AppSettings.shared.bitCardBottomBarColor
    @State private var selectedWindowTheme: BitWindowTheme = AppSettings.shared.bitWindowTheme
    
    var body: some View {
        Form {
            Section {
                Picker("Background Frame", selection: $selectedFrameColor) {
                    ForEach(BitCardFrameColor.allCases) { color in
                        HStack {
                            Circle()
                                .fill(color.color)
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Circle()
                                        .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                                )
                            
                            Text(color.displayName)
                        }
                        .tag(color)
                    }
                }
                .pickerStyle(.navigationLink)
                .onChange(of: selectedFrameColor) { _, newValue in
                    AppSettings.shared.bitCardFrameColor = newValue
                }
                
                Picker("Bottom Bar", selection: $selectedBottomBarColor) {
                    ForEach(BitCardFrameColor.allCases) { color in
                        HStack {
                            Circle()
                                .fill(color.color)
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Circle()
                                        .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                                )
                            
                            Text(color.displayName)
                        }
                        .tag(color)
                    }
                }
                .pickerStyle(.navigationLink)
                .onChange(of: selectedBottomBarColor) { _, newValue in
                    AppSettings.shared.bitCardBottomBarColor = newValue
                }
                
                Picker("Bit Window Theme", selection: $selectedWindowTheme) {
                    ForEach(BitWindowTheme.allCases) { theme in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(theme.displayName)
                                .font(.body)
                            Text(theme.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(theme)
                    }
                }
                .pickerStyle(.navigationLink)
                .onChange(of: selectedWindowTheme) { _, newValue in
                    AppSettings.shared.bitWindowTheme = newValue
                }
            } header: {
                Text("Bit Card Theme")
            } footer: {
                Text("Customize the colors and theme for your shareable bit cards. The background frame wraps the entire card, the bottom bar displays your branding, and the bit window theme styles the text area.")
            }
            
            // Preview section
            Section {
                VStack(spacing: 12) {
                    Text("Preview")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    BitCardPreview(
                        frameColor: selectedFrameColor,
                        bottomBarColor: selectedBottomBarColor,
                        windowTheme: selectedWindowTheme
                    )
                }
            } header: {
                Text("Preview")
            }
        }
        .scrollContentBackground(.hidden)
        .tfBackground()
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                TFWordmarkTitle(title: "Settings", size: 22)
            }
        }
    }
}

// MARK: - Preview Component

private struct BitCardPreview: View {
    let frameColor: BitCardFrameColor
    let bottomBarColor: BitCardFrameColor
    let windowTheme: BitWindowTheme
    
    var body: some View {
        VStack(spacing: 0) {
            // Main content area with rounded top corners
            VStack(alignment: .leading, spacing: 12) {
                Text("This is what your shareable bit card will look like with the selected colors.")
                    .font(.system(size: 14))
                    .foregroundStyle(windowTheme == .chalkboard ? .white.opacity(0.9) : .black.opacity(0.85))
                    .lineSpacing(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(
                ZStack {
                    if windowTheme == .chalkboard {
                        // Original chalkboard theme
                        Color("TFCard")
                        
                        StaticGritLayer(
                            density: 300,
                            opacity: 0.55,
                            seed: 1234,
                            particleColor: Color("TFYellow")
                        )
                        
                        StaticGritLayer(
                            density: 300,
                            opacity: 0.35,
                            seed: 5678
                        )
                    } else {
                        // Yellow grit theme
                        Color("TFYellow")
                        
                        StaticGritLayer(
                            density: 800,
                            opacity: 0.85,
                            seed: 7777,
                            particleColor: .brown
                        )
                        
                        StaticGritLayer(
                            density: 100,
                            opacity: 0.88,
                            seed: 8888,
                            particleColor: .black
                        )
                        
                        StaticGritLayer(
                            density: 400,
                            opacity: 0.88,
                            seed: 8888,
                            particleColor: Color(red: 0.8, green: 0.4, blue: 0.0)
                        )
                    }
                    
                    UnevenRoundedRectangle(
                        topLeadingRadius: 8,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 8,
                        style: .continuous
                    )
                    .fill(
                        RadialGradient(
                            colors: [.clear, .black.opacity(windowTheme == .chalkboard ? 0.3 : 0.15)],
                            center: .center,
                            startRadius: 50,
                            endRadius: 200
                        )
                    )
                }
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 8,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 8,
                        style: .continuous
                    )
                )
            )
            .overlay(
                UnevenRoundedRectangle(
                    topLeadingRadius: 8,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 8,
                    style: .continuous
                )
                .strokeBorder(Color("TFCardStroke"), lineWidth: 1)
                .opacity(0.6)
                .blendMode(.overlay)
            )
            
            // Polaroid bar at bottom with rounded bottom corners
            HStack(spacing: 6) {
                Spacer()
                Image(systemName: "5.square.fill")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(TFTheme.yellow)
                
                Text("written in TightFive")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .kerning(0.5)
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 8,
                    bottomTrailingRadius: 8,
                    topTrailingRadius: 0,
                    style: .continuous
                )
                .fill(bottomBarColor.color)
            )
        }
        .padding(8) // Creates the frame effect
        .background(frameColor.color)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}



#Preview {
    NavigationStack {
        SettingsView()
    }
}
