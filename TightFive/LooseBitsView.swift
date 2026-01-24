import SwiftUI
import Foundation
import SwiftData
import Combine

struct LooseBitsView: View {
    enum Mode {
        case all
        case loose
        case finished
    }

    let mode: Mode

    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Bit> { bit in
        !bit.isDeleted
    }, sort: \Bit.updatedAt, order: .reverse) private var allBits: [Bit]

    @State private var query: String = ""
    @State private var showQuickBit = false
    
    // Navigation Path State for programmatic navigation (fixes gesture conflicts)
    @State private var navigationPath = NavigationPath()

    private var title: String {
        switch mode {
        case .all: return "Bits"
        case .loose: return "Loose ideas"
        case .finished: return "Finished Bits"
        }
    }

    /// Apply mode and search filters (deleted bits already excluded by @Query predicate)
    private var filtered: [Bit] {
        // First: apply mode filter
        let modeFiltered: [Bit] = {
            switch mode {
            case .all: return allBits
            case .loose: return allBits.filter { $0.status == .loose }
            case .finished: return allBits.filter { $0.status == .finished }
            }
        }()

        // Second: apply search filter
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return modeFiltered }
        return modeFiltered.filter { $0.text.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(spacing: 12) {
                    if filtered.isEmpty {
                        emptyState
                            .padding(.top, 40)
                    } else {
                        ForEach(filtered) { bit in
                            // Custom Swipe Wrapper
                            BitSwipeView(
                                bit: bit,
                                onFinish: {
                                    withAnimation(.snappy) { toggleStatus(bit) }
                                },
                                onDelete: {
                                    withAnimation(.snappy) { softDeleteBit(bit) }
                                },
                                onTap: {
                                    // Handle navigation manually to avoid gesture conflict
                                    navigationPath.append(bit)
                                }
                            ) {
                                // The Card Itself
                                BitCardRow(bit: bit)
                                    .contentShape(Rectangle())
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .tfBackground()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "Search bits")
            // Handle Navigation Destination here
            .navigationDestination(for: Bit.self) { bit in
                BitDetailView(bit: bit)
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    TFWordmarkTitle(title: title, size: 22)
                        .offset(x: -6)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showQuickBit = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .bold))
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
        }
        .hideKeyboardInteractively()
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Text(mode == .finished ? "No finished bits yet" : "No loose ideas yet")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            Text(mode == .finished
                 ? "Move a bit to Finished when it's stage-ready."
                 : "Tap + to capture an idea and it'll show up here.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.65))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 26)

            Button {
                showQuickBit = true
            } label: {
                Text("Quick Bit")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(TFTheme.yellow)
                    .clipShape(Capsule())
            }
            .padding(.top, 6)
        }
    }

    private func toggleStatus(_ bit: Bit) {
        bit.status = (bit.status == .loose) ? .finished : .loose
        bit.updatedAt = Date()
    }
    
    /// Soft delete: marks bit as deleted, hard-deletes variations, preserves setlist assignments
    private func softDeleteBit(_ bit: Bit) {
        bit.softDelete(context: modelContext)
        // Explicitly save to ensure the deletion persists immediately
        try? modelContext.save()
    }
}

// MARK: - Custom Swipe View
// This replaces the generic .swipeActions which only works in Lists
struct BitSwipeView<Content: View>: View {
    let bit: Bit
    let onFinish: () -> Void
    let onDelete: () -> Void
    let onTap: () -> Void
    let content: Content

    @State private var offset: CGFloat = 0
    @State private var isSwiping = false
    
    // Threshold to trigger the action automatically
    private let actionThreshold: CGFloat = 100
    
    init(bit: Bit, onFinish: @escaping () -> Void, onDelete: @escaping () -> Void, onTap: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.bit = bit
        self.onFinish = onFinish
        self.onDelete = onDelete
        self.onTap = onTap
        self.content = content()
    }

