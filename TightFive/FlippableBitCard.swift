import SwiftUI
import SwiftData

// MARK: - Keyboard Dismissal Extensions

extension View {
    /// Dismiss keyboard when user taps outside text fields
    func dismissKeyboardOnTap() -> some View {
        self.onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
    
    /// Dismiss keyboard when user drags/scrolls
    func dismissKeyboardOnDrag() -> some View {
        self.simultaneousGesture(
            DragGesture().onChanged { _ in
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        )
    }
}

// MARK: - Flippable Bit Card

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
            frontContent
                .opacity(isFlipped ? 0 : 1)
                .rotation3DEffect(
                    .degrees(isFlipped ? 180 : 0),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.5
                )
                .frame(maxHeight: isFlipped ? 0 : nil)
                .clipped()
            
            backContent
                .opacity(isFlipped ? 1 : 0)
                .rotation3DEffect(
                    .degrees(isFlipped ? 0 : -180),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.5
                )
                .frame(maxHeight: isFlipped ? nil : 0)
                .clipped()
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

// MARK: - Loose Bit Flippable Card (List View)

struct LooseFlippableBitCard: View {
    let bit: Bit
    @Binding var isFlipped: Bool
    var onTextFieldFocus: ((UUID) -> Void)?
    @Environment(\.modelContext) private var modelContext
    @State private var notesText: String = ""
    @FocusState private var isNotesFocused: Bool
    
    // Create a unique ID for the text editor to enable precise scrolling
    private var textEditorID: UUID {
        UUID(uuidString: bit.id.uuidString.replacingOccurrences(of: "-", with: "").prefix(8) + "-1111-1111-1111-" + bit.id.uuidString.suffix(12))!
    }

    var body: some View {
        FlippableBitCard(isFlipped: $isFlipped) {
            frontCard
        } back: {
            backCard
        }
        .onAppear {
            notesText = bit.notes
        }
    }

    private var frontCard: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .center, spacing: 8) {
                Text(bit.titleLine)
                    .appFont(.title3, weight: .semibold)
                    .foregroundStyle(TFTheme.text)
                    .lineLimit(3)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

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
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .tfDynamicCard(cornerRadius: 18)

            BitFlipButton(isFlipped: false, hasNotes: !bit.notes.isEmpty) {
                withAnimation { isFlipped = true }
            }
            .padding(.trailing, 12)
            .padding(.bottom, 12)
        }
    }

    private var backCard: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "note.text")
                        .appFont(.subheadline)
                        .foregroundStyle(TFTheme.yellow)
                    Text("Notes")
                        .appFont(.subheadline, weight: .semibold)
                        .foregroundStyle(TFTheme.text)
                    Spacer()
                }

                ZStack(alignment: .topLeading) {
                    if notesText.isEmpty && !isNotesFocused {
                        Text("Tap to add notes...")
                            .appFont(.caption)
                            .foregroundStyle(TFTheme.text.opacity(0.35))
                            .padding(.top, 6)
                            .padding(.leading, 4)
                    }

                    TextEditor(text: $notesText)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .appFont(.caption)
                        .foregroundStyle(TFTheme.text)
                        .focused($isNotesFocused)
                        .onChange(of: notesText) { _, newValue in
                            bit.notes = newValue
                            bit.updatedAt = Date()
                            try? modelContext.save()
                        }
                        .onChange(of: isNotesFocused) { oldValue, newValue in
                            if newValue {
                                // Delay to allow keyboard animation to start
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    onTextFieldFocus?(textEditorID)
                                }
                            }
                        }
                }
                .id(textEditorID)
                .frame(height: 120) // Fixed height - text scrolls inside
                .padding(6)
                .background(Color.black.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .tfDynamicCard(cornerRadius: 18)

            BitFlipButton(isFlipped: true, hasNotes: !bit.notes.isEmpty) {
                isNotesFocused = false
                withAnimation { isFlipped = false }
            }
            .padding(.trailing, 12)
            .padding(.bottom, 12)
        }
    }
}

// MARK: - Finished Bit Flippable Card (List View)

struct FinishedFlippableBitCard: View {
    let bit: Bit
    @Binding var isFlipped: Bool
    var onTextFieldFocus: ((UUID) -> Void)?
    @Environment(\.modelContext) private var modelContext
    @State private var notesText: String = ""
    @FocusState private var isNotesFocused: Bool
    
    // Create a unique ID for the text editor to enable precise scrolling
    private var textEditorID: UUID {
        UUID(uuidString: bit.id.uuidString.replacingOccurrences(of: "-", with: "").prefix(8) + "-2222-2222-2222-" + bit.id.uuidString.suffix(12))!
    }

    var body: some View {
        FlippableBitCard(isFlipped: $isFlipped) {
            frontCard
        } back: {
            backCard
        }
        .onAppear {
            notesText = bit.notes
        }
    }

