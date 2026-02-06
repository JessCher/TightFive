import SwiftUI

/// Settings view for Cue Card (Stage Mode) configuration
struct CueCardSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var cueCardSettings = CueCardSettingsStore.shared
    @State private var scriptSettings = StageModeScriptSettings.shared
    @State private var teleprompterSettings = StageModeTeleprompterSettings.shared
    
    // Optional: pass setlist to check availability
    var setlist: Setlist?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Stage Mode Type Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Stage Mode Type")
                            .appFont(.title3, weight: .semibold)
                            .foregroundStyle(TFTheme.yellow)
                            .padding(.horizontal, 4)
                        
                        // Mode Picker Card
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Performance display mode")
                                .appFont(.headline)
                                .foregroundStyle(.white)
                            
                            Text("Choose how your script is displayed during performances")
                                .appFont(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                                .padding(.bottom, 4)
                            
                            Picker("Stage Mode Type", selection: $cueCardSettings.stageModeType) {
                                ForEach(StageModeType.allCases) { type in
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(type.displayName)
                                            .appFont(.body)
                                        Text(type.description)
                                            .appFont(.caption2)
                                            .foregroundStyle(.white.opacity(0.7))
                                    }
                                    .tag(type)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(TFTheme.yellow)
                            .disabled(!StageModeType.cueCards.isAvailable(for: setlist) && cueCardSettings.stageModeType == .cueCards)
                            
                            // Show warning if cue cards disabled
                            if let setlist = setlist, !setlist.cueCardsAvailable && cueCardSettings.stageModeType == .cueCards {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(.orange)
                                    Text("Cue Cards unavailable in Traditional mode without custom cards")
                                        .appFont(.caption)
                                        .foregroundStyle(.orange)
                                }
                                .padding(.top, 4)
                            }
                        }
                        .padding(16)
                        .tfDynamicCard(cornerRadius: 16)
                    }
                    
                    // Recording toggle (applies to all modes)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recording")
                            .appFont(.title3, weight: .semibold)
                            .foregroundStyle(TFTheme.yellow)
                            .padding(.horizontal, 4)

                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Record performances")
                                    .appFont(.headline)
                                    .foregroundStyle(.white)

                                Text("Capture audio during Stage Mode for show notes")
                                    .appFont(.caption)
                                    .foregroundStyle(.white.opacity(0.6))
                            }

                            Spacer()

                            Toggle("", isOn: $cueCardSettings.recordingEnabled)
                                .labelsHidden()
                                .tint(TFTheme.yellow)
                        }
                        .padding(16)
                        .tfDynamicCard(cornerRadius: 16)

                        if !cueCardSettings.recordingEnabled {
                            HStack(spacing: 8) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundStyle(.orange)
                                Text("Audio will not be captured during Stage Mode. Performance duration will still be tracked.")
                                    .appFont(.caption)
                                    .foregroundStyle(.orange.opacity(0.9))
                            }
                            .padding(.horizontal, 4)
                        }
                    }

                    // Mode-specific settings
                    switch cueCardSettings.stageModeType {
                    case .cueCards:
                        if setlist?.cueCardsAvailable ?? true {
                            cueCardSpecificSettings
                            cueCardDisplaySettings
                            animationSettings
                        } else {
                            cueCardsUnavailableView
                        }
                    case .script:
                        scriptDisplaySettings
                    case .teleprompter:
                        teleprompterDisplaySettings
                    }
                    
                    // Reset Button
                    Button {
                        resetCurrentModeSettings()
                    } label: {
                        Text("Reset to Defaults")
                            .appFont(.headline)
                            .foregroundStyle(TFTheme.yellow)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.top, 8)
                    
                    // Footer
                    Text("Customize your Stage Mode experience")
                        .appFont(.footnote)
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.top, 8)
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
            .tfBackground()
            .navigationTitle("Stage Mode Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    TFWordmarkTitle(title: "Stage Mode Settings", size: 20)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(TFTheme.yellow)
                }
            }
        }
    }
    
    private func resetCurrentModeSettings() {
        switch cueCardSettings.stageModeType {
        case .cueCards:
            cueCardSettings.resetToDefaults()
        case .script:
            scriptSettings.resetToDefaults()
        case .teleprompter:
            teleprompterSettings.resetToDefaults()
        }
    }
    
    // MARK: - Cue Card Specific Settings
    
    private var cueCardSpecificSettings: some View {
        VStack(spacing: 16) {
            // Auto-Advance Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Auto-Advance")
                    .appFont(.title3, weight: .semibold)
                    .foregroundStyle(TFTheme.yellow)
                    .padding(.horizontal, 4)
                
                // Auto-Advance Toggle Card
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Enable auto-advance")
                            .appFont(.headline)
                            .foregroundStyle(.white)
                        
                        Text("Automatically move to next card when exit phrase detected")
                            .appFont(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $cueCardSettings.autoAdvanceEnabled)
                        .labelsHidden()
                        .tint(TFTheme.yellow)
                }
                .padding(16)
                .tfDynamicCard(cornerRadius: 16)
                
                // Show Feedback Toggle Card
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Show phrase feedback")
                            .appFont(.headline)
                            .foregroundStyle(.white)
                        
                        Text("Display anchor/exit phrase detection indicators")
                            .appFont(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $cueCardSettings.showPhraseFeedback)
                        .labelsHidden()
                        .tint(TFTheme.yellow)
                }
                .padding(16)
                .tfDynamicCard(cornerRadius: 16)
            }
            
            // Recognition Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Speech Recognition")
                    .appFont(.title3, weight: .semibold)
                    .foregroundStyle(TFTheme.yellow)
                    .padding(.horizontal, 4)
                    .padding(.top, 8)
                
                // Exit Phrase Sensitivity Card
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Exit phrase sensitivity")
                            .appFont(.headline)
                            .foregroundStyle(.white)
                        Spacer()
                        Text("\(Int(cueCardSettings.exitPhraseSensitivity * 100))%")
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(TFTheme.yellow)
                    }
                    
                    Text("Higher = more precise match required")
                        .appFont(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                    
                    Slider(value: $cueCardSettings.exitPhraseSensitivity, in: 0.3...0.9, step: 0.05)
                        .tint(TFTheme.yellow)
                }
                .padding(16)
                .tfDynamicCard(cornerRadius: 16)
                
                // Anchor Phrase Sensitivity Card
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Anchor phrase sensitivity")
                            .appFont(.headline)
                            .foregroundStyle(.white)
                        Spacer()
                        Text("\(Int(cueCardSettings.anchorPhraseSensitivity * 100))%")
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(TFTheme.yellow)
                    }
                    
                    Text("Higher = more precise match required")
                        .appFont(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                    
                    Slider(value: $cueCardSettings.anchorPhraseSensitivity, in: 0.3...0.9, step: 0.05)
                        .tint(TFTheme.yellow)
                }
                .padding(16)
                .tfDynamicCard(cornerRadius: 16)
            }
        }
    }
    
    // MARK: - Cue Card Display Settings
    
    private var cueCardDisplaySettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Display")
                .appFont(.title3, weight: .semibold)
                .foregroundStyle(TFTheme.yellow)
                .padding(.horizontal, 4)
                .padding(.top, 8)
            
            // Font Size Card
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Font size")
                        .appFont(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Text("\(Int(cueCardSettings.fontSize)) pt")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(TFTheme.yellow)
                }
                
                Slider(value: $cueCardSettings.fontSize, in: 24...56, step: 2)
                    .tint(TFTheme.yellow)
            }
            .padding(16)
            .tfDynamicCard(cornerRadius: 16)
            
            // Line Spacing Card
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Line spacing")
                        .appFont(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Text("\(Int(cueCardSettings.lineSpacing)) pt")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(TFTheme.yellow)
                }
                
                Slider(value: $cueCardSettings.lineSpacing, in: 4...24, step: 2)
                    .tint(TFTheme.yellow)
            }
            .padding(16)
            .tfDynamicCard(cornerRadius: 16)
            
            // Text Color Card
            VStack(alignment: .leading, spacing: 10) {
                Text("Text color")
                    .appFont(.headline)
                    .foregroundStyle(.white)

                Picker("Text color", selection: $cueCardSettings.textColor) {
                    ForEach(CueCardTextColor.allCases) { color in
                        Text(color.displayName).tag(color)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(16)
            .tfDynamicCard(cornerRadius: 16)

            // Advance Button Color Card
            VStack(alignment: .leading, spacing: 10) {
                Text("Advance button color")
                    .appFont(.headline)
                    .foregroundStyle(.white)

                Text("Color of the previous/next card buttons")
                    .appFont(.caption)
                    .foregroundStyle(.white.opacity(0.6))

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 50), spacing: 10)], spacing: 10) {
                    ForEach(AdvanceButtonColor.allCases) { btnColor in
                        Button {
                            cueCardSettings.advanceButtonColor = btnColor
                        } label: {
                            Circle()
                                .fill(btnColor.color)
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Circle()
                                        .stroke(cueCardSettings.advanceButtonColor == btnColor ? .white : .clear, lineWidth: 3)
                                )
                                .overlay(
                                    cueCardSettings.advanceButtonColor == btnColor ?
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(.black.opacity(0.6))
                                    : nil
                                )
                        }
                    }
                }
                .padding(.top, 4)
            }
            .padding(16)
            .tfDynamicCard(cornerRadius: 16)
        }
    }

    // MARK: - Script Display Settings
    
    private var scriptDisplaySettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Display")
                .appFont(.title3, weight: .semibold)
                .foregroundStyle(TFTheme.yellow)
                .padding(.horizontal, 4)
                .padding(.top, 8)
            
            // Font Size Card
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Font size")
                        .appFont(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Text("\(Int(scriptSettings.fontSize)) pt")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(TFTheme.yellow)
                }
                
                Slider(value: $scriptSettings.fontSize, in: 18...48, step: 2)
                    .tint(TFTheme.yellow)
            }
            .padding(16)
            .tfDynamicCard(cornerRadius: 16)
            
            // Line Spacing Card
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Line spacing")
                        .appFont(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Text("\(Int(scriptSettings.lineSpacing)) pt")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(TFTheme.yellow)
                }
                
                Slider(value: $scriptSettings.lineSpacing, in: 4...20, step: 2)
                    .tint(TFTheme.yellow)
            }
            .padding(16)
            .tfDynamicCard(cornerRadius: 16)
            
            // Text Color Card
            VStack(alignment: .leading, spacing: 10) {
                Text("Text color")
                    .appFont(.headline)
                    .foregroundStyle(.white)
                
                Picker("Text color", selection: $scriptSettings.textColor) {
                    ForEach(ScriptTextColor.allCases) { color in
                        Text(color.displayName).tag(color)
                    }
                }
                .pickerStyle(.menu)
            }
            .padding(16)
            .tfDynamicCard(cornerRadius: 16)
        }
    }
    
    // MARK: - Teleprompter Display Settings
    
    private var teleprompterDisplaySettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Display")
                .appFont(.title3, weight: .semibold)
                .foregroundStyle(TFTheme.yellow)
                .padding(.horizontal, 4)
                .padding(.top, 8)
            
            // Font Size Card
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Font size")
                        .appFont(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Text("\(Int(teleprompterSettings.fontSize)) pt")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(TFTheme.yellow)
                }
                
                Slider(value: $teleprompterSettings.fontSize, in: 22...54, step: 2)
                    .tint(TFTheme.yellow)
            }
            .padding(16)
            .tfDynamicCard(cornerRadius: 16)
            
            // Line Spacing Card
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Line spacing")
                        .appFont(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Text("\(Int(teleprompterSettings.lineSpacing)) pt")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(TFTheme.yellow)
                }
                
                Slider(value: $teleprompterSettings.lineSpacing, in: 8...24, step: 2)
                    .tint(TFTheme.yellow)
            }
            .padding(16)
            .tfDynamicCard(cornerRadius: 16)
            
            // Text Color Card
            VStack(alignment: .leading, spacing: 10) {
                Text("Text color")
                    .appFont(.headline)
                    .foregroundStyle(.white)
                
                Picker("Text color", selection: $teleprompterSettings.textColor) {
                    ForEach(StageModeTeleprompterTextColor.allCases) { color in
                        Text(color.displayName).tag(color)
                    }
                }
                .pickerStyle(.menu)
            }
            .padding(16)
            .tfDynamicCard(cornerRadius: 16)
            
            // Scroll Speed Card
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Scroll speed")
                        .appFont(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Text("\(Int(teleprompterSettings.scrollSpeed)) pts/sec")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(TFTheme.yellow)
                }
                
                Slider(value: $teleprompterSettings.scrollSpeed, in: 0...140, step: 5)
                    .tint(TFTheme.yellow)
            }
            .padding(16)
            .tfDynamicCard(cornerRadius: 16)
            
            // Context Window Height Card
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Context window height")
                        .appFont(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Text("\(Int(teleprompterSettings.contextWindowHeight)) pt")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(TFTheme.yellow)
                }
                
                Slider(value: $teleprompterSettings.contextWindowHeight, in: 120...280, step: 10)
                    .tint(TFTheme.yellow)
            }
            .padding(16)
            .tfDynamicCard(cornerRadius: 16)
            
            // Context Window Color Card
            VStack(alignment: .leading, spacing: 10) {
                Text("Context window color")
                    .appFont(.headline)
                    .foregroundStyle(.white)
                
                Picker("Context window color", selection: $teleprompterSettings.contextWindowColor) {
                    ForEach(StageModeContextWindowColor.allCases) { color in
                        Text(color.displayName).tag(color)
                    }
                }
                .pickerStyle(.menu)
            }
            .padding(16)
            .tfDynamicCard(cornerRadius: 16)
            
            // Auto-start Toggle Card
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Auto-start scrolling")
                        .appFont(.headline)
                        .foregroundStyle(.white)
                    
                    Text("Begin scrolling automatically when entering Stage Mode")
                        .appFont(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                
                Spacer()
                
                Toggle("", isOn: $teleprompterSettings.autoStartScrolling)
                    .labelsHidden()
                    .tint(TFTheme.yellow)
            }
            .padding(16)
            .tfDynamicCard(cornerRadius: 16)
        }
    }
    
    // MARK: - Animation Settings
    
    private var animationSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Animations")
                .appFont(.title3, weight: .semibold)
                .foregroundStyle(TFTheme.yellow)
                .padding(.horizontal, 4)
                .padding(.top, 8)
            
            // Enable Animations Toggle Card
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Enable animations")
                        .appFont(.headline)
                        .foregroundStyle(.white)
                    
                    Text("Smooth transitions between cards")
                        .appFont(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                
                Spacer()
                
                Toggle("", isOn: $cueCardSettings.enableAnimations)
                    .labelsHidden()
                    .tint(TFTheme.yellow)
            }
            .padding(16)
            .tfDynamicCard(cornerRadius: 16)
            
            // Transition Style Card
            if cueCardSettings.enableAnimations {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Transition style")
                        .appFont(.headline)
                        .foregroundStyle(.white)
                    
                    Picker("Transition style", selection: $cueCardSettings.transitionStyle) {
                        ForEach(CardTransitionStyle.allCases) { style in
                            Text(style.displayName).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(16)
                .tfDynamicCard(cornerRadius: 16)
            }
        }
    }
    
    // MARK: - Cue Cards Unavailable View
    
    private var cueCardsUnavailableView: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.stack.badge.minus")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.3))
            
            Text("Cue Cards Unavailable")
                .appFont(.title3, weight: .semibold)
                .foregroundStyle(.white)
            
            Text("This setlist is in Traditional mode. Configure custom cue cards in the setlist settings to enable Cue Card mode.")
                .appFont(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

#Preview {
    CueCardSettingsView()
}
