import SwiftUI
import SwiftData

struct LooseBitsView: View {
    enum Mode {
        case all
        case loose
        case finished
    }

    let mode: Mode

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Bit.updatedAt, order: .reverse) private var bits: [Bit]

    @State private var query: String = ""
    @State private var showQuickBit = false
    
    // Navigation Path State for programmatic navigation (fixes gesture conflicts)
    @State private var navigationPath = NavigationPath()

    private var title: String {
        switch mode {
        case .all: return "Bits"
        case .loose: return "Loose Bits"
        case .finished: return "Finished Bits"
        }
    }

    private var filtered: [Bit] {
        let base: [Bit] = {
            switch mode {
            case .all: return bits
            case .loose: return bits.filter { $0.status == .loose }
            case .finished: return bits.filter { $0.status == .finished }
            }
        }()

        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return base }
        return base.filter { $0.text.localizedCaseInsensitiveContains(q) }
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
                                    withAnimation(.snappy) { modelContext.delete(bit) }
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
        .hideKeyboardInteractively() // Use combined tap + swipe-down dismissal
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Text(mode == .finished ? "No finished bits yet" : "No loose bits yet")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            Text(mode == .finished
                 ? "Move a bit to Finished when it’s stage-ready."
                 : "Tap + to capture an idea and it’ll show up here.")
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
            Text(bit.titleLine)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

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

// MARK: - Detail (Unchanged)
private struct BitDetailView: View {
    @Bindable var bit: Bit

    var body: some View {
        Form {
            Section("Text") {
                TextEditor(text: $bit.text)
                    .frame(minHeight: 240)
            }

            Section("Status") {
                Picker("Status", selection: Binding(
                    get: { bit.status },
                    set: { newValue in
                        bit.status = newValue
                        bit.updatedAt = Date()
                    }
                )) {
                    Text("Loose").tag(BitStatus.loose)
                    Text("Finished").tag(BitStatus.finished)
                }
                .pickerStyle(.segmented)
            }
        }
        .scrollContentBackground(.hidden)
        .tfBackground()
        .navigationTitle("Bit")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: bit.text) {
            bit.updatedAt = Date()
        }
    }
}
