import SwiftUI

struct SettingsView: View {
    @State private var selectedFrameColor: BitCardFrameColor = AppSettings.shared.bitCardFrameColor
    @State private var selectedBottomBarColor: BitCardFrameColor = AppSettings.shared.bitCardBottomBarColor
    @State private var selectedWindowTheme: BitWindowTheme = AppSettings.shared.bitWindowTheme
    @State private var bitCardGritLevel: Double = AppSettings.shared.bitCardGritLevel
    
    @State private var selectedTileCardTheme: TileCardTheme = AppSettings.shared.tileCardTheme
    @State private var selectedQuickBitTheme: TileCardTheme = AppSettings.shared.quickBitTheme
    @State private var appGritLevel: Double = AppSettings.shared.appGritLevel
    @State private var selectedAppFont: AppFont = AppSettings.shared.appFont
    
    // Font customization
    @State private var appFontColor: Color = Color(hex: AppSettings.shared.appFontColorHex) ?? .white
    @State private var appFontSizeMultiplier: Double = AppSettings.shared.appFontSizeMultiplier
    
    // Quick Bit advanced customization
    @State private var quickBitCustomColor: Color = Color(hex: AppSettings.shared.quickBitCustomColorHex) ?? Color("TFYellow")
    @State private var quickBitGritEnabled: Bool = AppSettings.shared.quickBitGritEnabled
    @State private var quickBitGritLayer1Color: Color = Color(hex: AppSettings.shared.quickBitGritLayer1ColorHex) ?? .brown
    @State private var quickBitGritLayer2Color: Color = Color(hex: AppSettings.shared.quickBitGritLayer2ColorHex) ?? .black
    @State private var quickBitGritLayer3Color: Color = Color(hex: AppSettings.shared.quickBitGritLayer3ColorHex) ?? Color(red: 0.8, green: 0.4, blue: 0.0)
    
    // Tile Card advanced customization
    @State private var tileCardCustomColor: Color = Color(hex: AppSettings.shared.tileCardCustomColorHex) ?? Color("TFCard")
    @State private var tileCardGritEnabled: Bool = AppSettings.shared.tileCardGritEnabled
    @State private var tileCardGritLayer1Color: Color = Color(hex: AppSettings.shared.tileCardGritLayer1ColorHex) ?? Color("TFYellow")
    @State private var tileCardGritLayer2Color: Color = Color(hex: AppSettings.shared.tileCardGritLayer2ColorHex) ?? .white.opacity(0.3)
    @State private var tileCardGritLayer3Color: Color = Color(hex: AppSettings.shared.tileCardGritLayer3ColorHex) ?? .white.opacity(0.1)
    
    @State private var showFrameColorPicker = false
    @State private var showBottomBarColorPicker = false
    @State private var customFrameColor: Color = Color(hex: AppSettings.shared.customFrameColorHex) ?? Color("TFCard")
    @State private var customBottomBarColor: Color = Color(hex: AppSettings.shared.customBottomBarColorHex) ?? Color("TFCard")
    
