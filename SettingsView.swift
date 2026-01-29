import SwiftUI

struct SettingsView: View {
    @State private var selectedColor: BitCardFrameColor = AppSettings.shared.bitCardFrameColor
    
    var body: some View {
        Form {
            Section {
                Picker("Frame Color", selection: $selectedColor) {
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
                .onChange(of: selectedColor) { _, newValue in
                    AppSettings.shared.bitCardFrameColor = newValue
                }
            } header: {
                Text("Bit Card Theme")
            } footer: {
                Text("Choose the frame color for your shareable bit cards. This affects the polaroid-style frame when you share bits.")
            }
            
            // Preview section
            Section {
                VStack(spacing: 12) {
                    Text("Preview")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    BitCardPreview(frameColor: selectedColor)
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
    
    var body: some View {
        VStack(spacing: 0) {
            // Main content area
            VStack(alignment: .leading, spacing: 12) {
                Text("This is what your shareable bit card will look like with the selected frame color.")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineSpacing(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(Color("TFCard"))
            
            // Polaroid bar at bottom
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
            .background(frameColor.color)
        }
        .background(frameColor.color)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(frameColor.color, lineWidth: 8)
        )
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}



#Preview {
    NavigationStack {
        SettingsView()
    }
}