    var body: some View {
        ZStack {
            // Background Layer (The Actions)
            GeometryReader { geo in
                HStack(spacing: 0) {
                    // LEFT SIDE (Swipe Right -> Finish)
                    ZStack(alignment: .leading) {
                        TFTheme.yellow
                        Image(systemName: bit.status == .loose ? "checkmark.seal.fill" : "tray.full.fill")
                            .font(.title2)
                            .foregroundColor(.black)
                            .padding(.leading, 30)
                            .scaleEffect(offset > 0 ? 1.0 : 0.001)
                            .opacity(offset > 0 ? 1 : 0)
                    }
                    .frame(width: geo.size.width / 2)
                    .offset(x: offset > 0 ? 0 : -geo.size.width / 2)

                    // RIGHT SIDE (Swipe Left -> Delete)
                    ZStack(alignment: .trailing) {
                        Color.red
                        Image(systemName: "trash.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(.trailing, 30)
                            .scaleEffect(offset < 0 ? 1.0 : 0.001)
                            .opacity(offset < 0 ? 1 : 0)
                    }
                    .frame(width: geo.size.width / 2)
                    .offset(x: offset < 0 ? 0 : geo.size.width / 2)
                }
            }
            .cornerRadius(18)

            // Foreground Layer (The Card)
            content
                .offset(x: offset)
                .highPriorityGesture(
                    DragGesture(minimumDistance: 20)
                        .onChanged { value in
                            let translation = value.translation.width
                            let vertical = abs(value.translation.height)
                            
                            // Only start swiping if it's mostly horizontal
                            // This allows vertical scrolling to work naturally
                            if abs(translation) > vertical * 1.5 {
                                isSwiping = true
                                withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.8)) {
                                    offset = translation
                                }
                            }
                        }
                        .onEnded { value in
                            guard isSwiping else { return }
                            
                            let translation = value.translation.width
                            withAnimation(.snappy) {
                                if translation > actionThreshold {
                                    // Swipe Right -> Finish
                                    onFinish()
                                    offset = 0
                                } else if translation < -actionThreshold {
                                    // Swipe Left -> Delete
                                    onDelete()
                                    offset = -500
                                } else {
                                    // Snap back
                                    offset = 0
                                }
                            }
                            isSwiping = false
                        }
                )
                .onTapGesture {
                    if offset == 0 {
                        onTap()
                    }
                }
        }
    }
}

// MARK: - Bit row
private struct BitCardRow: View {
    let bit: Bit

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(bit.titleLine)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                
                Spacer()
                
                // Show variation count badge if any
                if bit.variationCount > 0 {
                    Text("\(bit.variationCount)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(TFTheme.yellow)
                        .clipShape(Capsule())
                }
            }

            Text(bit.updatedAt, style: .date)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .tfDynamicCard(cornerRadius: 18)
    }
}

// MARK: - Detail

// UITextView wrapper with built-in undo support (matches RichTextEditor pattern)
private struct UndoableTextEditor: UIViewRepresentable {
    @Binding var text: String
    let modelContext: ModelContext
    let bit: Bit
    var undoManager: UndoManager?
    
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
        
        // Load initial text
        textView.text = text
        
        return textView
    }
    
    func updateUIView(_ textView: UITextView, context: Context) {
        // Don't update if the change came from the text view itself
        if !context.coordinator.isInternalUpdate && textView.text != text {
            textView.text = text
        }
        context.coordinator.isInternalUpdate = false
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, modelContext: modelContext, bit: bit)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        @Binding var text: String
        let modelContext: ModelContext
        let bit: Bit
        var isInternalUpdate = false
        
        init(text: Binding<String>, modelContext: ModelContext, bit: Bit) {
            self._text = text
            self.modelContext = modelContext
            self.bit = bit
        }
        
        func textViewDidChange(_ textView: UITextView) {
            isInternalUpdate = true
            text = textView.text
            bit.text = textView.text
            bit.updatedAt = Date()
            try? modelContext.save()
        }
    }
}

private struct BitDetailView: View {
    @Bindable var bit: Bit
    @State private var showVariationComparison = false
    @ObservedObject private var keyboard = TFKeyboardState.shared
    @Environment(\.undoManager) private var undoManager
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        Form {
            Section("Text") {
                UndoableTextEditor(
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
            
            // Show variations section if any exist
            if !bit.variations.isEmpty {
                Section {
                    Button {
                        showVariationComparison = true
                    } label: {
                        HStack {
                            Image(systemName: "doc.on.doc")
                                .foregroundStyle(TFTheme.yellow)
                            
                            Text("Compare Variations")
                                .foregroundStyle(.white)
                            
                            Spacer()
                            
                            Text("\(bit.variationCount)")
                                .font(.subheadline.weight(.semibold))
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
        .sheet(isPresented: $showVariationComparison) {
            VariationComparisonView(bit: bit)
        }
    }
}



