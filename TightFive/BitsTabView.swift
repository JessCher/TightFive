import SwiftUI
import SwiftData

/// Combined view for the Bits tab that shows loose, finished, and favorited bits
/// with a segmented picker to switch between them.
///
/// **Scroll behavior:**
/// - Search bar is hidden above screen by default, pulls down when user drags/scrolls up
/// - Tabs stay at the top of scrollable content and travel off-screen with scroll
/// - This maximizes screen real estate for bit cards
struct BitsTabView: View {
    @State private var selectedSegment: BitSegment = .loose
    @State private var query: String = ""
    @State private var showQuickBit = false
    @State private var selectedBit: Bit?
    @State private var showImport = false

    enum BitSegment: String, CaseIterable {
        case loose = "Ideas"
        case finished = "Finished"
        case favorites = "Favorites"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Segmented picker - scrolls with content for maximum card real estate
                Picker("Bits", selection: $selectedSegment) {
                    ForEach(BitSegment.allCases, id: \.self) { segment in
                        Text(segment.rawValue).tag(segment)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 12)

                // Tab content (no nested ScrollView - parent ScrollView handles scrolling)
                switch selectedSegment {
                case .loose:
                    LooseBitsContent(query: query, selectedBit: $selectedBit)
                case .finished:
                    FinishedBitsContent(query: query, selectedBit: $selectedBit)
                case .favorites:
                    FavoritesBitsContent(query: query, selectedBit: $selectedBit)
                }
            }
        }
        // Search bar: hidden above screen by default, pulls down when user drags/scrolls up
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search bits")
        .navigationDestination(item: $selectedBit) { bit in
            if bit.status == .loose {
                LooseBitDetailView(bit: bit)
            } else {
                FinishedBitDetailView(bit: bit)
            }
        }
        .tfBackground()
        .navigationTitle("Bits")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                TFWordmarkTitle(title: "Bits", size: 22)
                    .offset(x: -6)
            }
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showImport = true
                } label: {
                    Image(systemName: "square.and.arrow.down")
                }
                .accessibilityLabel("Import Bits")
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
        .sheet(isPresented: $showImport) {
            ImportContentView(mode: .bits, defaultStatus: selectedSegment == .finished ? .finished : .loose)
        }
    }
}

// MARK: - Shared Sort Criteria

/// Shared sorting options used across all Bits tab content views
private enum BitSortCriteria: String, CaseIterable, Identifiable {
    case dateModified = "Date Modified"
    case dateCreated = "Date Created"
    case length = "Length"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .dateModified: return "calendar.badge.clock"
        case .dateCreated: return "calendar.badge.plus"
        case .length: return "text.alignleft"
        }
    }
}

/// Reusable sort menu button used across all tab content views
private struct BitSortMenuButton: View {
    @Binding var sortCriteria: BitSortCriteria
    @Binding var sortAscending: Bool

