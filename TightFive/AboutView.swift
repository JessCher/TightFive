import SwiftUI

struct AboutView: View {
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                aboutHeaderCard
                featureHelpCard
                privacyPolicyCard
                appInformationCard
                
                
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 28)
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                TFWordmarkTitle(title: "About", size: 22)
            }
        }
        .tfBackground()
    }
    private var featureHelpCard: some View {
        aboutCard(title: "Feature-Specific Help") {
            ForEach(Feature.allFeatures) { feature in
                NavigationLink {
                    FeatureHelpDetailView(feature: feature)
                } label: {
                    featureHelpRow(feature.name, feature.shortDescription)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var aboutHeaderCard: some View {
        VStack(spacing: 8) {
            TightFiveWordmark(size: 20)

            Text("Version \(AppMetadata.version) (\(AppMetadata.build))")
                .appFont(.subheadline, weight: .semibold)
                .foregroundStyle(TFTheme.text)

            Text("Build information placeholder")
                .appFont(.caption)
                .foregroundStyle(TFTheme.text.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .tfDynamicCard(cornerRadius: 18)
    }

    private var appInformationCard: some View {
        aboutCard(title: "App Information") {
            AboutRow(label: "App Name", value: AppMetadata.appName)
            AboutRow(label: "Bundle Version", value: "\(AppMetadata.version) (\(AppMetadata.build))")
        }
    }

    private var privacyPolicyCard: some View {
        Button {
            if let url = URL(string: "https://jesscher.github.io/TightFive/privacy-policy.html") {
                openURL(url)
            }
        } label: {
            aboutCard(title: "Privacy Policy") {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("TightFive does not collect, share, or sell any personal data for any users. We do not track any usage activity or have access to any material that you create. Everything you do on this app is contained completely on your personal device and belongs to you. To view the full privacy policy for TightFive, please click the link.")
                            .appFont(.caption)
                            .foregroundStyle(TFTheme.text.opacity(0.65))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "arrow.up.right.square")
                        .font(.title3)
                        .foregroundStyle(TFTheme.yellow.opacity(0.8))
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func aboutCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .appFont(.headline, weight: .semibold)
                .foregroundStyle(TFTheme.yellow)

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .tfDynamicCard(cornerRadius: 18)
    }

    private func featureHelpRow(_ title: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .appFont(.subheadline, weight: .semibold)
                    .foregroundStyle(TFTheme.text)

                Text(text)
                    .appFont(.caption)
                    .foregroundStyle(TFTheme.text.opacity(0.65))
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(TFTheme.text.opacity(0.4))
        }
        .contentShape(Rectangle())
    }
}

private struct AboutRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .appFont(.caption, weight: .semibold)
                .foregroundStyle(TFTheme.text.opacity(0.70))
                .frame(width: 120, alignment: .leading)

            Text(value)
                .appFont(.caption)
                .foregroundStyle(TFTheme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
}
