import SwiftUI
import Foundation
import SwiftData
import Combine

/// View for managing loose (work-in-progress) bits only.
/// For finished bits, see FinishedBitsView.
struct LooseBitsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Bit> { bit in
        !bit.isDeleted && bit.statusRaw == "loose"
    }, sort: \Bit.updatedAt, order: .reverse) private var looseBits: [Bit]

    @State private var query: String = ""
    @State private var showQuickBit = false
    @State private var selectedBit: Bit?
    @State private var flippedBitIds: Set<UUID> = []
    @State private var activeTextFieldID: UUID?
    @State private var sortCriteria: BitSortCriteria = .dateCreated
    @State private var sortAscending: Bool = false // false = descending (newest/longest first)
    
    private enum BitSortCriteria: String, CaseIterable, Identifiable {
        case dateModified = "Date Modified"
        case dateCreated = "Date Created"
        case length = "Length"
        
        var id: String { rawValue }
        
        var systemImage: String {
            switch self {
            case .dateModified:
                return "calendar.badge.clock"
            case .dateCreated:
                return "calendar.badge.plus"
            case .length:
                return "text.alignleft"
            }
        }
    }

    /// Apply search filter and sorting to loose bits
    private var filtered: [Bit] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let searchFiltered = q.isEmpty ? looseBits : looseBits.filter { bit in
            bit.text.localizedCaseInsensitiveContains(q)
            || bit.title.localizedCaseInsensitiveContains(q)
            || bit.tags.contains(where: { $0.localizedCaseInsensitiveContains(q) })
        }
        
        // Apply sorting
        return searchFiltered.sorted { bit1, bit2 in
            let comparison: Bool
            switch sortCriteria {
            case .dateModified:
                comparison = bit1.updatedAt < bit2.updatedAt
            case .dateCreated:
                comparison = bit1.createdAt < bit2.createdAt
            case .length:
                comparison = wordCount(for: bit1) < wordCount(for: bit2)
            }
            return sortAscending ? comparison : !comparison
        }
    }
    
    private func wordCount(for bit: Bit) -> Int {
        bit.text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 12) {
                    // Sort button
                    HStack {
                        Spacer()
                        Menu {
                            // Sort criteria section
                            Section("Sort By") {
                                ForEach(BitSortCriteria.allCases) { criteria in
                                    Button {
                                        sortCriteria = criteria
                                    } label: {
                                        HStack {
                                            Image(systemName: criteria.systemImage)
                                            Text(criteria.rawValue)
                                            Spacer()
                                            if sortCriteria == criteria {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            }
                            
                            // Direction section
                            Section("Order") {
                                Button {
                                    sortAscending = false
                                } label: {
                                    HStack {
                                        Image(systemName: "arrow.down")
                                        Text(sortDirectionLabel(descending: true))
                                        Spacer()
                                        if !sortAscending {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                                
                                Button {
                                    sortAscending = true
                                } label: {
                                    HStack {
                                        Image(systemName: "arrow.up")
                                        Text(sortDirectionLabel(descending: false))
                                        Spacer()
                                        if sortAscending {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: sortAscending ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(TFTheme.yellow)
                                .frame(width: 44, height: 32)
                                .background(Color.white.opacity(0.10))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color("TFCardStroke").opacity(0.9), lineWidth: 1)
                                )
                        }
                    }
                    .padding(.horizontal, 2)
                    
                    if filtered.isEmpty {
                        emptyState
                            .padding(.top, 40)
                    } else {
                        ForEach(filtered) { bit in
                            let isFlipped = Binding(
                                get: { flippedBitIds.contains(bit.id) },
                                set: { newValue in
                                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                        if newValue {
                                            flippedBitIds.insert(bit.id)
                                        } else {
                                            flippedBitIds.remove(bit.id)
                                        }
                                    }
                                    
                                    // Scroll to the flipped card after a brief delay
                                    if newValue {
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                            withAnimation(.easeInOut(duration: 0.4)) {
                                                proxy.scrollTo(bit.id, anchor: .top)
                                            }
                                        }
                                    }
                                }
                            )

                            BitSwipeView(
                                bit: bit,
                                onFinish: {
                                    withAnimation(.snappy) { markAsFinished(bit) }
                                },
                                onDelete: {
                                    withAnimation(.snappy) { softDeleteBit(bit) }
                                },
                                onTap: {
                                    if !isFlipped.wrappedValue {
                                        selectedBit = bit
                                    }
                                }
                            ) {
                                LooseFlippableBitCard(
                                    bit: bit,
                                    isFlipped: isFlipped,
                                    onTextFieldFocus: { textEditorID in
                                        // Auto-scroll to center text editor when keyboard appears
                                        activeTextFieldID = textEditorID
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                            withAnimation(.easeInOut(duration: 0.4)) {
                                                proxy.scrollTo(bit.id, anchor: .center)
                                            }
                                        }
                                    }
                                )
                                .id(bit.id)
                                .padding(.vertical, isFlipped.wrappedValue ? 8 : 0)
                                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isFlipped.wrappedValue)
                                .contentShape(Rectangle())
                                .contextMenu {
                                    Button {
                                        withAnimation {
                                            bit.isFavorite.toggle()
                                            bit.updatedAt = Date()
                                            try? modelContext.save()
                                        }
                                    } label: {
                                        Label(
                                            bit.isFavorite ? "Unfavorite" : "Favorite",
                                            systemImage: bit.isFavorite ? "star.slash" : "star.fill"
                                        )
                                    }

                                    Button {
                                        withAnimation(.snappy) { markAsFinished(bit) }
                                    } label: {
                                        Label("Mark as Finished", systemImage: "checkmark.seal.fill")
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .dismissKeyboardOnDrag()
        }
        .dismissKeyboardOnTap()
        .tfBackground()
        .navigationTitle("Loose Ideas")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "Search bits")
        .navigationDestination(item: $selectedBit) { bit in
            LooseBitDetailView(bit: bit)
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                TFWordmarkTitle(title: "Loose Ideas", size: 22)
                    .offset(x: -6)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showQuickBit = true
                } label: {
                    Image(systemName: "plus")
                        .appFont(size: 18, weight: .bold)
                        .foregroundStyle(TFTheme.yellow)
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.10))
                        .clipShape(Circle())
                        .overlay(
                            Circle().stroke(Color("TFCardStroke").opacity(0.9), lineWidth: 1)
                        )
                }
                .accessibilityLabel("New Bit")
            }
        }
        .sheet(isPresented: $showQuickBit) {
            QuickBitEditor()
                .presentationDetents([.medium, .large])
        }
        .hideKeyboardInteractively()
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Text("No loose ideas yet")
                .appFont(.title3, weight: .semibold)
                .foregroundStyle(TFTheme.text)

            Text("Tap + to capture an idea and it'll show up here.")
                .appFont(.subheadline)
                .foregroundStyle(TFTheme.text.opacity(0.65))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 26)

            Button {
                showQuickBit = true
            } label: {
                Text("Quick Bit")
                    .appFont(.headline, weight: .semibold)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(TFTheme.yellow)
                    .clipShape(Capsule())
            }
            .padding(.top, 6)
        }
    }

    private func markAsFinished(_ bit: Bit) {
        bit.status = .finished
        bit.updatedAt = Date()
        try? modelContext.save()
    }

    private func softDeleteBit(_ bit: Bit) {
        bit.softDelete(context: modelContext)
        try? modelContext.save()
    }
    
    private func sortDirectionLabel(descending: Bool) -> String {
        switch sortCriteria {
        case .dateModified, .dateCreated:
            return descending ? "Newest First" : "Oldest First"
        case .length:
            return descending ? "Longest First" : "Shortest First"
        }
    }
}

// MARK: - Loose Bit Card Row

private struct LooseBitCardRow: View {
    let bit: Bit

    var body: some View {
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
                    Text("•")
                        .appFont(.subheadline)
                        .foregroundStyle(TFTheme.text.opacity(0.4))

                    Text("\(bit.variationCount) variation\(bit.variationCount == 1 ? "" : "s")")
                        .appFont(.subheadline)
                        .foregroundStyle(TFTheme.text.opacity(0.55))
                }

                if bit.isFavorite {
                    Text("•")
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
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .tfDynamicCard(cornerRadius: 18)
    }
}

// MARK: - Loose Bit Detail View

/// Detail view for editing loose (work-in-progress) bits.
struct LooseBitDetailView: View {
    @Bindable var bit: Bit
    @State private var showVariationComparison = false
    @ObservedObject private var keyboard = TFKeyboardState.shared
    @Environment(\.undoManager) private var undoManager
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Form {
            Section("Title") {
                TextField("Enter a title", text: $bit.title)
                    .onChange(of: bit.title) { _, _ in
                        bit.updatedAt = Date()
                        try? modelContext.save()
                    }
            }

            Section("Text") {
                LooseUndoableTextEditor(
                    text: $bit.text,
                    modelContext: modelContext,
                    bit: bit,
                    undoManager: undoManager
                )
                .frame(minHeight: 240)
            }

            Section("Status") {
                Picker("Status", selection: $bit.status) {
                    Text("Loose").tag(BitStatus.loose)
                    Text("Finished").tag(BitStatus.finished)
                }
                .pickerStyle(.segmented)
                .onChange(of: bit.status) { oldValue, newValue in
                    bit.updatedAt = Date()
                    try? modelContext.save()
                }
            }

            Section("Tags") {
                LooseTagEditor(tags: $bit.tags) { updated in
                    bit.tags = updated
                    bit.updatedAt = Date()
                    try? modelContext.save()
                }
            }

            Section {
                ZStack(alignment: .topLeading) {
                    if bit.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Tap to add notes...")
                            .appFont(.body)
                            .foregroundStyle(TFTheme.text.opacity(0.35))
                            .padding(.top, 8)
                    }
                    TextEditor(text: Binding(
                        get: { bit.notes },
                        set: { newValue in
                            bit.notes = newValue
                            bit.updatedAt = Date()
                            try? modelContext.save()
                        }
                    ))
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .appFont(.body)
                    .foregroundStyle(TFTheme.text)
                    .frame(minHeight: 100)
                }
            } header: {
                HStack {
                    Image(systemName: "note.text")
                        .foregroundStyle(TFTheme.yellow)
                    Text("Notes")
                }
            } footer: {
                Text("Variant punchlines, alternate wording, delivery ideas, etc.")
            }

            // Show variations section if any exist
            if !(bit.variations?.isEmpty ?? true) {
                Section {
                    Button {
                        showVariationComparison = true
                    } label: {
                        HStack {
                            Image(systemName: "doc.on.doc")
                                .foregroundStyle(TFTheme.yellow)

                            Text("Compare Variations")
                                .foregroundStyle(TFTheme.text)

                            Spacer()

                            Text("\(bit.variationCount)")
                                .appFont(.subheadline, weight: .semibold)
                                .foregroundStyle(.black)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(TFTheme.yellow)
                                .clipShape(Capsule())
                        }
                    }
                } header: {
                    Text("Variations")
                } footer: {
                    Text("See how this bit evolved across different setlists.")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .tfBackground()
        .tfUndoRedoToolbar(isVisible: keyboard.isVisible)
        .navigationTitle("Bit")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    bit.isFavorite.toggle()
                    bit.updatedAt = Date()
                    try? modelContext.save()
                } label: {
                    Image(systemName: bit.isFavorite ? "star.fill" : "star")
                        .foregroundStyle(TFTheme.yellow)
                }
            }
        }
        .sheet(isPresented: $showVariationComparison) {
            VariationComparisonView(bit: bit)
        }
    }
}

