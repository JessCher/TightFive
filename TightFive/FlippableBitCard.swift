import SwiftUI
import SwiftData

/// A flippable bit card that shows the bit content on the front and notes on the back.
/// Features a flip button in the bottom right corner that triggers a 3D flip animation.
struct FlippableBitCard<FrontContent: View, BackContent: View>: View {
    @Binding var isFlipped: Bool
    let frontContent: FrontContent
    let backContent: BackContent

    init(
        isFlipped: Binding<Bool>,
        @ViewBuilder front: () -> FrontContent,
        @ViewBuilder back: () -> BackContent
    ) {
        self._isFlipped = isFlipped
        self.frontContent = front()
        self.backContent = back()
    }

    var body: some View {
        ZStack {
            // Front side (bit content)
            frontContent
                .opacity(isFlipped ? 0 : 1)
                .rotation3DEffect(
                    .degrees(isFlipped ? 180 : 0),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.5
                )

            // Back side (notes)
            backContent
                .opacity(isFlipped ? 1 : 0)
                .rotation3DEffect(
                    .degrees(isFlipped ? 0 : -180),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.5
                )
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isFlipped)
    }
}

/// The flip button that appears in the bottom right corner of bit cards
struct BitFlipButton: View {
    let isFlipped: Bool
    let hasNotes: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: isFlipped ? "doc.text" : "note.text")
                    .appFont(.caption)
                if !isFlipped && hasNotes {
                    Circle()
                        .fill(TFTheme.yellow)
                        .frame(width: 6, height: 6)
                }
            }
            .foregroundStyle(TFTheme.yellow)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.4))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(TFTheme.yellow.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Loose Bit Flippable Card

struct LooseFlippableBitCard: View {
    let bit: Bit
    @Binding var isFlipped: Bool
    @Environment(\.modelContext) private var modelContext
    @State private var notesText: String = ""
    @FocusState private var isNotesFocused: Bool

    var body: some View {
        FlippableBitCard(isFlipped: $isFlipped) {
            // Front: Bit content card
            frontCard
        } back: {
            // Back: Notes card
            backCard
        }
        .onAppear {
            notesText = bit.notes
        }
    }

    private var frontCard: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .center, spacing: 8) {
                // Title
                Text(bit.titleLine)
                    .appFont(.title3, weight: .semibold)
                    .foregroundStyle(TFTheme.text)
                    .lineLimit(3)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                // Date - Variations - Favorite row
                HStack(spacing: 8) {
                    Text(bit.updatedAt, style: .date)
                        .appFont(.subheadline)
                        .foregroundStyle(TFTheme.text.opacity(0.55))

                    if bit.variationCount > 0 {
                        Text("\u{2022}")
                            .appFont(.subheadline)
                            .foregroundStyle(TFTheme.text.opacity(0.4))

                        Text("\(bit.variationCount) variation\(bit.variationCount == 1 ? "" : "s")")
                            .appFont(.subheadline)
                            .foregroundStyle(TFTheme.text.opacity(0.55))
                    }

                    if bit.isFavorite {
                        Text("\u{2022}")
                            .appFont(.subheadline)
                            .foregroundStyle(TFTheme.text.opacity(0.4))

                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .appFont(.caption)
                                .foregroundStyle(TFTheme.yellow)
                            Text("Favorite")
                                .appFont(.subheadline)
                                .foregroundStyle(TFTheme.text.opacity(0.55))
                        }
                    }
                }

                // Tags row
                if !bit.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(bit.tags, id: \.self) { tag in
                                Text(tag)
                                    .appFont(.caption2, weight: .medium)
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(TFTheme.yellow.opacity(0.9))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                // Spacer for flip button
                Spacer().frame(height: 24)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .tfDynamicCard(cornerRadius: 18)

            // Flip button
            BitFlipButton(isFlipped: false, hasNotes: !bit.notes.isEmpty) {
                withAnimation {
                    isFlipped = true
                }
            }
            .padding(.trailing, 12)
            .padding(.bottom, 12)
        }
    }

    private var backCard: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Image(systemName: "note.text")
                        .appFont(.headline)
                        .foregroundStyle(TFTheme.yellow)
                    Text("Notes")
                        .appFont(.headline, weight: .semibold)
                        .foregroundStyle(TFTheme.text)
                    Spacer()
                }

                // Notes description
                Text("Variant punchlines, alternate wording, delivery ideas...")
                    .appFont(.caption)
                    .foregroundStyle(TFTheme.text.opacity(0.5))

                // Notes text editor
                ZStack(alignment: .topLeading) {
                    if notesText.isEmpty && !isNotesFocused {
                        Text("Tap to add notes...")
                            .appFont(.body)
                            .foregroundStyle(TFTheme.text.opacity(0.35))
                            .padding(.top, 8)
                            .padding(.leading, 4)
                    }

                    TextEditor(text: $notesText)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .appFont(.body)
                        .foregroundStyle(TFTheme.text)
                        .focused($isNotesFocused)
                        .frame(minHeight: 80)
                        .onChange(of: notesText) { _, newValue in
                            bit.notes = newValue
                            bit.updatedAt = Date()
                            try? modelContext.save()
                        }
                }
                .padding(8)
                .background(Color.black.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                // Spacer for flip button
                Spacer().frame(height: 24)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .tfDynamicCard(cornerRadius: 18)

            // Flip button (back to front)
            BitFlipButton(isFlipped: true, hasNotes: !bit.notes.isEmpty) {
                isNotesFocused = false
                withAnimation {
                    isFlipped = false
                }
            }
            .padding(.trailing, 12)
            .padding(.bottom, 12)
        }
    }
}

