import SwiftUI

struct RunModeSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settings = RunModeSettingsStore.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // General Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("General")
                            .appFont(.title3, weight: .semibold)
                            .foregroundStyle(TFTheme.yellow)
                            .padding(.horizontal, 4)
                        
                        // Default Mode Picker Card
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Default Mode")
                                .appFont(.headline)
                                .foregroundStyle(.white)
                            
                            Picker("Default Mode", selection: $settings.defaultMode) {
                                ForEach(RunModeDefaultMode.allCases) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        .padding(16)
                        .tfDynamicCard(cornerRadius: 16)
                        
                        // Auto Start Timer Card
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Start timer automatically")
                                    .appFont(.headline)
                                    .foregroundStyle(.white)
                                
                                Text("Timer begins when you enter Run Mode")
                                    .appFont(.caption)
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: $settings.autoStartTimer)
                                .labelsHidden()
                                .tint(TFTheme.yellow)
                        }
                        .padding(16)
                        .tfDynamicCard(cornerRadius: 16)
                        
                        // Auto Start Teleprompter Card
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Start teleprompter automatically")
                                    .appFont(.headline)
                                    .foregroundStyle(.white)
                                
                                Text("Scrolling begins immediately in Teleprompter mode")
                                    .appFont(.caption)
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: $settings.autoStartTeleprompter)
                                .labelsHidden()
                                .tint(TFTheme.yellow)
                        }
                        .padding(16)
                        .tfDynamicCard(cornerRadius: 16)
                    }
                    
                    // Teleprompter Defaults Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Teleprompter Defaults")
                            .appFont(.title3, weight: .semibold)
                            .foregroundStyle(TFTheme.yellow)
                            .padding(.horizontal, 4)
                            .padding(.top, 8)
                        
                        // Font Size Card
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Default font size")
                                    .appFont(.headline)
                                    .foregroundStyle(.white)
                                Spacer()
                                Text("\(Int(settings.defaultFontSize)) pt")
                                    .font(.headline.monospacedDigit())
                                    .foregroundStyle(TFTheme.yellow)
                            }
                            
                            Slider(value: $settings.defaultFontSize, in: 22...54, step: 1)
                                .tint(TFTheme.yellow)
                        }
                        .padding(16)
                        .tfDynamicCard(cornerRadius: 16)
                        
                        // Speed Card
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Default speed")
                                    .appFont(.headline)
                                    .foregroundStyle(.white)
                                Spacer()
                                Text("\(Int(settings.defaultSpeed)) pts/sec")
                                    .font(.headline.monospacedDigit())
                                    .foregroundStyle(TFTheme.yellow)
                            }
                            
                            Slider(value: $settings.defaultSpeed, in: 0...140, step: 1)
                                .tint(TFTheme.yellow)
                        }
                        .padding(16)
                        .tfDynamicCard(cornerRadius: 16)
                        
                        // Teleprompter Font Color Card
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Teleprompter font color")
                                .appFont(.headline)
                                .foregroundStyle(.white)
                            
                            Picker("Teleprompter font color", selection: $settings.teleprompterFontColor) {
                                ForEach(TeleprompterFontColor.allCases) { c in
                                    Text(c.rawValue.capitalized).tag(c)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        .padding(16)
                        .tfDynamicCard(cornerRadius: 16)
                        
                        // Context Window Color Card
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Margin Color")
                                .appFont(.headline)
                                .foregroundStyle(.white)
                            
                            Picker("Context window color", selection: $settings.contextWindowColor) {
                                ForEach(ContextWindowColor.allCases) { c in
                                    Text(c.rawValue.capitalized).tag(c)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        .padding(16)
                        .tfDynamicCard(cornerRadius: 16)
                    }
                    
                    // Script Defaults Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Script Defaults")
                            .appFont(.title3, weight: .semibold)
                            .foregroundStyle(TFTheme.yellow)
                            .padding(.horizontal, 4)
                            .padding(.top, 8)
                        
                        // Script Font Color Card
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Script font color")
                                .appFont(.headline)
                                .foregroundStyle(.white)
                            
                            Picker("Script font color", selection: $settings.scriptFontColor) {
                                ForEach(TeleprompterFontColor.allCases) { c in
                                    Text(c.rawValue.capitalized).tag(c)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        .padding(16)
                        .tfDynamicCard(cornerRadius: 16)
                    }
                    
                    // Timer Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Timer")
                            .appFont(.title3, weight: .semibold)
                            .foregroundStyle(TFTheme.yellow)
                            .padding(.horizontal, 4)
                            .padding(.top, 8)
                        
                        // Timer Color Card
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Timer color")
                                .appFont(.headline)
                                .foregroundStyle(.white)
                            
                            Picker("Timer color", selection: $settings.timerColor) {
                                ForEach(TimerColor.allCases) { c in
                                    Text(c.rawValue.capitalized).tag(c)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        .padding(16)
                        .tfDynamicCard(cornerRadius: 16)
                        
                        // Timer Size Card
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Timer size")
                                    .appFont(.headline)
                                    .foregroundStyle(.white)
                                Spacer()
                                Text("\(Int(settings.timerSize)) pt")
                                    .font(.headline.monospacedDigit())
                                    .foregroundStyle(TFTheme.yellow)
                            }
                            
                            Slider(value: $settings.timerSize, in: 20...48, step: 1)
                                .tint(TFTheme.yellow)
                        }
                        .padding(16)
                        .tfDynamicCard(cornerRadius: 16)
                    }
                    
                    // Footer
                    Text("Make it yours")
                        .appFont(.footnote)
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.top, 8)
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
            .tfBackground()
            .navigationTitle("Run Mode Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    TFWordmarkTitle(title: "Run Mode Settings", size: 20)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(TFTheme.yellow)
                }
            }
        }
    }
}

#Preview {
    RunModeSettingsView()
}
