import SwiftUI
import Foundation
import SwiftData
import Combine

/// View for managing finished (stage-ready) bits.
/// For loose bits, see LooseBitsView.
struct FinishedBitsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Bit> { bit in
        !bit.isDeleted && bit.statusRaw == "finished"
    }, sort: \Bit.updatedAt, order: .reverse) private var finishedBits: [Bit]

    @Query(sort: \Setlist.updatedAt, order: .reverse) private var allSetlists: [Setlist]

    private var inProgressSetlists: [Setlist] {
        allSetlists.filter { $0.isDraft }
    }

    @State private var query: String = ""
    @State private var showQuickBit = false
    @State private var selectedBit: Bit?
    @State private var flippedBitIds: Set<UUID> = []
    @State private var activeTextFieldID: UUID?

    @State private var filterScope: FilterScope = .all
    @State private var sortCriteria: BitSortCriteria = .dateCreated
    @State private var sortAscending: Bool = false // false = descending (newest/longest first)
    
    private enum FilterScope: String, CaseIterable, Identifiable {
        case all = "All"
        case favorites = "Favorites"
        var id: String { rawValue }
    }
    
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

    /// Apply search filter and sorting to finished bits
    private var filtered: [Bit] {
        let base: [Bit]
        switch filterScope {
        case .all:
            base = finishedBits
        case .favorites:
            base = finishedBits.filter { $0.isFavorite }
        }
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let searchFiltered = q.isEmpty ? base : base.filter { bit in
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
                    HStack(spacing: 8) {
                        Picker("Scope", selection: $filterScope) {
                            Text("All").tag(FilterScope.all)
                            Text("Favorites").tag(FilterScope.favorites)
                        }
                        .pickerStyle(.segmented)
                        
                        // Sort button
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

                            // Use BitSwipeView with custom share action
                            BitSwipeView(
                                bit: bit,
                                onFinish: {
                                    // For finished bits, "finish" action becomes "share"
                                    shareBit(bit)
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
                                // The Card Itself with flip capability
                                FinishedFlippableBitCard(
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

                                    // Share action
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
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .dismissKeyboardOnDrag()
    }
    .dismissKeyboardOnTap()
    .tfBackground()
    .navigationTitle("Finished Bits")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "Search bits")
        .navigationDestination(item: $selectedBit) { bit in
            FinishedBitDetailView(bit: bit)
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                TFWordmarkTitle(title: "Finished Bits", size: 22)
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
        .hideKeyboardInteractively()
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

    private func softDeleteBit(_ bit: Bit) {
        bit.softDelete(context: modelContext)
        try? modelContext.save()
    }

    private func add(bit: Bit, to setlist: Setlist) {
        setlist.insertBit(bit, at: nil, context: modelContext)
        setlist.updatedAt = Date()
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
    
    private func shareBit(_ bit: Bit) {
        // Fetch user profile name
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
}

// MARK: - Finished Bit Detail View

/// Detail view for finished bits - used by both FinishedBitsView and BitsTabView
struct FinishedBitDetailView: View {
    @Bindable var bit: Bit
    @State private var showVariationComparison = false
    @State private var showShareSheet = false
    @State private var isCardFlipped = false
    @ObservedObject private var keyboard = TFKeyboardState.shared
    @Environment(\.undoManager) private var undoManager
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Main Bit Card with flip for notes
                FinishedDetailFlippableCard(bit: bit, isFlipped: $isCardFlipped)

                // Tags Card - Always show
                VStack(alignment: .leading, spacing: 12) {
                    Text("Tags")
                        .appFont(.headline)
                        .foregroundStyle(TFTheme.text)

                    TagEditor(tags: $bit.tags) { updated in
                        bit.tags = updated
                        bit.updatedAt = Date()
                        try? modelContext.save()
                    }
                }
                .padding(20)
                .tfDynamicCard(cornerRadius: 20)

                // Compare Variations Button
                if !(bit.variations?.isEmpty ?? true) {
                    Button {
                        showVariationComparison = true
                    } label: {
                        HStack {
                            Image(systemName: "doc.on.doc")
                                .appFont(.headline)
                            
                            Text("Compare Variations")
                                .appFont(.headline, weight: .semibold)
                            
                            Spacer()
                            
                            Text("\(bit.variationCount)")
                                .appFont(.subheadline, weight: .semibold)
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
                
                // Performance Insights Button
                BitPerformanceInsightsButton(bit: bit)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .tfBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    // Share button
                    Button {
                        shareBitInDetail(bit)
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
    
    private func shareBitInDetail(_ bit: Bit) {
        // Fetch user profile name
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

// MARK: - Finished Bit Card Row

private struct BitCardRow: View {
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

// MARK: - Performance Insights

/// Button to navigate to performance insights for a bit
struct BitPerformanceInsightsButton: View {
    let bit: Bit
    @State private var showInsights = false
    @State private var insightCount: Int = 0
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        Button {
            showInsights = true
        } label: {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .appFont(.headline)
                
                Text("Performance Insights")
                    .appFont(.headline, weight: .semibold)
                
                Spacer()
                
                if insightCount > 0 {
                    Text("\(insightCount)")
                        .appFont(.subheadline, weight: .semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(TFTheme.yellow.opacity(0.3))
                        .clipShape(Capsule())
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)
            .background(Color.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color("TFCardStroke"), lineWidth: 1.5)
                    .opacity(0.9)
            )
        }
        .sheet(isPresented: $showInsights) {
            BitPerformanceInsightsView(bit: bit)
        }
        .onAppear {
            loadInsightCount()
        }
    }
    
    private func loadInsightCount() {
        let insights = BitPerformanceInsight.fetchInsights(for: bit, context: modelContext)
        insightCount = insights.count
    }
}

/// View showing all performance insights for a specific bit
struct BitPerformanceInsightsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let bit: Bit
    
    @State private var insights: [BitPerformanceInsight] = []
    @State private var averageRating: Double = 0.0
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Average Rating Header
                    if averageRating > 0 {
                        VStack(spacing: 12) {
                            Text("Average Rating")
                                .appFont(.headline)
                                .foregroundStyle(TFTheme.text.opacity(0.7))
                            
                            HStack(spacing: 4) {
                                ForEach(1...5, id: \.self) { index in
                                    Image(systemName: starName(for: index, average: averageRating))
                                        .font(.system(size: 32))
                                        .foregroundStyle(TFTheme.yellow)
                                }
                            }
                            
                            Text(String(format: "%.1f / 5.0", averageRating))
                                .appFont(.title3, weight: .semibold)
                                .foregroundStyle(TFTheme.text)
                            
                            Text("\(insights.count) performance\(insights.count == 1 ? "" : "s")")
                                .appFont(.caption)
                                .foregroundStyle(TFTheme.text.opacity(0.5))
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity)
                        .tfDynamicCard(cornerRadius: 20)
                    }
                    
                    // Individual Insights
                    if insights.isEmpty {
                        emptyState
                    } else {
                        VStack(spacing: 16) {
                            ForEach(insights) { insight in
                                PerformanceInsightCard(insight: insight)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .tfBackground()
            .navigationTitle("Performance Insights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(TFTheme.yellow)
                }
            }
            .onAppear {
                loadInsights()
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.downtrend.xyaxis")
                .font(.system(size: 48))
                .foregroundStyle(TFTheme.text.opacity(0.3))
            
            Text("No Performance Data Yet")
                .appFont(.title3, weight: .semibold)
                .foregroundStyle(TFTheme.text)
            
            Text("Rate this bit in Show Notes after performing it to see insights here.")
                .appFont(.subheadline)
                .foregroundStyle(TFTheme.text.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.top, 60)
    }
    
    private func loadInsights() {
        insights = BitPerformanceInsight.fetchInsights(for: bit, context: modelContext)
        
        // Calculate average rating
        let ratings = insights.compactMap { $0.rating > 0 ? $0.rating : nil }
        if !ratings.isEmpty {
            averageRating = Double(ratings.reduce(0, +)) / Double(ratings.count)
        }
    }
    
    private func starName(for index: Int, average: Double) -> String {
        if Double(index) <= average {
            return "star.fill"
        } else if Double(index) - 0.5 <= average {
            return "star.leadinghalf.filled"
        } else {
            return "star"
        }
    }
}

/// Card displaying a single performance insight
struct PerformanceInsightCard: View {
    let insight: BitPerformanceInsight
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Date and Venue
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(insight.datePerformed, style: .date)
                        .appFont(.headline)
                        .foregroundStyle(TFTheme.text)
                    
                    if !insight.venue.isEmpty {
                        Text(insight.venue)
                            .appFont(.subheadline)
                            .foregroundStyle(TFTheme.text.opacity(0.7))
                    }
                    
                    if !insight.city.isEmpty {
                        Text(insight.city)
                            .appFont(.caption)
                            .foregroundStyle(TFTheme.text.opacity(0.5))
                    }
                }
                
                Spacer()
                
                // Rating
                if insight.rating > 0 {
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { index in
                            Image(systemName: index <= insight.rating ? "star.fill" : "star")
                                .font(.system(size: 16))
                                .foregroundStyle(index <= insight.rating ? TFTheme.yellow : .white.opacity(0.3))
                        }
                    }
                }
            }
            
            // Notes
            if !insight.notes.isEmpty {
                Divider()
                    .background(.white.opacity(0.2))
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Notes")
                        .appFont(.caption, weight: .semibold)
                        .foregroundStyle(TFTheme.text.opacity(0.6))
                        .textCase(.uppercase)
                        .kerning(0.5)
                    
                    Text(insight.notes)
                        .appFont(.body)
                        .foregroundStyle(TFTheme.text.opacity(0.85))
                        .lineSpacing(4)
                }
            }
            
            // Performance metadata
            HStack(spacing: 8) {
                Text("Show: \(insight.performanceTitle)")
                    .appFont(.caption2)
                    .foregroundStyle(TFTheme.text.opacity(0.4))
                    .lineLimit(1)
            }
        }
        .padding(16)
        .tfDynamicCard(cornerRadius: 14)
    }
}

// MARK: - BitPerformanceInsight Model

/// A computed view model representing how a bit performed in a specific show
struct BitPerformanceInsight: Identifiable {
    let id = UUID()
    let performanceId: UUID
    let performanceTitle: String
    let datePerformed: Date
    let city: String
    let venue: String
    let rating: Int
    let notes: String
    
    /// Fetch all performance insights for a specific bit
    static func fetchInsights(for bit: Bit, context: ModelContext) -> [BitPerformanceInsight] {
        // 1. Fetch all performances
        let performanceDescriptor = FetchDescriptor<Performance>(
            predicate: #Predicate { !$0.isDeleted },
            sortBy: [SortDescriptor(\Performance.datePerformed, order: .reverse)]
        )
        
        guard let performances = try? context.fetch(performanceDescriptor) else {
            return []
        }
        
        // 2. For each performance, find if this bit was rated
        var insights: [BitPerformanceInsight] = []
        
        for performance in performances {
            // 3. Fetch the setlist for this performance
            // Capture the setlist ID as a local variable for the predicate
            let setlistId = performance.setlistId
            let setlistDescriptor = FetchDescriptor<Setlist>(
                predicate: #Predicate<Setlist> { setlist in
                    setlist.id == setlistId
                }
            )
            
            guard let setlist = try? context.fetch(setlistDescriptor).first else {
                continue
            }
            
            // 4. Find script blocks that reference this bit's assignments
            let bitAssignmentIds = Set((setlist.assignments ?? []).filter { $0.bitId == bit.id }.map { $0.id })
            
            for block in setlist.scriptBlocks {
                guard case .bit(_, let assignmentId) = block,
                      bitAssignmentIds.contains(assignmentId) else {
                    continue
                }
                
                // 5. Check if this block has ratings or notes
                let blockIdString = block.id.uuidString
                let rating = performance.bitRatings[blockIdString] ?? 0
                let notes = performance.bitNotes[blockIdString] ?? ""
                
                // Only include if there's data
                if rating > 0 || !notes.isEmpty {
                    let insight = BitPerformanceInsight(
                        performanceId: performance.id,
                        performanceTitle: performance.displayTitle,
                        datePerformed: performance.datePerformed,
                        city: performance.city,
                        venue: performance.venue,
                        rating: rating,
                        notes: notes
                    )
                    insights.append(insight)
                    break // Only add one insight per performance (even if bit appears multiple times)
                }
            }
        }
        
        return insights
    }
}


