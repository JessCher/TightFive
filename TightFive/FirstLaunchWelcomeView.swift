import SwiftUI

struct FirstLaunchWelcomeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showAbout = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    TightFiveWordmark(size: 28)

                    Text("Welcome to \(AppMetadata.appName)")
                        .appFont(.title2, weight: .bold)
                        .foregroundStyle(TFTheme.text)

                    Text("Build better material faster with one place for notes, sets, and post-show feedback.")
                        .appFont(.subheadline)
                        .foregroundStyle(TFTheme.text.opacity(0.65))
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 10) {
                    welcomeBullet("Capture ideas quickly with Notebook and Quick Bit.")
                    welcomeBullet("Shape your act in Setlists and rehearse in Run Through.")
                    welcomeBullet("Track progress over time using Show Notes.")
                }

                Spacer(minLength: 0)

                VStack(spacing: 10) {
                    Button {
                        showAbout = true
                    } label: {
                        Text("Learn more in About")
                            .appFont(.headline, weight: .semibold)
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(TFTheme.yellow)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    Button {
                        dismiss()
                    } label: {
                        Text("Get Started")
                            .appFont(.subheadline, weight: .semibold)
                            .foregroundStyle(TFTheme.text)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color("TFCardStroke").opacity(0.9), lineWidth: 1)
                            )
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
            .navigationTitle("Welcome")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundStyle(TFTheme.yellow)
                }
            }
            .tfBackground()
        }
        .sheet(isPresented: $showAbout) {
            NavigationStack {
                AboutView()
            }
        }
    }

    private func welcomeBullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(TFTheme.yellow)
                .padding(.top, 2)

            Text(text)
                .appFont(.subheadline)
                .foregroundStyle(TFTheme.text)
        }
    }
}

#Preview {
    FirstLaunchWelcomeView()
}