// MARK: - Supporting Components

/// UITextView wrapper with built-in undo support
private struct LooseUndoableTextEditor: UIViewRepresentable {
    @Binding var text: String
    let modelContext: ModelContext
    let bit: Bit
    var undoManager: UndoManager?
    var isNotesField: Bool = false

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.font = .systemFont(ofSize: 17)
        textView.backgroundColor = .clear
        textView.textColor = .white
        textView.delegate = context.coordinator
        textView.allowsEditingTextAttributes = false
        textView.isScrollEnabled = true
        textView.autocapitalizationType = .sentences
        textView.autocorrectionType = .yes
        textView.spellCheckingType = .yes
        textView.text = text
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        if !context.coordinator.isInternalUpdate && textView.text != text {
            textView.text = text
        }
        context.coordinator.isInternalUpdate = false
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, modelContext: modelContext, bit: bit, isNotesField: isNotesField)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        @Binding var text: String
        let modelContext: ModelContext
        let bit: Bit
        let isNotesField: Bool
        var isInternalUpdate = false

        init(text: Binding<String>, modelContext: ModelContext, bit: Bit, isNotesField: Bool) {
            self._text = text
            self.modelContext = modelContext
            self.bit = bit
            self.isNotesField = isNotesField
        }

        func textViewDidChange(_ textView: UITextView) {
            isInternalUpdate = true
            text = textView.text
            if isNotesField {
                bit.notes = textView.text
            } else {
                bit.text = textView.text
            }
            bit.updatedAt = Date()
            try? modelContext.save()
        }
    }
}

