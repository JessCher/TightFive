import SwiftUI

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                aboutHeaderCard
                appInformationCard
                privacyPolicyCard
                featureHelpCard
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
            AboutRow(label: "Placeholder", value: "Product story and support links coming soon.")
        }
    }

    private var privacyPolicyCard: some View {
        aboutCard(title: "Privacy Policy") {
            Text("Privacy policy placeholder")
                .appFont(.subheadline, weight: .semibold)
                .foregroundStyle(TFTheme.text)

            Text("Add a summary of data collection, storage, and sharing practices here. Include links to your full policy when available.")
                .appFont(.caption)
                .foregroundStyle(TFTheme.text.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var featureHelpCard: some View {
        aboutCard(title: "Feature-Specific Help") {
            featureHelpRow("Bits", "Placeholder: organizing and refining material.")
            featureHelpRow("Notebook", "Placeholder: capturing notes and managing folders.")
            featureHelpRow("Setlists", "Placeholder: building and rehearsing performance flow.")
            featureHelpRow("Run Through", "Placeholder: guided timed practice.")
            featureHelpRow("Show Notes", "Placeholder: post-show review and feedback.")
        }
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
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .appFont(.subheadline, weight: .semibold)
                .foregroundStyle(TFTheme.text)

            Text(text)
                .appFont(.caption)
                .foregroundStyle(TFTheme.text.opacity(0.65))
        }
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