    private var frontCard: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .center, spacing: 8) {
                Text(bit.titleLine)
                    .appFont(.title3, weight: .semibold)
                    .foregroundStyle(TFTheme.text)
                    .lineLimit(3)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .appFont(.caption)
                        .foregroundStyle(TFTheme.yellow)
                    Text(bit.formattedDuration)
                        .appFont(.subheadline)
                        .foregroundStyle(TFTheme.text.opacity(0.7))
                }
                .frame(maxWidth: .infinity, alignment: .center)

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
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .tfDynamicCard(cornerRadius: 18)

            BitFlipButton(isFlipped: false, hasNotes: !bit.notes.isEmpty) {
                withAnimation { isFlipped = true }
            }
            .padding(.trailing, 12)
            .padding(.bottom, 12)
        }
    }

    private var backCard: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "note.text")
                        .appFont(.subheadline)
                        .foregroundStyle(TFTheme.yellow)
                    Text("Notes")
                        .appFont(.subheadline, weight: .semibold)
                        .foregroundStyle(TFTheme.text)
                    Spacer()
                }

                ZStack(alignment: .topLeading) {
                    if notesText.isEmpty && !isNotesFocused {
                        Text("Tap to add notes...")
                            .appFont(.caption)
                            .foregroundStyle(TFTheme.text.opacity(0.35))
                            .padding(.top, 6)
                            .padding(.leading, 4)
                    }

                    TextEditor(text: $notesText)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .appFont(.caption)
                        .foregroundStyle(TFTheme.text)
                        .focused($isNotesFocused)
                        .onChange(of: notesText) { _, newValue in
                            bit.notes = newValue
                            bit.updatedAt = Date()
                            try? modelContext.save()
                        }
                        .onChange(of: isNotesFocused) { oldValue, newValue in
                            if newValue {
                                // Delay to allow keyboard animation to start
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    onTextFieldFocus?(textEditorID)
                                }
                            }
                        }
                }
                .id(textEditorID)
                .frame(height: 120) // Fixed height - text scrolls inside
                .padding(6)
                .background(Color.black.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .tfDynamicCard(cornerRadius: 18)

            BitFlipButton(isFlipped: true, hasNotes: !bit.notes.isEmpty) {
                isNotesFocused = false
                withAnimation { isFlipped = false }
            }
            .padding(.trailing, 12)
            .padding(.bottom, 12)
        }
    }
}

// MARK: - Detail View Flippable Card

/// Flippable card for the Finished Bit Detail View - editable text on front, notes on back
struct FinishedDetailFlippableCard: View {
    @Bindable var bit: Bit
    @Binding var isFlipped: Bool
    @Environment(\.modelContext) private var modelContext
    @State private var notesText: String = ""
    @FocusState private var isNotesFocused: Bool

    var body: some View {
        FlippableBitCard(isFlipped: $isFlipped) {
            frontCard
        } back: {
            backCard
        }
        .onAppear {
            notesText = bit.notes
        }
    }

    private var frontCard: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 16) {
                TextField("Title", text: Binding(
                    get: { bit.title },
                    set: { newValue in
                        bit.title = newValue
                        bit.updatedAt = Date()
                        try? modelContext.save()
                    }
                ))
                .appFont(.title2, weight: .bold)
                .foregroundStyle(TFTheme.yellow)
                .multilineTextAlignment(.center)
                .submitLabel(.done)
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)

                Divider()
                    .background(.white.opacity(0.2))

                ZStack(alignment: .topLeading) {
                    if bit.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Body")
                            .appFont(.body)
                            .foregroundStyle(TFTheme.text.opacity(0.35))
                            .padding(.top, 8)
                    }
                    TextEditor(text: Binding(
                        get: { bit.text },
                        set: { newValue in
                            bit.text = newValue
                            bit.updatedAt = Date()
                            try? modelContext.save()
                        }
                    ))
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .appFont(.body)
                    .foregroundStyle(TFTheme.text)
                    .frame(minHeight: 140)
                }

                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .appFont(.subheadline)
                        .foregroundStyle(TFTheme.yellow)
                    Text("Estimated: \(bit.formattedDuration)")
                        .appFont(.subheadline)
                        .foregroundStyle(TFTheme.text.opacity(0.7))
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(20)
            .tfDynamicCard(cornerRadius: 20)

            BitFlipButton(isFlipped: false, hasNotes: !bit.notes.isEmpty) {
                withAnimation { isFlipped = true }
            }
            .padding(.trailing, 16)
            .padding(.bottom, 16)
        }
    }

    private var backCard: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "note.text")
                        .appFont(.headline)
                        .foregroundStyle(TFTheme.yellow)
                    Text("Notes")
                        .appFont(.headline, weight: .semibold)
                        .foregroundStyle(TFTheme.text)
                    Spacer()
                }

                Text("Variant punchlines, alternate wording, delivery ideas...")
                    .appFont(.caption)
                    .foregroundStyle(TFTheme.text.opacity(0.5))

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
                        .onChange(of: notesText) { _, newValue in
                            bit.notes = newValue
                            bit.updatedAt = Date()
                            try? modelContext.save()
                        }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(8)
                .background(Color.black.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(20)
            .tfDynamicCard(cornerRadius: 20)

            BitFlipButton(isFlipped: true, hasNotes: !bit.notes.isEmpty) {
                isNotesFocused = false
                withAnimation { isFlipped = false }
            }
            .padding(.trailing, 16)
            .padding(.bottom, 16)
        }
    }
}
