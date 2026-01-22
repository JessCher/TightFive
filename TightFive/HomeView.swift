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
            .tfBackground()
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
                HStack(spacing: 8) {
                    Text("Quick Bit")
                        .font(.title.weight(.bold)) // Increased weight to match the "heavier" look
                }
                .foregroundStyle(.black) // Keep black text for high contrast on Yellow
                .frame(maxWidth: .infinity)
                .padding(.vertical, 35) // Slightly taller to feel like a "Hero" button
                // NEW: Use the dynamic modifier with TFYellow
                .tfDynamicCard(color: Color("TFYellow"), cornerRadius: 20)
            }
            // Add a specialized shadow for the main button to make it "pop" more than the list items
            .shadow(color: Color("TFYellow").opacity(0.15), radius: 12, x: 0, y: 0)
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
        .tfDynamicCard(cornerRadius: 20) // New dynamic generator
    }
}

struct SetlistsPlaceholderView: View {
    var body: some View {
        ZStack {
            ContentUnavailableView("Setlists", systemImage: "list.bullet.rectangle", description: Text("Coming soon."))
                .foregroundStyle(.white)
        }
        .navigationTitle("Setlists")
        .navigationBarTitleDisplayMode(.inline)
        .tfBackground()
    }
}

struct ShowNotesPlaceholderView: View {
    var body: some View {
        ZStack {
            ContentUnavailableView("Show Notes", systemImage: "note.text", description: Text("Coming soon."))
                .foregroundStyle(.white)
        }
        .navigationTitle("Show Notes")
        .navigationBarTitleDisplayMode(.inline)
        .tfBackground()
    }
}
