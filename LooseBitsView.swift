import SwiftUI
import Foundation
import SwiftData
import Combine

struct LooseBitsView: View {
    enum Mode {
        case all
        case loose
        case finished
        case favorites
    }

    let mode: Mode

    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Bit> { bit in
        !bit.isDeleted
    }, sort: \Bit.updatedAt, order: .reverse) private var allBits: [Bit]

    @Query(sort: \Setlist.updatedAt, order: .reverse) private var allSetlists: [Setlist]

    private var inProgressSetlists: [Setlist] {
        allSetlists.filter { $0.isDraft }
    }

    @State private var query: String = ""
    @State private var showQuickBit = false
    
    // Navigation Path State for programmatic navigation (fixes gesture conflicts)
    @State private var navigationPath = NavigationPath()

    private var title: String {
        switch mode {
        case .all: return "Bits"
        case .loose: return "Loose ideas"
        case .finished: return "Finished Bits"
        case .favorites: return "Favorites"
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
            case .favorites: return allBits.filter { $0.isFavorite }
            }
        }()

        // Second: apply search filter
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return modeFiltered }
        return modeFiltered.filter { bit in
            bit.text.localizedCaseInsensitiveContains(q)
            || bit.title.localizedCaseInsensitiveContains(q)
            || bit.tags.contains(where: { $0.localizedCaseInsensitiveContains(q) })
        }
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
                                    .contextMenu {
                                        // Favorite/Unfavorite action
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
                                        
                                        // Share action (finished bits only)
                                        if bit.status == .finished {
                                            Button {
                                                shareBit(bit)
                                            } label: {
                                                Label("Share", systemImage: "square.and.arrow.up")
                                            }
                                        }
                                        
                                        if bit.status == .finished {
                                            if inProgressSetlists.isEmpty {
                                                Text("No in-progress setlists")
                                            } else {
                                                Menu("Add to setlist…") {
                                                    ForEach(inProgressSetlists) { setlist in
                                                        Button(setlist.title.isEmpty ? "Untitled Set" : setlist.title) {
                                                            add(bit: bit, to: setlist)
                                                        }
                                                    }
                                                }
                                            }
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
            Text(emptyStateTitle)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            Text(emptyStateMessage)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.65))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 26)

            if mode != .favorites {
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
    }
    
    private var emptyStateTitle: String {
        switch mode {
        case .finished: return "No finished bits yet"
        case .favorites: return "No favorites yet"
        default: return "No loose ideas yet"
        }
    }
    
    private var emptyStateMessage: String {
        switch mode {
        case .finished:
            return "Move a bit to Finished when it's stage-ready."
        case .favorites:
            return "Favorite bits will appear here for quick access."
        default:
            return "Tap + to capture an idea and it'll show up here."
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

    private func add(bit: Bit, to setlist: Setlist) {
        setlist.insertBit(bit, at: nil, context: modelContext)
        setlist.updatedAt = Date()
        try? modelContext.save()
    }
    
    private func shareBit(_ bit: Bit) {
        // Fetch user profile name
        let descriptor = FetchDescriptor<UserProfile>()
        let userName = (try? modelContext.fetch(descriptor).first?.name) ?? ""
        
        let renderer = ImageRenderer(content: BitShareCard(bit: bit, userName: userName))
        renderer.scale = 3.0 // High resolution for sharing
        
        if let image = renderer.uiImage {
            let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)
            
            // Present the share sheet
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                var topVC = rootVC
                while let presentedVC = topVC.presentedViewController {
                    topVC = presentedVC
                }
                activityVC.popoverPresentationController?.sourceView = topVC.view
                topVC.present(activityVC, animated: true)
            }
        }
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
                    // LEFT SIDE (Swipe Right -> Finish) - only for loose bits
                    if bit.status == .loose {
                        ZStack(alignment: .leading) {
                            TFTheme.yellow
                            Image(systemName: "checkmark.seal.fill")
                                .font(.title2)
                                .foregroundColor(.black)
                                .padding(.leading, 30)
                                .scaleEffect(offset > 0 ? 1.0 : 0.001)
                                .opacity(offset > 0 ? 1 : 0)
                        }
                        .frame(width: geo.size.width / 2)
                        .offset(x: offset > 0 ? 0 : -geo.size.width / 2)
                    }

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
                                    // For finished bits, only allow left swipe (delete)
                                    if bit.status == .finished && translation > 0 {
                                        offset = 0
                                    } else {
                                        offset = translation
                                    }
                                }
                            }
                        }
                        .onEnded { value in
                            guard isSwiping else { return }
                            
                            let translation = value.translation.width
                            withAnimation(.snappy) {
                                if translation > actionThreshold && bit.status == .loose {
                                    // Swipe Right -> Finish (only for loose bits)
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
                
                HStack(spacing: 8) {
                    // Favorite indicator
                    if bit.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(TFTheme.yellow)
                    }
                    
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
            }

            Text(bit.updatedAt, style: .date)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.55))
            
            if !bit.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(bit.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption2.weight(.medium))
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
    
    var body: some View {
        if bit.status == .finished {
            FinishedBitDetailView(bit: bit)
        } else {
            LooseBitDetailView(bit: bit)
        }
    }
}