/// Tag editor for loose bits
private struct LooseTagEditor: View {
    @Binding var tags: [String]
    var onChange: ([String]) -> Void
    @State private var input: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(tags, id: \.self) { tag in
                            HStack(spacing: 6) {
                                Text(tag)
                                    .appFont(.caption2, weight: .medium)
                                    .foregroundStyle(.black)
                                Image(systemName: "xmark.circle.fill")
                                    .appFont(.caption)
                                    .foregroundStyle(.black.opacity(0.7))
                                    .onTapGesture {
                                        var copy = tags
                                        copy.removeAll { $0.caseInsensitiveCompare(tag) == .orderedSame }
                                        onChange(copy)
                                    }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(TFTheme.yellow.opacity(0.9))
                            .clipShape(Capsule())
                        }
                    }
                }
            }

            HStack {
                TextField("Add tag", text: $input)
                    .appFont(.body)
                    .textInputAutocapitalization(.words)
                    .onSubmit(addTag)
                Button("Add") { addTag() }
                    .buttonStyle(.borderedProminent)
                    .tint(TFTheme.yellow)
                    .foregroundStyle(.black)
            }
        }
    }

    private func addTag() {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let set = Set(tags.map { $0.lowercased() })
        let key = trimmed.lowercased()
        guard !set.contains(key) else { input = ""; return }
        var copy = tags
        copy.append(trimmed)
        onChange(copy)
        input = ""
    }
}
