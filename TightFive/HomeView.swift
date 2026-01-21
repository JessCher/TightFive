import SwiftUI

struct HomeView: View {
    @State private var showQuickBit = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    quickBitButton

                    VStack(spacing: 14) {
                        NavigationLink {
                            LooseBitsView(mode: .loose)
                        } label: {
                            HomeTile(title: "Loose Bits",
                                     subtitle: "Save joke ideas for later…",
                                     iconName: "IconLooseBits")
                        }

                        NavigationLink {
                            LooseBitsView(mode: .finished)
                        } label: {
                            HomeTile(title: "Finished Bits",
                                     subtitle: "Refine your best stuff.",
                                     iconName: "IconFinishedBits")
                        }

                        NavigationLink {
                            SetlistsView()
                        } label: {
                            HomeTile(title: "Setlists",
                                     subtitle: "Build and run tight sets.",
                                     iconName: "IconSetlists")
                        }

                        NavigationLink {
                            ShowNotesPlaceholderView()
                        } label: {
                            HomeTile(title: "Show Notes",
                                     subtitle: "Reflect on how shows went.",
                                     iconName: "IconShowNotes")
                        }
                    }

                    Spacer(minLength: 26)
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
            .background(TFChalkboardBackground().ignoresSafeArea()) // ✅ DOES NOT AFFECT LAYOUT
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                            ToolbarItem(placement: .principal) {
                                HStack(spacing: 8) {
                                    Image("IconLogo")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 50, height: 50)

                                    TightFiveWordmark(size: 22)
                                }
                                .offset(x: -15)
                            }

                            ToolbarItem(placement: .topBarTrailing) {
                                Button {
                                    showQuickBit = true
                                } label: {
                                    Image(systemName: "plus")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(Color("TFYellow"))
                                        .frame(width: 40, height: 40)
                                        .background(Color.white.opacity(0.0))
                                }
                    .accessibilityLabel("New Bit")
                }
            }
            .sheet(isPresented: $showQuickBit) {
                QuickBitEditor()
                    .presentationDetents([.medium, .large])
            }
        }
    }

    private var quickBitButton: some View {
        Button {
            showQuickBit = true
        } label: {
            Text("Quick Bit")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(Color("TFYellow"))
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.45), radius: 14, x: 0, y: 10)
        }
    }
}

// MARK: - Tile

private struct HomeTile: View {
    let title: String
    let subtitle: String
    let iconName: String

    var body: some View {
        HStack(spacing: 14) {
            Image(iconName)
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.62))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.28))
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 16)
        .tfTexturedCard(cornerRadius: 20)
    }
}

// MARK: - Placeholders (same styling)

private struct SetlistsPlaceholderView: View {
    var body: some View {
        ZStack {
            TFChalkboardBackground().ignoresSafeArea()
            ContentUnavailableView("Setlists", systemImage: "list.bullet.rectangle", description: Text("Coming soon."))
                .foregroundStyle(.white)
        }
        .navigationTitle("Setlists")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ShowNotesPlaceholderView: View {
    var body: some View {
        ZStack {
            TFChalkboardBackground().ignoresSafeArea()
            ContentUnavailableView("Show Notes", systemImage: "note.text", description: Text("Coming soon."))
                .foregroundStyle(.white)
        }
        .navigationTitle("Show Notes")
        .navigationBarTitleDisplayMode(.inline)
    }
}