// MARK: - Loose Bit Detail View
private struct LooseBitDetailView: View {
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
            
            Section("Tags") {
                TagEditor(tags: $bit.tags) { updated in
                    bit.tags = updated
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

// MARK: - Finished Bit Detail View
private struct FinishedBitDetailView: View {
    @Bindable var bit: Bit
    @State private var showVariationComparison = false
    @State private var showShareSheet = false
    @ObservedObject private var keyboard = TFKeyboardState.shared
    @Environment(\.undoManager) private var undoManager
    @Environment(\.modelContext) private var modelContext
    
    private var displayTitle: String {
        let trimmed = bit.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Add Bit Title" : trimmed
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Main Bit Card
                VStack(alignment: .leading, spacing: 16) {
                    TextField("Add Bit Title", text: $bit.title, axis: .vertical)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(TFTheme.yellow)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .onChange(of: bit.title) { _, _ in
                            bit.updatedAt = Date()
                            try? modelContext.save()
                        }
                    
                    Divider()
                        .background(.white.opacity(0.2))
                    
                    // Editable text view that scales to content
                    UndoableTextEditor(
                        text: $bit.text,
                        modelContext: modelContext,
                        bit: bit,
                        undoManager: undoManager
                    )
                    .frame(minHeight: 200)
                }
                .padding(20)
                .tfDynamicCard(cornerRadius: 20)
                
                // Tags Card - Always show
                VStack(alignment: .leading, spacing: 12) {
                    Text("Tags")
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    TagEditor(tags: $bit.tags) { updated in
                        bit.tags = updated
                        bit.updatedAt = Date()
                        try? modelContext.save()
                    }
                }
                .padding(20)
                .tfDynamicCard(cornerRadius: 20)
                
                // Compare Variations Button
                if !bit.variations.isEmpty {
                    Button {
                        showVariationComparison = true
                    } label: {
                        HStack {
                            Image(systemName: "doc.on.doc")
                                .font(.headline)
                            
                            Text("Compare Variations")
                                .font(.headline.weight(.semibold))
                            
                            Spacer()
                            
                            Text("\(bit.variationCount)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(.black.opacity(0.15))
                                .clipShape(Capsule())
                        }
                        .foregroundStyle(.black)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 18)
                        .frame(maxWidth: .infinity)
                        .background(TFTheme.yellow)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(Color("TFCardStroke"), lineWidth: 1.5)
                                .opacity(0.9)
                                .blendMode(.overlay)
                        )
                        .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .tfBackground()
        .tfUndoRedoToolbar(isVisible: keyboard.isVisible)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    // Share button
                    Button {
                        shareBit(bit)
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(TFTheme.yellow)
                    }
                    
                    // Favorite button
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
        }
        .sheet(isPresented: $showVariationComparison) {
            VariationComparisonView(bit: bit)
        }
    }
    
    private func shareBit(_ bit: Bit) {
        // Fetch user profile name
        let descriptor = FetchDescriptor<UserProfile>()
        let userName = (try? modelContext.fetch(descriptor).first?.name) ?? ""
        
        let renderer = ImageRenderer(content: BitShareCard(bit: bit, userName: userName))
        renderer.scale = 3.0 // High resolution for sharing
        
        if let image = renderer.uiImage {
            let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)
            
            // Present the share sheet
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                var topVC = rootVC
                while let presentedVC = topVC.presentedViewController {
                    topVC = presentedVC
                }
                activityVC.popoverPresentationController?.sourceView = topVC.view
                topVC.present(activityVC, animated: true)
            }
        }
    }
}

// MARK: - Tag Editor

private struct TagEditor: View {
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
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.black)
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
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

// MARK: - Share Card

/// A beautifully styled polaroid-style card for sharing bits externally
private struct BitShareCard: View {
    let bit: Bit
    let userName: String
    let frameColor: Color
    
    init(bit: Bit, userName: String) {
        self.bit = bit
        self.userName = userName
        self.frameColor = AppSettings.shared.bitCardFrameColor.color
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main content area with dynamic card texture
            VStack(alignment: .leading, spacing: 16) {
                // Bit text only (no title or tags)
                Text(bit.text)
                    .font(.system(size: 18))
                    .foregroundStyle(.white.opacity(0.95))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(4)
            }
            .frame(maxWidth: 500)
            .padding(32)
            .tfDynamicCard(cornerRadius: 0)
            
            // Polaroid-style bar at the bottom - use same color variable
            VStack(spacing: 4) {
                TFWordmarkTitle(title: "written in TightFive", size: 16)
                
                if !userName.isEmpty {
                    Text("by \(userName)")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(frameColor)
        }
        .frame(width: 500)
        .background(frameColor)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            // Thin polaroid-style frame around the entire card - use same color variable
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(frameColor, lineWidth: 12)
        )
        .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
    }
}




