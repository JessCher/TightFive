import SwiftUI

struct RunModeSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var settings = RunModeSettingsStore.shared

    var body: some View {
        NavigationStack {
            Form {
                Section("General") {
                    Picker("Default Mode", selection: $settings.defaultMode) {
                        ForEach(RunModeDefaultMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    Toggle("Start timer automatically", isOn: $settings.autoStartTimer)
                    Toggle("Start teleprompter automatically", isOn: $settings.autoStartTeleprompter)
                }

                Section("Teleprompter Defaults") {
                    Stepper(value: $settings.defaultFontSize, in: 22...54, step: 1) {
                        Text("Default font size: \(Int(settings.defaultFontSize)) pt")
                    }
                    Stepper(value: $settings.defaultSpeed, in: 0...140, step: 1) {
                        Text("Default speed: \(Int(settings.defaultSpeed)) pts/sec")
                    }
                    Picker("Teleprompter font color", selection: $settings.teleprompterFontColor) {
                        ForEach(TeleprompterFontColor.allCases) { c in
                            Text(c.rawValue.capitalized).tag(c)
                        }
                    }
                    Picker("Context window color", selection: $settings.contextWindowColor) {
                        ForEach(ContextWindowColor.allCases) { c in
                            Text(c.rawValue.capitalized).tag(c)
                        }
                    }
                }

                Section("Script Defaults") {
                    Picker("Script font color", selection: $settings.scriptFontColor) {
                        ForEach(TeleprompterFontColor.allCases) { c in
                            Text(c.rawValue.capitalized).tag(c)
                        }
                    }
                }

                Section("Timer") {
                    Picker("Timer color", selection: $settings.timerColor) {
                        ForEach(TimerColor.allCases) { c in
                            Text(c.rawValue.capitalized).tag(c)
                        }
                    }
                    Stepper(value: $settings.timerSize, in: 20...48, step: 1) {
                        Text("Timer size: \(Int(settings.timerSize)) pt")
                    }
                }

                Section {
                    Text("More settings coming soon…")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Run Mode Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    RunModeSettingsView()
}
