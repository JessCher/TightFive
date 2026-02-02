import SwiftUI
import SwiftData

/// Combined view for the Bits tab that shows both loose and finished bits
/// with a segmented picker to switch between them.
struct BitsTabView: View {
    @State private var selectedSegment: BitSegment = .loose

    enum BitSegment: String, CaseIterable {
        case loose = "Loose"
        case finished = "Finished"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Segmented picker
            Picker("Bits", selection: $selectedSegment) {
                ForEach(BitSegment.allCases, id: \.self) { segment in
                    Text(segment.rawValue).tag(segment)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)

            // Content based on selection
            switch selectedSegment {
            case .loose:
                LooseBitsContent()
            case .finished:
                FinishedBitsContent()
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
        }
    }
}

// MARK: - Loose Bits Content

private struct LooseBitsContent: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Bit> { bit in
        !bit.isDeleted && bit.statusRaw == "loose"
    }, sort: \Bit.updatedAt, order: .reverse) private var looseBits: [Bit]

    @State private var query: String = ""
    @State private var showQuickBit = false
    @State private var selectedBit: Bit?
    @State private var flippedBitIds: Set<UUID> = []
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
                                if newValue {
                                    flippedBitIds.insert(bit.id)
                                } else {
                                    flippedBitIds.remove(bit.id)
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
        .searchable(text: $query, prompt: "Search loose bits")
        .navigationDestination(item: $selectedBit) { bit in
            LooseBitDetailView(bit: bit)
        }
        .toolbar {
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

// MARK: - Finished Bits Content

private struct FinishedBitsContent: View {
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

    private var filtered: [Bit] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let searchFiltered = q.isEmpty ? finishedBits : finishedBits.filter { bit in
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
                                if newValue {
                                    flippedBitIds.insert(bit.id)
                                } else {
                                    flippedBitIds.remove(bit.id)
                                }
                            }
                        )

                        BitSwipeView(
                            bit: bit,
                            onFinish: {
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
        .searchable(text: $query, prompt: "Search finished bits")
        .navigationDestination(item: $selectedBit) { bit in
            FinishedBitDetailView(bit: bit)
        }
        .toolbar {
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
        let descriptor = FetchDescriptor<UserProfile>()
        let userName = (try? modelContext.fetch(descriptor).first?.name) ?? ""

        let renderer = ImageRenderer(content: BitShareCardForTab(bit: bit, userName: userName))
        renderer.scale = 3.0

        if let image = renderer.uiImage {
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

// MARK: - Share Card (simplified copy for tab view)

private struct BitShareCardForTab: View {
    let bit: Bit
    let userName: String
    let windowTheme: BitWindowTheme

    init(bit: Bit, userName: String) {
        self.bit = bit
        self.userName = userName
        self.windowTheme = AppSettings.shared.bitWindowTheme
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                Text(bit.text)
                    .appFont(size: 18)
                    .foregroundStyle(windowTheme == .chalkboard ? .white.opacity(0.95) : .black.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(32)
            .background(
                ZStack {
                    windowTheme == .chalkboard ? Color("TFCard") : Color("TFYellow")

                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            RadialGradient(
                                colors: [.clear, .black.opacity(windowTheme == .chalkboard ? 0.3 : 0.15)],
                                center: .center,
                                startRadius: 50,
                                endRadius: 400
                            )
                        )
                }
            )
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 12, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 12, style: .continuous))

            VStack(spacing: 4) {
                TFWordmarkTitle(title: "written in TightFive", size: 16)

                if !userName.isEmpty {
                    Text("by \(userName)")
                        .appFont(size: 14)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(Color("TFCard"))
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 12, bottomTrailingRadius: 12, topTrailingRadius: 0, style: .continuous))
        }
        .frame(width: 500)
        .padding(12)
        .background(Color("TFCard"))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
    }
}