    var body: some View {
        HStack {
            Spacer()
            Menu {
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

// MARK: - Shared Helpers

private func wordCount(for bit: Bit) -> Int {
    bit.text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
}

private func sortedBits(_ bits: [Bit], criteria: BitSortCriteria, ascending: Bool) -> [Bit] {
    bits.sorted { bit1, bit2 in
        let comparison: Bool
        switch criteria {
        case .dateModified:
            comparison = bit1.updatedAt < bit2.updatedAt
        case .dateCreated:
            comparison = bit1.createdAt < bit2.createdAt
        case .length:
            comparison = wordCount(for: bit1) < wordCount(for: bit2)
        }
        return ascending ? comparison : !comparison
    }
}

private func searchFilter(_ bits: [Bit], query: String) -> [Bit] {
    let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !q.isEmpty else { return bits }
    return bits.filter { bit in
        bit.text.localizedCaseInsensitiveContains(q)
        || bit.title.localizedCaseInsensitiveContains(q)
        || bit.tags.contains(where: { $0.localizedCaseInsensitiveContains(q) })
    }
}

// MARK: - Loose Bits Content

/// Inline content for the Loose (Ideas) tab. Rendered inside parent ScrollView.
private struct LooseBitsContent: View {
    let query: String
    @Binding var selectedBit: Bit?

    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Bit> { bit in
        !bit.isDeleted && bit.statusRaw == "loose"
    }, sort: \Bit.updatedAt, order: .reverse) private var looseBits: [Bit]

    @State private var flippedBitIds: Set<UUID> = []
    @State private var sortCriteria: BitSortCriteria = .dateCreated
    @State private var sortAscending: Bool = false

    private var filtered: [Bit] {
        sortedBits(searchFilter(looseBits, query: query), criteria: sortCriteria, ascending: sortAscending)
    }

    var body: some View {
        VStack(spacing: 12) {
            BitSortMenuButton(sortCriteria: $sortCriteria, sortAscending: $sortAscending)

            if filtered.isEmpty {
                emptyState
                    .padding(.top, 40)
            } else {
                ForEach(filtered) { bit in
                    let isFlipped = Binding(
                        get: { flippedBitIds.contains(bit.id) },
                        set: { newValue in
                            if newValue { flippedBitIds.insert(bit.id) }
                            else { flippedBitIds.remove(bit.id) }
                        }
                    )

                    BitSwipeView(
                        bit: bit,
                        onFinish: { withAnimation(.snappy) { markAsFinished(bit) } },
                        onDelete: { withAnimation(.snappy) { softDeleteBit(bit) } },
                        onTap: { if !isFlipped.wrappedValue { selectedBit = bit } }
                    ) {
                        LooseFlippableBitCard(bit: bit, isFlipped: isFlipped)
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
        .padding(.top, 4)
        .padding(.bottom, 28)
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
        }
    }

    private func markAsFinished(_ bit: Bit) {
        bit.status = .finished
        bit.updatedAt = Date()
        try? modelContext.save()
    }

    private func softDeleteBit(_ bit: Bit) {
        bit.softDelete(context: modelContext)
        // Save AFTER a brief delay to allow animation to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            try? self.modelContext.save()
        }
    }
}

// MARK: - Finished Bits Content

/// Inline content for the Finished tab. Rendered inside parent ScrollView.
private struct FinishedBitsContent: View {
    let query: String
    @Binding var selectedBit: Bit?
    
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Bit> { bit in
        !bit.isDeleted && bit.statusRaw == "finished"
    }, sort: \Bit.updatedAt, order: .reverse) private var finishedBits: [Bit]
    
    @Query(sort: \Setlist.updatedAt, order: .reverse) private var allSetlists: [Setlist]
    
    private var inProgressSetlists: [Setlist] {
        allSetlists.filter { $0.isDraft }
    }
    
    @State private var flippedBitIds: Set<UUID> = []
    @State private var sortCriteria: BitSortCriteria = .dateCreated
    @State private var sortAscending: Bool = false
    
    private var filtered: [Bit] {
        sortedBits(searchFilter(finishedBits, query: query), criteria: sortCriteria, ascending: sortAscending)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            BitSortMenuButton(sortCriteria: $sortCriteria, sortAscending: $sortAscending)
            
            if filtered.isEmpty {
                emptyState
                    .padding(.top, 40)
            } else {
                ForEach(filtered) { bit in
                    let isFlipped = Binding(
                        get: { flippedBitIds.contains(bit.id) },
                        set: { newValue in
                            if newValue { flippedBitIds.insert(bit.id) }
                            else { flippedBitIds.remove(bit.id) }
                        }
                    )
                    
                    BitSwipeView(
                        bit: bit,
                        onFinish: { shareBit(bit) },
                        onDelete: { withAnimation(.snappy) { softDeleteBit(bit) } },
                        onTap: { if !isFlipped.wrappedValue { selectedBit = bit } }
                    ) {
                        FinishedFlippableBitCard(bit: bit, isFlipped: isFlipped)
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
                                    shareBit(bit)
                                } label: {
                                    Label("Share", systemImage: "square.and.arrow.up")
                                }
                                
                                if inProgressSetlists.isEmpty {
                                    Text("No in-progress setlists")
                                } else {
                                    Menu("Add to setlist\u{2026}") {
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
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 28)
    }
    
    private var emptyState: some View {
        VStack(spacing: 14) {
            Text("No finished bits yet")
                .appFont(.title3, weight: .semibold)
                .foregroundStyle(TFTheme.text)
            
            Text("Move a bit to Finished when it's stage-ready.")
                .appFont(.subheadline)
                .foregroundStyle(TFTheme.text.opacity(0.65))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 26)
        }
    }
    
    private func softDeleteBit(_ bit: Bit) {
        bit.softDelete(context: modelContext)
        // Save AFTER a brief delay to allow animation to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            try? self.modelContext.save()
        }
    }
    
    private func add(bit: Bit, to setlist: Setlist) {
        setlist.insertBit(bit, at: nil, context: modelContext)
        setlist.updatedAt = Date()
        try? modelContext.save()
    }
    
    private func shareBit(_ bit: Bit) {
        let descriptor = FetchDescriptor<UserProfile>()
        let userName = (try? modelContext.fetch(descriptor).first?.name) ?? ""
        
        // Render on a background thread to avoid blocking the main thread
        Task.detached(priority: .userInitiated) {
            let shareCard = BitShareCardUnified(bit: bit, userName: userName)
            let renderer = ImageRenderer(content: shareCard)
            
            // Use a reasonable scale - 2x for retina displays
            await MainActor.run {
                renderer.scale = 2.0
            }
            
            // Let the renderer calculate the natural size
            guard let image = await MainActor.run(body: { renderer.uiImage }) else {
                await MainActor.run {
                    print("Failed to render bit card image")
                }
                return
            }
            
            await MainActor.run {
                let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)
                
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
}

// MARK: - Favorites Content

/// Inline content for the Favorites tab. Shows all favorited bits regardless of status.
private struct FavoritesBitsContent: View {
    let query: String
    @Binding var selectedBit: Bit?
    
    @Environment(\.modelContext) private var modelContext
    
    /// All non-deleted favorited bits (both loose and finished)
    @Query(filter: #Predicate<Bit> { bit in
        !bit.isDeleted && bit.isFavorite
    }, sort: \Bit.updatedAt, order: .reverse) private var favoriteBits: [Bit]
    
    @State private var flippedBitIds: Set<UUID> = []
    @State private var sortCriteria: BitSortCriteria = .dateCreated
    @State private var sortAscending: Bool = false
    
    private var filtered: [Bit] {
        sortedBits(searchFilter(favoriteBits, query: query), criteria: sortCriteria, ascending: sortAscending)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            BitSortMenuButton(sortCriteria: $sortCriteria, sortAscending: $sortAscending)
            
            if filtered.isEmpty {
                emptyState
                    .padding(.top, 40)
            } else {
                ForEach(filtered) { bit in
                    let isFlipped = Binding(
                        get: { flippedBitIds.contains(bit.id) },
                        set: { newValue in
                            if newValue { flippedBitIds.insert(bit.id) }
                            else { flippedBitIds.remove(bit.id) }
                        }
                    )
                    
                    // Use the appropriate card based on bit status
                    if bit.status == .finished {
                        BitSwipeView(
                            bit: bit,
                            onFinish: { /* No swipe-right action for favorites */ },
                            onDelete: { withAnimation(.snappy) { softDeleteBit(bit) } },
                            onTap: { if !isFlipped.wrappedValue { selectedBit = bit } }
                        ) {
                            FinishedFlippableBitCard(bit: bit, isFlipped: isFlipped)
                                .id(bit.id)
                                .padding(.vertical, isFlipped.wrappedValue ? 8 : 0)
                                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isFlipped.wrappedValue)
                                .contentShape(Rectangle())
                                .contextMenu {
                                    favoriteContextMenu(for: bit)
                                    statusLabel(for: bit)
                                }
                        }
                    } else {
                        BitSwipeView(
                            bit: bit,
                            onFinish: { withAnimation(.snappy) { markAsFinished(bit) } },
                            onDelete: { withAnimation(.snappy) { softDeleteBit(bit) } },
                            onTap: { if !isFlipped.wrappedValue { selectedBit = bit } }
                        ) {
                            LooseFlippableBitCard(bit: bit, isFlipped: isFlipped)
                                .id(bit.id)
                                .padding(.vertical, isFlipped.wrappedValue ? 8 : 0)
                                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isFlipped.wrappedValue)
                                .contentShape(Rectangle())
                                .contextMenu {
                                    favoriteContextMenu(for: bit)
                                    statusLabel(for: bit)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 28)
    }
    
    @ViewBuilder
    private func favoriteContextMenu(for bit: Bit) -> some View {
        Button {
            withAnimation {
                bit.isFavorite.toggle()
                bit.updatedAt = Date()
                try? modelContext.save()
            }
        } label: {
            Label("Unfavorite", systemImage: "star.slash")
        }
    }
    
    @ViewBuilder
    private func statusLabel(for bit: Bit) -> some View {
        Label(
            bit.status == .loose ? "Loose Idea" : "Finished Bit",
            systemImage: bit.status == .loose ? "lightbulb" : "checkmark.seal"
        )
        .disabled(true)
    }
    
    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "star")
                .font(.system(size: 36))
                .foregroundStyle(TFTheme.text.opacity(0.4))
            
            Text("No favorites yet")
                .appFont(.title3, weight: .semibold)
                .foregroundStyle(TFTheme.text)
            
            Text("Long-press any bit and tap Favorite to see it here.")
                .appFont(.subheadline)
                .foregroundStyle(TFTheme.text.opacity(0.65))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 26)
        }
    }
    
    private func markAsFinished(_ bit: Bit) {
        bit.status = .finished
        bit.updatedAt = Date()
        try? modelContext.save()
    }
    
    private func softDeleteBit(_ bit: Bit) {
        bit.softDelete(context: modelContext)
        // Save AFTER a brief delay to allow animation to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            try? self.modelContext.save()
        }
    }
}

// MARK: - Shared Card Row

private struct BitsTabCardRow: View {
        let bit: Bit
        
        var body: some View {
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
        }
    }
    
    // MARK: - Share Card (unified for all bit sharing)
    
    private struct BitShareCardUnified: View {
        let bit: Bit
        let userName: String
        
        // Computed properties that read settings on every access
        private var settings: AppSettings { AppSettings.shared }
        
        // Reduce grit density for rendering to prevent crashes
        // Use 30% of normal density for share card rendering
        private func renderDensity(_ normalDensity: Int) -> Int {
            return max(50, Int(Double(normalDensity) * 0.3))
        }
        
        private var frameTheme: TileCardTheme {
            settings.bitCardFrameTheme
        }
        
        private var bottomBarTheme: TileCardTheme {
            settings.bitCardBottomBarTheme
        }
        
        private var windowTheme: TileCardTheme {
            settings.bitCardWindowTheme
        }
        
        private var frameColor: Color {
            switch frameTheme {
            case .darkGrit:
                return Color("TFCard")
            case .yellowGrit:
                return Color("TFYellow")
            case .custom:
                return Color(hex: settings.bitCardFrameCustomColorHex) ?? Color("TFCard")
            }
        }
        
        private var bottomBarColor: Color {
            switch bottomBarTheme {
            case .darkGrit:
                return Color("TFCard")
            case .yellowGrit:
                return Color("TFYellow")
            case .custom:
                return Color(hex: settings.bitCardBottomBarCustomColorHex) ?? Color("TFCard")
            }
        }
        
        private var windowColor: Color {
            switch windowTheme {
            case .darkGrit:
                return Color("TFCard")
            case .yellowGrit:
                return Color("TFYellow")
            case .custom:
                return Color(hex: settings.bitCardWindowCustomColorHex) ?? Color("TFCard")
            }
        }
        
        // Helper to determine if bottom bar should use dark text
        private var shouldUseDarkTextOnBottomBar: Bool {
            if bottomBarTheme == .yellowGrit {
                return true
            }
            if bottomBarTheme == .custom {
                // Check luminance of custom color
                if let components = UIColor(bottomBarColor).cgColor.components, components.count >= 3 {
                    let r = components[0]
                    let g = components[1]
                    let b = components[2]
                    let luminance = 0.299 * r + 0.587 * g + 0.114 * b
                    return luminance > 0.5
                }
            }
            return false
        }
        
        // Helper to determine if window should use dark text
        private var shouldUseDarkTextOnWindow: Bool {
            if windowTheme == .yellowGrit {
                return true
            }
            if windowTheme == .custom {
                // Check luminance of custom color
                if let components = UIColor(windowColor).cgColor.components, components.count >= 3 {
                    let r = components[0]
                    let g = components[1]
                    let b = components[2]
                    let luminance = 0.299 * r + 0.587 * g + 0.114 * b
                    return luminance > 0.5
                }
            }
            return false
        }
        
        var body: some View {
            // Wrap everything in a container that includes the frame
            ZStack {
                // Frame background with grit
                ZStack {
                    // Always render the base color first
                    frameColor
                    
                    // Then render grit layers based on settings
                    if frameTheme == .custom {
                        // Custom color: use custom grit settings (if enabled)
                        if settings.bitCardFrameGritEnabled {
                            StaticGritLayer(
                                density: renderDensity(800),
                                opacity: 0.85,
                                seed: 9999,
                                particleColor: Color(hex: settings.bitCardFrameGritLayer1ColorHex) ?? Color("TFYellow")
                            )
                            
                            StaticGritLayer(
                                density: renderDensity(100),
                                opacity: 0.88,
                                seed: 1111,
                                particleColor: Color(hex: settings.bitCardFrameGritLayer2ColorHex) ?? .white.opacity(0.3)
                            )
                            
                            StaticGritLayer(
                                density: renderDensity(400),
                                opacity: 0.88,
                                seed: 2222,
                                particleColor: Color(hex: settings.bitCardFrameGritLayer3ColorHex) ?? .white.opacity(0.1)
                            )
                        }
                    } else if frameTheme == .darkGrit {
                        // Dark grit theme
                        StaticGritLayer(
                            density: renderDensity(300),
                            opacity: 0.55,
                            seed: 9999,
                            particleColor: Color("TFYellow")
                        )
                        
                        StaticGritLayer(
                            density: renderDensity(300),
                            opacity: 0.35,
                            seed: 1111
                        )
                    } else if frameTheme == .yellowGrit {
                        // Yellow grit theme
                        StaticGritLayer(
                            density: renderDensity(800),
                            opacity: 0.85,
                            seed: 2223,
                            particleColor: .brown
                        )
                        
                        StaticGritLayer(
                            density: renderDensity(100),
                            opacity: 0.88,
                            seed: 3333,
                            particleColor: .black
                        )
                        
                        StaticGritLayer(
                            density: renderDensity(400),
                            opacity: 0.88,
                            seed: 4444,
                            particleColor: Color(red: 0.8, green: 0.4, blue: 0.0)
                        )
                    }
                }
                
                // Content on top of frame
                VStack(spacing: 0) {
                    // Main content area with dynamic card texture - rounded only at top
                    VStack(alignment: .leading, spacing: 16) {
                        // Bit text only (no title or tags)
                        Text(bit.text)
                            .appFont(size: 18)
                            .foregroundStyle(shouldUseDarkTextOnWindow ? .black.opacity(0.85) : .white.opacity(0.95))
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(32)
                    .background(
                        ZStack {
                            if windowTheme == .custom {
                                // Custom color with optional custom grit
                                windowColor
                                
                                if settings.bitCardWindowGritEnabled {
                                    StaticGritLayer(
                                        density: renderDensity(800),
                                        opacity: 0.85,
                                        seed: 7777,
                                        particleColor: Color(hex: settings.bitCardWindowGritLayer1ColorHex) ?? Color("TFYellow")
                                    )
                                    
                                    StaticGritLayer(
                                        density: renderDensity(100),
                                        opacity: 0.88,
                                        seed: 8888,
                                        particleColor: Color(hex: settings.bitCardWindowGritLayer2ColorHex) ?? .white.opacity(0.3)
                                    )
                                    
                                    StaticGritLayer(
                                        density: renderDensity(400),
                                        opacity: 0.88,
                                        seed: 8889,
                                        particleColor: Color(hex: settings.bitCardWindowGritLayer3ColorHex) ?? .white.opacity(0.1)
                                    )
                                }
                            } else if windowTheme == .darkGrit {
                                // Dark grit theme
                                Color("TFCard")
                                
                                StaticGritLayer(
                                    density: renderDensity(300),
                                    opacity: 0.55,
                                    seed: 1234,
                                    particleColor: Color("TFYellow")
                                )
                                
                                StaticGritLayer(
                                    density: renderDensity(300),
                                    opacity: 0.35,
                                    seed: 5678
                                )
                            } else {
                                // Yellow grit theme
                                Color("TFYellow")
                                
                                StaticGritLayer(
                                    density: renderDensity(800),
                                    opacity: 0.85,
                                    seed: 7777,
                                    particleColor: .brown
                                )
                                
                                StaticGritLayer(
                                    density: renderDensity(100),
                                    opacity: 0.88,
                                    seed: 8888,
                                    particleColor: .black
                                )
                                
                                StaticGritLayer(
                                    density: renderDensity(400),
                                    opacity: 0.88,
                                    seed: 8889,
                                    particleColor: Color(red: 0.8, green: 0.4, blue: 0.0)
                                )
                            }
                            
                            UnevenRoundedRectangle(
                                topLeadingRadius: 12,
                                bottomLeadingRadius: 0,
                                bottomTrailingRadius: 0,
                                topTrailingRadius: 12,
                                style: .continuous
                            )
                            .fill(
                                RadialGradient(
                                    colors: [.clear, .black.opacity(windowTheme == .darkGrit ? 0.3 : 0.15)],
                                    center: .center,
                                    startRadius: 50,
                                    endRadius: 400
                                )
                            )
                        }
                            .clipShape(
                                UnevenRoundedRectangle(
                                    topLeadingRadius: 12,
                                    bottomLeadingRadius: 0,
                                    bottomTrailingRadius: 0,
                                    topTrailingRadius: 12,
                                    style: .continuous
                                )
                            )
                    )
                    .overlay(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 12,
                            bottomLeadingRadius: 0,
                            bottomTrailingRadius: 0,
                            topTrailingRadius: 12,
                            style: .continuous
                        )
                        .strokeBorder(Color("TFCardStroke"), lineWidth: 1.5)
                        .opacity(0.9)
                        .blendMode(.overlay)
                    )
                    
                    // Polaroid-style bar at the bottom - rounded only at bottom
                    VStack(spacing: 4) {
                        TFWordmarkTitle(title: "written in TightFive", size: 16)
                        
                        if !userName.isEmpty {
                            Text("by \(userName)")
                                .appFont(size: 14)
                                .foregroundStyle(shouldUseDarkTextOnBottomBar ? .black.opacity(0.7) : .white.opacity(0.7))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(
                        ZStack {
                            if bottomBarTheme == .custom {
                                // Custom color with optional custom grit
                                bottomBarColor
                                
                                if settings.bitCardBottomBarGritEnabled {
                                    StaticGritLayer(
                                        density: renderDensity(800),
                                        opacity: 0.85,
                                        seed: 5555,
                                        particleColor: Color(hex: settings.bitCardBottomBarGritLayer1ColorHex) ?? Color("TFYellow")
                                    )
                                    
                                    StaticGritLayer(
                                        density: renderDensity(100),
                                        opacity: 0.88,
                                        seed: 6666,
                                        particleColor: Color(hex: settings.bitCardBottomBarGritLayer2ColorHex) ?? .white.opacity(0.3)
                                    )
                                    
                                    StaticGritLayer(
                                        density: renderDensity(400),
                                        opacity: 0.88,
                                        seed: 7777,
                                        particleColor: Color(hex: settings.bitCardBottomBarGritLayer3ColorHex) ?? .white.opacity(0.1)
                                    )
                                }
                            } else if bottomBarTheme == .darkGrit {
                                // Dark grit theme
                                Color("TFCard")
                                
                                StaticGritLayer(
                                    density: renderDensity(300),
                                    opacity: 0.55,
                                    seed: 1234,
                                    particleColor: Color("TFYellow")
                                )
                                
                                StaticGritLayer(
                                    density: renderDensity(300),
                                    opacity: 0.35,
                                    seed: 5678
                                )
                            } else {
                                // Yellow grit theme
                                Color("TFYellow")
                                
                                StaticGritLayer(
                                    density: renderDensity(800),
                                    opacity: 0.85,
                                    seed: 7778,
                                    particleColor: .brown
                                )
                                
                                StaticGritLayer(
                                    density: renderDensity(100),
                                    opacity: 0.88,
                                    seed: 8889,
                                    particleColor: .black
                                )
                                
                                StaticGritLayer(
                                    density: renderDensity(400),
                                    opacity: 0.88,
                                    seed: 8890,
                                    particleColor: Color(red: 0.8, green: 0.4, blue: 0.0)
                                )
                            }
                            
                            UnevenRoundedRectangle(
                                topLeadingRadius: 0,
                                bottomLeadingRadius: 12,
                                bottomTrailingRadius: 12,
                                topTrailingRadius: 0,
                                style: .continuous
                            )
                            .fill(.clear)
                        }
                            .clipShape(
                                UnevenRoundedRectangle(
                                    topLeadingRadius: 0,
                                    bottomLeadingRadius: 12,
                                    bottomTrailingRadius: 12,
                                    topTrailingRadius: 0,
                                    style: .continuous
                                )
                            )
                    )
                }
                .padding(12) // Creates visible frame border
            }
            .frame(width: 524) // 500 content + 24 padding for frame
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
        }
    }

