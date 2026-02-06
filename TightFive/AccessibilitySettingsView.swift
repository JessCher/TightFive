import SwiftUI

/// Accessibility settings for TightFive
struct AccessibilitySettingsView: View {
    @State private var settings = AppSettings.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Reduce Motion
                VStack(alignment: .leading, spacing: 12) {
                    Text("Motion & Animation")
                        .appFont(.title3, weight: .semibold)
                        .foregroundStyle(TFTheme.yellow)
                        .padding(.horizontal, 4)
                        .accessibilityAddTraits(.isHeader)

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Reduce motion")
                                .appFont(.headline)
                                .foregroundStyle(.white)

                            Text("Minimizes animations and transitions throughout the app")
                                .appFont(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .accessibilityElement(children: .combine)

                        Spacer()

                        Toggle("Reduce motion", isOn: $settings.reduceMotion)
                            .labelsHidden()
                            .tint(TFTheme.yellow)
                            .accessibilityLabel("Reduce motion")
                            .accessibilityHint("Minimizes animations and transitions throughout the app")
                    }
                    .padding(16)
                    .tfDynamicCard(cornerRadius: 16)
                    .accessibilityElement(children: .contain)
                }

                // Visual
                VStack(alignment: .leading, spacing: 12) {
                    Text("Visual")
                        .appFont(.title3, weight: .semibold)
                        .foregroundStyle(TFTheme.yellow)
                        .padding(.horizontal, 4)
                        .accessibilityAddTraits(.isHeader)

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("High contrast")
                                .appFont(.headline)
                                .foregroundStyle(.white)

                            Text("Increases contrast for text and UI elements")
                                .appFont(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .accessibilityElement(children: .combine)

                        Spacer()

                        Toggle("High contrast", isOn: $settings.highContrast)
                            .labelsHidden()
                            .tint(TFTheme.yellow)
                            .accessibilityLabel("High contrast")
                            .accessibilityHint("Increases contrast for text and UI elements")
                    }
                    .padding(16)
                    .tfDynamicCard(cornerRadius: 16)
                    .accessibilityElement(children: .contain)

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Bold text")
                                .appFont(.headline)
                                .foregroundStyle(.white)

                            Text("Uses heavier font weight for all text")
                                .appFont(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .accessibilityElement(children: .combine)

                        Spacer()

                        Toggle("Bold text", isOn: $settings.boldText)
                            .labelsHidden()
                            .tint(TFTheme.yellow)
                            .accessibilityLabel("Bold text")
                            .accessibilityHint("Uses heavier font weight for all text")
                    }
                    .padding(16)
                    .tfDynamicCard(cornerRadius: 16)
                    .accessibilityElement(children: .contain)

                    // Text size
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Text size")
                                .appFont(.headline)
                                .foregroundStyle(.white)
                            Spacer()
                            Text("\(Int(settings.appFontSizeMultiplier * 100))%")
                                .font(.headline.monospacedDigit())
                                .foregroundStyle(TFTheme.yellow)
                        }

                        Text("Adjusts text size across the entire app")
                            .appFont(.caption)
                            .foregroundStyle(.white.opacity(0.6))

                        Slider(value: $settings.appFontSizeMultiplier, in: 0.8...1.6, step: 0.05)
                            .tint(TFTheme.yellow)
                            .accessibilityLabel("Text size")
                            .accessibilityValue("\(Int(settings.appFontSizeMultiplier * 100)) percent")
                            .accessibilityHint("Adjusts text size across the entire app")

                        HStack {
                            Text("A")
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.5))
                                .accessibilityHidden(true)
                            Spacer()
                            Text("A")
                                .font(.system(size: 22))
                                .foregroundStyle(.white.opacity(0.5))
                                .accessibilityHidden(true)
                        }
                    }
                    .padding(16)
                    .tfDynamicCard(cornerRadius: 16)
                    .accessibilityElement(children: .contain)
                }

                // Interaction
                VStack(alignment: .leading, spacing: 12) {
                    Text("Interaction")
                        .appFont(.title3, weight: .semibold)
                        .foregroundStyle(TFTheme.yellow)
                        .padding(.horizontal, 4)
                        .accessibilityAddTraits(.isHeader)

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Haptic feedback")
                                .appFont(.headline)
                                .foregroundStyle(.white)

                            Text("Vibration feedback for taps and gestures")
                                .appFont(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .accessibilityElement(children: .combine)

                        Spacer()

                        Toggle("Haptic feedback", isOn: $settings.hapticsEnabled)
                            .labelsHidden()
                            .tint(TFTheme.yellow)
                            .accessibilityLabel("Haptic feedback")
                            .accessibilityHint("Vibration feedback for taps and gestures")
                    }
                    .padding(16)
                    .tfDynamicCard(cornerRadius: 16)
                    .accessibilityElement(children: .contain)

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Larger touch targets")
                                .appFont(.headline)
                                .foregroundStyle(.white)

                            Text("Increases button and control sizes for easier tapping")
                                .appFont(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .accessibilityElement(children: .combine)

                        Spacer()

                        Toggle("Larger touch targets", isOn: $settings.largerTouchTargets)
                            .labelsHidden()
                            .tint(TFTheme.yellow)
                            .accessibilityLabel("Larger touch targets")
                            .accessibilityHint("Increases button and control sizes for easier tapping")
                    }
                    .padding(16)
                    .tfDynamicCard(cornerRadius: 16)
                    .accessibilityElement(children: .contain)
                }

                // Footer
                Text("These settings supplement your system accessibility preferences.")
                    .appFont(.footnote)
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.top, 8)
                    .accessibilityAddTraits(.isStaticText)
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 28)
        }
        .tfBackground()
        .navigationTitle("Accessibility")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                TFWordmarkTitle(title: "Accessibility", size: 20)
            }
        }
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    NavigationStack {
        AccessibilitySettingsView()
    }
}