    var body: some View {
        Form {
            Section {
                Picker("Background Frame", selection: $selectedFrameColor) {
                    ForEach(BitCardFrameColor.allCases) { color in
                        HStack {
                            Circle()
                                .fill(color == .custom ? customFrameColor : color.color(customHex: AppSettings.shared.customFrameColorHex))
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
                    if newValue == .custom {
                        showFrameColorPicker = true
                    }
                }
                
                // Show custom color picker button if custom is selected
                if selectedFrameColor == .custom {
                    Button {
                        showFrameColorPicker = true
                    } label: {
                        HStack {
                            Text("Choose Custom Color")
                                .foregroundStyle(.white)
                            Spacer()
                            Circle()
                                .fill(customFrameColor)
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Circle()
                                        .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                                )
                        }
                    }
                }
                
                Picker("Bottom Bar", selection: $selectedBottomBarColor) {
                    ForEach(BitCardFrameColor.allCases) { color in
                        HStack {
                            Circle()
                                .fill(color == .custom ? customBottomBarColor : color.color(customHex: AppSettings.shared.customBottomBarColorHex))
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
                    if newValue == .custom {
                        showBottomBarColorPicker = true
                    }
                }
                
                // Show custom color picker button if custom is selected
                if selectedBottomBarColor == .custom {
                    Button {
                        showBottomBarColorPicker = true
                    } label: {
                        HStack {
                            Text("Choose Custom Color")
                                .foregroundStyle(.white)
                            Spacer()
                            Circle()
                                .fill(customBottomBarColor)
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Circle()
                                        .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                                )
                        }
                    }
                }
                
                Picker("Bit Window Theme", selection: $selectedWindowTheme) {
                    ForEach(BitWindowTheme.allCases) { theme in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(theme.displayName)
                                .appFont(.body)
                            Text(theme.description)
                                .appFont(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(theme)
                    }
                }
                .pickerStyle(.navigationLink)
                .onChange(of: selectedWindowTheme) { _, newValue in
                    AppSettings.shared.bitWindowTheme = newValue
                }
                
                // Grit level slider for shareable bit cards (only if using textured theme)
                if AppSettings.shared.hasAnyTexturedTheme {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Grit Level")
                                .appFont(.body)
                            Spacer()
                            Text(bitCardGritLevel == 0 ? "None" : bitCardGritLevel == 1.0 ? "Max" : "\(Int(bitCardGritLevel * 100))%")
                                .font(.body.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        
                        HStack(spacing: 12) {
                            Text("0")
                                .appFont(.caption)
                                .foregroundStyle(.secondary)
                            
                            Slider(value: $bitCardGritLevel, in: 0...1.0, step: 0.05)
                                .tint(TFTheme.yellow)
                                .onChange(of: bitCardGritLevel) { _, newValue in
                                    AppSettings.shared.bitCardGritLevel = newValue
                                }
                            
                            Text("Max")
                                .appFont(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("Bit Card Theme")
            } footer: {
                if AppSettings.shared.hasAnyTexturedTheme {
                    Text("Customize the colors and theme for your shareable bit cards. Use the Grit Level slider to adjust the density of the texture effect on exported cards.")
                } else {
                    Text("Customize the colors and theme for your shareable bit cards. The background frame wraps the entire card, the bottom bar displays your branding, and the bit window theme styles the text area.")
                }
            }
            
            // Preview section
            Section {
                VStack(spacing: 12) {
                    Text("Preview")
                        .appFont(.caption, weight: .semibold)
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    BitCardPreview(
                        frameColor: selectedFrameColor,
                        bottomBarColor: selectedBottomBarColor,
                        windowTheme: selectedWindowTheme,
                        gritLevel: bitCardGritLevel
                    )
                }
            } header: {
                Text("Preview")
            }
            
            // App Customization section
            Section {
                Picker("Tile Card Theme", selection: $selectedTileCardTheme) {
                    ForEach(TileCardTheme.allCases) { theme in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(theme.displayName)
                                .appFont(.body)
                            Text(theme.description)
                                .appFont(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(theme)
                    }
                }
                .pickerStyle(.navigationLink)
                .onChange(of: selectedTileCardTheme) { _, newValue in
                    AppSettings.shared.tileCardTheme = newValue
                }
                
                // Advanced Tile Card Customization (only show if custom theme is selected)
                if selectedTileCardTheme == .custom {
                    DisclosureGroup("Advanced Tile Card Customization") {
                    VStack(spacing: 16) {
                        // Custom background color with hex input
                        VStack(alignment: .leading, spacing: 8) {
                            ColorPicker("Background Color", selection: $tileCardCustomColor, supportsOpacity: false)
                                .onChange(of: tileCardCustomColor) { _, newValue in
                                    if let hex = newValue.toHex() {
                                        AppSettings.shared.tileCardCustomColorHex = hex
                                    }
                                }
                            
                            HStack {
                                Text("Hex:")
                                    .appFont(.caption)
                                    .foregroundStyle(.secondary)
                                TextField("", text: Binding(
                                    get: { AppSettings.shared.tileCardCustomColorHex },
                                    set: { newValue in
                                        AppSettings.shared.tileCardCustomColorHex = newValue
                                        if let color = Color(hex: newValue) {
                                            tileCardCustomColor = color
                                        }
                                    }
                                ))
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                                .font(.system(.body, design: .monospaced))
                                .textFieldStyle(.roundedBorder)
                            }
                        }
                        
                        Divider()
                        
                        // Grit toggle
                        Toggle("Enable Grit Texture", isOn: $tileCardGritEnabled)
                            .onChange(of: tileCardGritEnabled) { _, newValue in
                                AppSettings.shared.tileCardGritEnabled = newValue
                            }
                        
                        if tileCardGritEnabled {
                            VStack(spacing: 16) {
                                Text("Grit Layer Colors")
                                    .appFont(.caption, weight: .semibold)
                                    .foregroundStyle(.white.opacity(0.6))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                // Layer 1
                                VStack(alignment: .leading, spacing: 8) {
                                    ColorPicker("Layer 1 (Primary)", selection: $tileCardGritLayer1Color, supportsOpacity: false)
                                        .onChange(of: tileCardGritLayer1Color) { _, newValue in
                                            if let hex = newValue.toHex() {
                                                AppSettings.shared.tileCardGritLayer1ColorHex = hex
                                            }
                                        }
                                    
                                    HStack {
                                        Text("Hex:")
                                            .appFont(.caption)
                                            .foregroundStyle(.secondary)
                                        TextField("", text: Binding(
                                            get: { AppSettings.shared.tileCardGritLayer1ColorHex },
                                            set: { newValue in
                                                AppSettings.shared.tileCardGritLayer1ColorHex = newValue
                                                if let color = Color(hex: newValue) {
                                                    tileCardGritLayer1Color = color
                                                }
                                            }
                                        ))
                                        .textInputAutocapitalization(.characters)
                                        .autocorrectionDisabled()
                                        .font(.system(.caption, design: .monospaced))
                                        .textFieldStyle(.roundedBorder)
                                    }
                                }
                                
                                // Layer 2
                                VStack(alignment: .leading, spacing: 8) {
                                    ColorPicker("Layer 2 (Secondary)", selection: $tileCardGritLayer2Color, supportsOpacity: false)
                                        .onChange(of: tileCardGritLayer2Color) { _, newValue in
                                            if let hex = newValue.toHex() {
                                                AppSettings.shared.tileCardGritLayer2ColorHex = hex
                                            }
                                        }
                                    
                                    HStack {
                                        Text("Hex:")
                                            .appFont(.caption)
                                            .foregroundStyle(.secondary)
                                        TextField("", text: Binding(
                                            get: { AppSettings.shared.tileCardGritLayer2ColorHex },
                                            set: { newValue in
                                                AppSettings.shared.tileCardGritLayer2ColorHex = newValue
                                                if let color = Color(hex: newValue) {
                                                    tileCardGritLayer2Color = color
                                                }
                                            }
                                        ))
                                        .textInputAutocapitalization(.characters)
                                        .autocorrectionDisabled()
                                        .font(.system(.caption, design: .monospaced))
                                        .textFieldStyle(.roundedBorder)
                                    }
                                }
                                
                                // Layer 3
                                VStack(alignment: .leading, spacing: 8) {
                                    ColorPicker("Layer 3 (Accent)", selection: $tileCardGritLayer3Color, supportsOpacity: false)
                                        .onChange(of: tileCardGritLayer3Color) { _, newValue in
                                            if let hex = newValue.toHex() {
                                                AppSettings.shared.tileCardGritLayer3ColorHex = hex
                                            }
                                        }
                                    
                                    HStack {
                                        Text("Hex:")
                                            .appFont(.caption)
                                            .foregroundStyle(.secondary)
                                        TextField("", text: Binding(
                                            get: { AppSettings.shared.tileCardGritLayer3ColorHex },
                                            set: { newValue in
                                                AppSettings.shared.tileCardGritLayer3ColorHex = newValue
                                                if let color = Color(hex: newValue) {
                                                    tileCardGritLayer3Color = color
                                                }
                                            }
                                        ))
                                        .textInputAutocapitalization(.characters)
                                        .autocorrectionDisabled()
                                        .font(.system(.caption, design: .monospaced))
                                        .textFieldStyle(.roundedBorder)
                                    }
                                }
                            }
                            .padding(.leading, 8)
                        }
                    }
                    .padding(.vertical, 8)
                }
                }
                
                Picker("Quick Bit Button", selection: $selectedQuickBitTheme) {
                    ForEach(TileCardTheme.allCases) { theme in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(theme.displayName)
                                .appFont(.body)
                            Text(theme.description)
                                .appFont(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(theme)
                    }
                }
                .pickerStyle(.navigationLink)
                .onChange(of: selectedQuickBitTheme) { _, newValue in
                    AppSettings.shared.quickBitTheme = newValue
                }
                
                // Advanced Quick Bit Customization (only show if custom theme is selected)
                if selectedQuickBitTheme == .custom {
                    DisclosureGroup("Advanced Quick Bit Customization") {
                    VStack(spacing: 16) {
                        // Custom background color with hex input
                        VStack(alignment: .leading, spacing: 8) {
                            ColorPicker("Background Color", selection: $quickBitCustomColor, supportsOpacity: false)
                                .onChange(of: quickBitCustomColor) { _, newValue in
                                    if let hex = newValue.toHex() {
                                        AppSettings.shared.quickBitCustomColorHex = hex
                                    }
                                }
                            
                            HStack {
                                Text("Hex:")
                                    .appFont(.caption)
                                    .foregroundStyle(.secondary)
                                TextField("", text: Binding(
                                    get: { AppSettings.shared.quickBitCustomColorHex },
                                    set: { newValue in
                                        AppSettings.shared.quickBitCustomColorHex = newValue
                                        if let color = Color(hex: newValue) {
                                            quickBitCustomColor = color
                                        }
                                    }
                                ))
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                                .font(.system(.body, design: .monospaced))
                                .textFieldStyle(.roundedBorder)
                            }
                        }
                        
                        Divider()
                        
                        // Grit toggle
                        Toggle("Enable Grit Texture", isOn: $quickBitGritEnabled)
                            .onChange(of: quickBitGritEnabled) { _, newValue in
                                AppSettings.shared.quickBitGritEnabled = newValue
                            }
                        
                        if quickBitGritEnabled {
                            VStack(spacing: 16) {
                                Text("Grit Layer Colors")
                                    .appFont(.caption, weight: .semibold)
                                    .foregroundStyle(.white.opacity(0.6))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                // Layer 1
                                VStack(alignment: .leading, spacing: 8) {
                                    ColorPicker("Layer 1 (Primary)", selection: $quickBitGritLayer1Color, supportsOpacity: false)
                                        .onChange(of: quickBitGritLayer1Color) { _, newValue in
                                            if let hex = newValue.toHex() {
                                                AppSettings.shared.quickBitGritLayer1ColorHex = hex
                                            }
                                        }
                                    
                                    HStack {
                                        Text("Hex:")
                                            .appFont(.caption)
                                            .foregroundStyle(.secondary)
                                        TextField("", text: Binding(
                                            get: { AppSettings.shared.quickBitGritLayer1ColorHex },
                                            set: { newValue in
                                                AppSettings.shared.quickBitGritLayer1ColorHex = newValue
                                                if let color = Color(hex: newValue) {
                                                    quickBitGritLayer1Color = color
                                                }
                                            }
                                        ))
                                        .textInputAutocapitalization(.characters)
                                        .autocorrectionDisabled()
                                        .font(.system(.caption, design: .monospaced))
                                        .textFieldStyle(.roundedBorder)
                                    }
                                }
                                
                                // Layer 2
                                VStack(alignment: .leading, spacing: 8) {
                                    ColorPicker("Layer 2 (Secondary)", selection: $quickBitGritLayer2Color, supportsOpacity: false)
                                        .onChange(of: quickBitGritLayer2Color) { _, newValue in
                                            if let hex = newValue.toHex() {
                                                AppSettings.shared.quickBitGritLayer2ColorHex = hex
                                            }
                                        }
                                    
                                    HStack {
                                        Text("Hex:")
                                            .appFont(.caption)
                                            .foregroundStyle(.secondary)
                                        TextField("", text: Binding(
                                            get: { AppSettings.shared.quickBitGritLayer2ColorHex },
                                            set: { newValue in
                                                AppSettings.shared.quickBitGritLayer2ColorHex = newValue
                                                if let color = Color(hex: newValue) {
                                                    quickBitGritLayer2Color = color
                                                }
                                            }
                                        ))
                                        .textInputAutocapitalization(.characters)
                                        .autocorrectionDisabled()
                                        .font(.system(.caption, design: .monospaced))
                                        .textFieldStyle(.roundedBorder)
                                    }
                                }
                                
                                // Layer 3
                                VStack(alignment: .leading, spacing: 8) {
                                    ColorPicker("Layer 3 (Accent)", selection: $quickBitGritLayer3Color, supportsOpacity: false)
                                        .onChange(of: quickBitGritLayer3Color) { _, newValue in
                                            if let hex = newValue.toHex() {
                                                AppSettings.shared.quickBitGritLayer3ColorHex = hex
                                            }
                                        }
                                    
                                    HStack {
                                        Text("Hex:")
                                            .appFont(.caption)
                                            .foregroundStyle(.secondary)
                                        TextField("", text: Binding(
                                            get: { AppSettings.shared.quickBitGritLayer3ColorHex },
                                            set: { newValue in
                                                AppSettings.shared.quickBitGritLayer3ColorHex = newValue
                                                if let color = Color(hex: newValue) {
                                                    quickBitGritLayer3Color = color
                                                }
                                            }
                                        ))
                                        .textInputAutocapitalization(.characters)
                                        .autocorrectionDisabled()
                                        .font(.system(.caption, design: .monospaced))
                                        .textFieldStyle(.roundedBorder)
                                    }
                                }
                            }
                            .padding(.leading, 8)
                        }
                    }
                    .padding(.vertical, 8)
                }
                }
                
                // Grit level slider for app UI elements (tile cards, Quick Bit button)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Grit Level")
                            .appFont(.body)
                        Spacer()
                        Text(appGritLevel == 0 ? "None" : appGritLevel == 1.0 ? "Max" : "\(Int(appGritLevel * 100))%")
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack(spacing: 12) {
                        Text("0")
                            .appFont(.caption)
                            .foregroundStyle(.secondary)
                        
                        Slider(value: $appGritLevel, in: 0...1.0, step: 0.05)
                            .tint(TFTheme.yellow)
                            .onChange(of: appGritLevel) { _, newValue in
                                AppSettings.shared.appGritLevel = newValue
                            }
                        
                        Text("Max")
                            .appFont(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
                
                Picker("App Font", selection: $selectedAppFont) {
                    ForEach(AppFont.allCases) { font in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(font.displayName)
                                .appFont(.body)
                            Text(font.description)
                                .appFont(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(font)
                    }
                }
                .pickerStyle(.navigationLink)
                .onChange(of: selectedAppFont) { _, newValue in
                    AppSettings.shared.appFont = newValue
                }
                
                // Font Color Picker
                VStack(alignment: .leading, spacing: 8) {
                    ColorPicker("Font Color", selection: $appFontColor, supportsOpacity: false)
                        .onChange(of: appFontColor) { _, newValue in
                            if let hex = newValue.toHex() {
                                AppSettings.shared.appFontColorHex = hex
                            }
                        }
                    
                    Text("Current: \(AppSettings.shared.appFontColorHex)")
                        .appFont(.caption)
                        .foregroundStyle(.secondary)
                    TextField("", text: Binding(
                        get: { AppSettings.shared.appFontColorHex },
                        set: { newValue in
                            AppSettings.shared.appFontColorHex = newValue
                            if let color = Color(hex: newValue) {
                                appFontColor = color
                            }
                        }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                }
                
                // Font Size Slider
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Font Size")
                            .appFont(.headline)
                        
                        Spacer()
                        
                        Text("\(Int(appFontSizeMultiplier * 100))%")
                            .appFont(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack(spacing: 12) {
                        Text("Small")
                            .appFont(.caption)
                            .foregroundStyle(.secondary)
                        
                        Slider(value: $appFontSizeMultiplier, in: 0.8...1.4, step: 0.05)
                            .tint(TFTheme.yellow)
                            .onChange(of: appFontSizeMultiplier) { _, newValue in
                                AppSettings.shared.appFontSizeMultiplier = newValue
                            }
                        
                        Text("Large")
                            .appFont(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Button("Reset to Default (100%)") {
                        appFontSizeMultiplier = 1.0
                        AppSettings.shared.appFontSizeMultiplier = 1.0
                    }
                    .appFont(.caption)
                    .foregroundStyle(TFTheme.yellow)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Theme Customization")
            } footer: {
                Text("Customize the appearance of tile cards, Quick Bit button, fonts, and colors throughout the app. The Grit Level controls texture density for these elements only.")
            }
            
            // Theme Preview section
            Section {
                VStack(spacing: 16) {
                    Text("Font Preview")
                        .appFont(.caption, weight: .semibold)
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    FontPreview(
                        appFont: selectedAppFont,
                        fontColor: appFontColor,
                        fontSizeMultiplier: appFontSizeMultiplier
                    )
                    
                    Text("Quick Bit Button Preview")
                        .appFont(.caption, weight: .semibold)
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)
                    
                    QuickBitButtonPreview(
                        theme: selectedQuickBitTheme,
                        gritLevel: appGritLevel,
                        customColor: quickBitCustomColor,
                        gritEnabled: quickBitGritEnabled,
                        gritLayer1Color: quickBitGritLayer1Color,
                        gritLayer2Color: quickBitGritLayer2Color,
                        gritLayer3Color: quickBitGritLayer3Color,
                        appFont: selectedAppFont
                    )
                    
                    Text("Tile Card Preview")
                        .appFont(.caption, weight: .semibold)
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)
                    
                    TileCardPreview(
                        theme: selectedTileCardTheme,
                        gritLevel: appGritLevel,
                        customColor: tileCardCustomColor,
                        gritEnabled: tileCardGritEnabled,
                        gritLayer1Color: tileCardGritLayer1Color,
                        gritLayer2Color: tileCardGritLayer2Color,
                        gritLayer3Color: tileCardGritLayer3Color,
                        appFont: selectedAppFont
                    )
                }
            } header: {
                Text("Theme Preview")
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
        .sheet(isPresented: $showFrameColorPicker) {
            ColorPickerSheet(
                title: "Frame Color",
                selectedColor: $customFrameColor,
                onSave: {
                    if let hex = customFrameColor.toHex() {
                        AppSettings.shared.customFrameColorHex = hex
                    }
                }
            )
        }
        .sheet(isPresented: $showBottomBarColorPicker) {
            ColorPickerSheet(
                title: "Bottom Bar Color",
                selectedColor: $customBottomBarColor,
                onSave: {
                    if let hex = customBottomBarColor.toHex() {
                        AppSettings.shared.customBottomBarColorHex = hex
                    }
                }
            )
        }
    }
}

// MARK: - Preview Component

private struct BitCardPreview: View {
    let frameColor: BitCardFrameColor
    let bottomBarColor: BitCardFrameColor
    let windowTheme: BitWindowTheme
    let gritLevel: Double
    
    private var resolvedFrameColor: Color {
        if frameColor == .custom {
            return Color(hex: AppSettings.shared.customFrameColorHex) ?? Color("TFCard")
        }
        return frameColor.color(customHex: nil)
    }
    
    private var resolvedBottomBarColor: Color {
        if bottomBarColor == .custom {
            return Color(hex: AppSettings.shared.customBottomBarColorHex) ?? Color("TFCard")
        }
        return bottomBarColor.color(customHex: nil)
    }
    
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
                        
                        if gritLevel > 0 {
                            StaticGritLayer(
                                density: Int(300 * gritLevel),
                                opacity: 0.55,
                                seed: 1234,
                                particleColor: Color("TFYellow")
                            )
                            
                            StaticGritLayer(
                                density: Int(300 * gritLevel),
                                opacity: 0.35,
                                seed: 5678
                            )
                        }
                    } else {
                        // Yellow grit theme
                        Color("TFYellow")
                        
                        if gritLevel > 0 {
                            StaticGritLayer(
                                density: Int(800 * gritLevel),
                                opacity: 0.85,
                                seed: 7777,
                                particleColor: .brown
                            )
                            
                            StaticGritLayer(
                                density: Int(100 * gritLevel),
                                opacity: 0.88,
                                seed: 8888,
                                particleColor: .black
                            )
                            
                            StaticGritLayer(
                                density: Int(400 * gritLevel),
                                opacity: 0.88,
                                seed: 8888,
                                particleColor: Color(red: 0.8, green: 0.4, blue: 0.0)
                            )
                        }
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
                    .foregroundStyle(bottomBarColor.hasTexture && bottomBarColor == .yellowGrit ? .black.opacity(0.85) : TFTheme.yellow)
                
                Text("written in TightFive")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(bottomBarColor.hasTexture && bottomBarColor == .yellowGrit ? .black.opacity(0.85) : .white)
                    .kerning(0.5)
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                ZStack {
                    if bottomBarColor.hasTexture, let theme = bottomBarColor.textureTheme {
                        // Render textured background
                        if theme == .chalkboard {
                            Color("TFCard")
                            
                            if gritLevel > 0 {
                                StaticGritLayer(
                                    density: Int(300 * gritLevel),
                                    opacity: 0.55,
                                    seed: 1234,
                                    particleColor: Color("TFYellow")
                                )
                                
                                StaticGritLayer(
                                    density: Int(300 * gritLevel),
                                    opacity: 0.35,
                                    seed: 5678
                                )
                            }
                        } else {
                            Color("TFYellow")
                            
                            if gritLevel > 0 {
                                StaticGritLayer(
                                    density: Int(800 * gritLevel),
                                    opacity: 0.85,
                                    seed: 7777,
                                    particleColor: .brown
                                )
                                
                                StaticGritLayer(
                                    density: Int(100 * gritLevel),
                                    opacity: 0.88,
                                    seed: 8888,
                                    particleColor: .black
                                )
                                
                                StaticGritLayer(
                                    density: Int(400 * gritLevel),
                                    opacity: 0.88,
                                    seed: 8888,
                                    particleColor: Color(red: 0.8, green: 0.4, blue: 0.0)
                                )
                            }
                        }
                    }
                    
                    UnevenRoundedRectangle(
                        topLeadingRadius: 0,
                        bottomLeadingRadius: 8,
                        bottomTrailingRadius: 8,
                        topTrailingRadius: 0,
                        style: .continuous
                    )
                    .fill(bottomBarColor.hasTexture ? .clear : resolvedBottomBarColor)
                }
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 0,
                        bottomLeadingRadius: 8,
                        bottomTrailingRadius: 8,
                        topTrailingRadius: 0,
                        style: .continuous
                    )
                )
            )
        }
        .padding(8) // Creates the frame effect
        .background(
            ZStack {
                if frameColor.hasTexture, let theme = frameColor.textureTheme {
                    // Render textured frame background
                    if theme == .chalkboard {
                        Color("TFCard")
                        
                        if gritLevel > 0 {
                            StaticGritLayer(
                                density: Int(300 * gritLevel),
                                opacity: 0.55,
                                seed: 9999,
                                particleColor: Color("TFYellow")
                            )
                            
                            StaticGritLayer(
                                density: Int(300 * gritLevel),
                                opacity: 0.35,
                                seed: 1111
                            )
                        }
                    } else if theme == .yellowGrit {
                        Color("TFYellow")
                        
                        if gritLevel > 0 {
                            StaticGritLayer(
                                density: Int(800 * gritLevel),
                                opacity: 0.85,
                                seed: 2222,
                                particleColor: .brown
                            )
                            
                            StaticGritLayer(
                                density: Int(100 * gritLevel),
                                opacity: 0.88,
                                seed: 3333,
                                particleColor: .black
                            )
                            
                            StaticGritLayer(
                                density: Int(400 * gritLevel),
                                opacity: 0.88,
                                seed: 4444,
                                particleColor: Color(red: 0.8, green: 0.4, blue: 0.0)
                            )
                        }
                    }
                } else {
                    // Solid color frame
                    resolvedFrameColor
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Quick Bit Button Preview

private struct QuickBitButtonPreview: View {
    let theme: TileCardTheme
    let gritLevel: Double
    let customColor: Color
    let gritEnabled: Bool
    let gritLayer1Color: Color
    let gritLayer2Color: Color
    let gritLayer3Color: Color
    let appFont: AppFont
    
    private func textColor(for theme: TileCardTheme, customColor: Color) -> Color {
        switch theme {
        case .yellowGrit:
            return .black.opacity(0.85)
        case .darkGrit:
            return .white
        case .custom:
            // Calculate luminance to determine if we should use light or dark text
            if let components = UIColor(customColor).cgColor.components, components.count >= 3 {
                let r = components[0]
                let g = components[1]
                let b = components[2]
                let luminance = 0.299 * r + 0.587 * g + 0.114 * b
                return luminance > 0.5 ? .black.opacity(0.85) : .white
            }
            return .white
        }
    }
    
    var body: some View {
        HStack {
            Spacer()
            
            Button {
                // Preview only
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(textColor(for: theme, customColor: customColor))
                    
                    Text("Quick Bit")
                        .font(appFont.font(size: 16).weight(.bold))
                        .foregroundStyle(textColor(for: theme, customColor: customColor))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    ZStack {
                        if theme == .darkGrit {
                            Color("TFCard")
                            
                            if gritLevel > 0 {
                                StaticGritLayer(
                                    density: Int(300 * gritLevel),
                                    opacity: 0.55,
                                    seed: 9001,
                                    particleColor: Color("TFYellow")
                                )
                                
                                StaticGritLayer(
                                    density: Int(300 * gritLevel),
                                    opacity: 0.35,
                                    seed: 9002
                                )
                            }
                        } else if theme == .yellowGrit {
                            Color("TFYellow")
                            
                            if gritLevel > 0 {
                                StaticGritLayer(
                                    density: Int(800 * gritLevel),
                                    opacity: 0.85,
                                    seed: 9003,
                                    particleColor: .brown
                                )
                                
                                StaticGritLayer(
                                    density: Int(100 * gritLevel),
                                    opacity: 0.88,
                                    seed: 9004,
                                    particleColor: .black
                                )
                                
                                StaticGritLayer(
                                    density: Int(400 * gritLevel),
                                    opacity: 0.88,
                                    seed: 9005,
                                    particleColor: Color(red: 0.8, green: 0.4, blue: 0.0)
                                )
                            }
                        } else if theme == .custom {
                            customColor
                            
                            if gritEnabled && gritLevel > 0 {
                                StaticGritLayer(
                                    density: Int(800 * gritLevel),
                                    opacity: 0.85,
                                    seed: 9006,
                                    particleColor: gritLayer1Color
                                )
                                
                                StaticGritLayer(
                                    density: Int(100 * gritLevel),
                                    opacity: 0.88,
                                    seed: 9007,
                                    particleColor: gritLayer2Color
                                )
                                
                                StaticGritLayer(
                                    density: Int(400 * gritLevel),
                                    opacity: 0.88,
                                    seed: 9008,
                                    particleColor: gritLayer3Color
                                )
                            }
                        }
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color("TFCardStroke"), lineWidth: 1)
                        .opacity(0.6)
                        .blendMode(.overlay)
                )
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Tile Card Preview

private struct TileCardPreview: View {
    let theme: TileCardTheme
    let gritLevel: Double
    let customColor: Color
    let gritEnabled: Bool
    let gritLayer1Color: Color
    let gritLayer2Color: Color
    let gritLayer3Color: Color
    let appFont: AppFont
    
    private func textColor(for theme: TileCardTheme, customColor: Color) -> Color {
        switch theme {
        case .yellowGrit:
            return .black.opacity(0.85)
        case .darkGrit:
            return .white
        case .custom:
            // Calculate luminance to determine if we should use light or dark text
            if let components = UIColor(customColor).cgColor.components, components.count >= 3 {
                let r = components[0]
                let g = components[1]
                let b = components[2]
                let luminance = 0.299 * r + 0.587 * g + 0.114 * b
                return luminance > 0.5 ? .black.opacity(0.85) : .white
            }
            return .white
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sample Bit")
                .font(appFont.font(size: 16).weight(.bold))
                .foregroundStyle(textColor(for: theme, customColor: customColor))
            
            Text("This is a preview of how your tile cards will appear in the app.")
                .font(appFont.font(size: 13).weight(.regular))
                .foregroundStyle(textColor(for: theme, customColor: customColor).opacity(0.9))
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            ZStack {
                if theme == .yellowGrit {
                    Color("TFYellow")
                    
                    if gritLevel > 0 {
                        StaticGritLayer(
                            density: Int(800 * gritLevel),
                            opacity: 0.85,
                            seed: 8003,
                            particleColor: .brown
                        )
                        
                        StaticGritLayer(
                            density: Int(100 * gritLevel),
                            opacity: 0.88,
                            seed: 8004,
                            particleColor: .black
                        )
                        
                        StaticGritLayer(
                            density: Int(400 * gritLevel),
                            opacity: 0.88,
                            seed: 8005,
                            particleColor: Color(red: 0.8, green: 0.4, blue: 0.0)
                        )
                    }
                } else if theme == .custom {
                    customColor
                    
                    if gritEnabled && gritLevel > 0 {
                        StaticGritLayer(
                            density: Int(300 * gritLevel),
                            opacity: 0.55,
                            seed: 8006,
                            particleColor: gritLayer1Color
                        )
                        
                        StaticGritLayer(
                            density: Int(300 * gritLevel),
                            opacity: 0.35,
                            seed: 8007,
                            particleColor: gritLayer2Color
                        )
                        
                        StaticGritLayer(
                            density: Int(200 * gritLevel),
                            opacity: 0.25,
                            seed: 8008,
                            particleColor: gritLayer3Color
                        )
                    }
                } else {
                    // Default darkGrit theme
                    Color("TFCard")
                    
                    if gritLevel > 0 {
                        StaticGritLayer(
                            density: Int(300 * gritLevel),
                            opacity: 0.55,
                            seed: 8001,
                            particleColor: Color("TFYellow")
                        )
                        
                        StaticGritLayer(
                            density: Int(300 * gritLevel),
                            opacity: 0.35,
                            seed: 8002
                        )
                    }
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color("TFCardStroke"), lineWidth: 1)
                .opacity(0.6)
                .blendMode(.overlay)
        )
        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Color Picker Sheet

private struct ColorPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    @Binding var selectedColor: Color
    let onSave: () -> Void
    
    @State private var hexInput: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ColorPicker("Pick a Color", selection: $selectedColor, supportsOpacity: false)
                } header: {
                    Text("Visual Picker")
                }
                
                Section {
                    HStack {
                        TextField("Hex Code", text: $hexInput)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .onChange(of: hexInput) { _, newValue in
                                if let color = Color(hex: newValue) {
                                    selectedColor = color
                                }
                            }
                        
                        Button("Paste") {
                            if let clipboardString = UIPasteboard.general.string {
                                hexInput = clipboardString
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(TFTheme.yellow)
                    }
                    
                    Text("Enter a 6-digit hex code (e.g., #FF5733)")
                        .appFont(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Hex Color Code")
                }
                
                Section {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(selectedColor)
                            .frame(width: 60, height: 60)
                            .overlay(
                                Circle()
                                    .strokeBorder(Color.white.opacity(0.3), lineWidth: 2)
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Preview")
                                .appFont(.headline)
                            Text(selectedColor.toHex() ?? "#000000")
                                .appFont(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                } header: {
                    Text("Preview")
                }
            }
            .scrollContentBackground(.hidden)
            .tfBackground()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(Color("TFYellow"))
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave()
                        dismiss()
                    }
                    .foregroundStyle(Color("TFYellow"))
                }
            }
        }
    }
}

// MARK: - Font Preview

private struct FontPreview: View {
    let appFont: AppFont
    let fontColor: Color
    let fontSizeMultiplier: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sample Text")
                .font(appFont.font(size: 20 * fontSizeMultiplier).weight(.bold))
                .foregroundStyle(fontColor)
            
            Text("This is how your custom font, color, and size will appear throughout the app. The quick brown fox jumps over the lazy dog.")
                .font(appFont.font(size: 15 * fontSizeMultiplier))
                .foregroundStyle(fontColor.opacity(0.85))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Font")
                        .appFont(.caption2)
                        .foregroundStyle(fontColor.opacity(0.5))
                    Text(appFont.displayName)
                        .appFont(.caption)
                        .foregroundStyle(fontColor.opacity(0.7))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Size")
                        .appFont(.caption2)
                        .foregroundStyle(fontColor.opacity(0.5))
                    Text("\(Int(fontSizeMultiplier * 100))%")
                        .appFont(.caption)
                        .foregroundStyle(fontColor.opacity(0.7))
                }
            }
        }
        .padding(16)
        .background(Color("TFCard"))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color("TFCardStroke").opacity(0.6), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