// MARK: - Finished Bit Flippable Card

struct FinishedFlippableBitCard: View {
    let bit: Bit
    @Binding var isFlipped: Bool
    @Environment(\.modelContext) private var modelContext
    @State private var notesText: String = ""
    @FocusState private var isNotesFocused: Bool

    var body: some View {
        FlippableBitCard(isFlipped: $isFlipped) {
            // Front: Bit content card
            frontCard
        } back: {
            // Back: Notes card
            backCard
        }
        .onAppear {
            notesText = bit.notes
        }
    }

    private var frontCard: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .center, spacing: 8) {
                // Title
                Text(bit.titleLine)
                    .appFont(.title3, weight: .semibold)
                    .foregroundStyle(TFTheme.text)
                    .lineLimit(3)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                // Estimated duration row
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .appFont(.caption)
                        .foregroundStyle(TFTheme.yellow)
                    Text(bit.formattedDuration)
                        .appFont(.subheadline)
                        .foregroundStyle(TFTheme.text.opacity(0.7))
                }
                .frame(maxWidth: .infinity, alignment: .center)

                // Date - Variations - Favorite row
                HStack(spacing: 8) {
                    Text(bit.updatedAt, style: .date)
                        .appFont(.subheadline)
                        .foregroundStyle(TFTheme.text.opacity(0.55))

                    if bit.variationCount > 0 {
                        Text("\u{2022}")
                            .appFont(.subheadline)
                            .foregroundStyle(TFTheme.text.opacity(0.4))

                        Text("\(bit.variationCount) variation\(bit.variationCount == 1 ? "" : "s")")
                            .appFont(.subheadline)
                            .foregroundStyle(TFTheme.text.opacity(0.55))
                    }

                    if bit.isFavorite {
                        Text("\u{2022}")
                            .appFont(.subheadline)
                            .foregroundStyle(TFTheme.text.opacity(0.4))

                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .appFont(.caption)
                                .foregroundStyle(TFTheme.yellow)
                            Text("Favorite")
                                .appFont(.subheadline)
                                .foregroundStyle(TFTheme.text.opacity(0.55))
                        }
                    }
                }

                // Tags row
                if !bit.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(bit.tags, id: \.self) { tag in
                                Text(tag)
                                    .appFont(.caption2, weight: .medium)
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(TFTheme.yellow.opacity(0.9))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                // Spacer for flip button
                Spacer().frame(height: 24)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .tfDynamicCard(cornerRadius: 18)

            // Flip button
            BitFlipButton(isFlipped: false, hasNotes: !bit.notes.isEmpty) {
                withAnimation {
                    isFlipped = true
                }
            }
            .padding(.trailing, 12)
            .padding(.bottom, 12)
        }
    }

    private var backCard: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Image(systemName: "note.text")
                        .appFont(.headline)
                        .foregroundStyle(TFTheme.yellow)
                    Text("Notes")
                        .appFont(.headline, weight: .semibold)
                        .foregroundStyle(TFTheme.text)
                    Spacer()
                }

                // Notes description
                Text("Variant punchlines, alternate wording, delivery ideas...")
                    .appFont(.caption)
                    .foregroundStyle(TFTheme.text.opacity(0.5))

                // Notes text editor
                ZStack(alignment: .topLeading) {
                    if notesText.isEmpty && !isNotesFocused {
                        Text("Tap to add notes...")
                            .appFont(.body)
                            .foregroundStyle(TFTheme.text.opacity(0.35))
                            .padding(.top, 8)
                            .padding(.leading, 4)
                    }

                    TextEditor(text: $notesText)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .appFont(.body)
                        .foregroundStyle(TFTheme.text)
                        .focused($isNotesFocused)
                        .frame(minHeight: 80)
                        .onChange(of: notesText) { _, newValue in
                            bit.notes = newValue
                            bit.updatedAt = Date()
                            try? modelContext.save()
                        }
                }
                .padding(8)
                .background(Color.black.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                // Spacer for flip button
                Spacer().frame(height: 24)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .tfDynamicCard(cornerRadius: 18)

            // Flip button (back to front)
            BitFlipButton(isFlipped: true, hasNotes: !bit.notes.isEmpty) {
                isNotesFocused = false
                withAnimation {
                    isFlipped = false
                }
            }
            .padding(.trailing, 12)
            .padding(.bottom, 12)
        }
    }
}
