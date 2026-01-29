import SwiftUI
import Foundation
import SwiftData
import Combine

struct FinishedBitsView: View {
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
    
    private var title: String {
        return "Finished Bits"
    }

    /// Apply search filter to finished bits only
    private var filtered: [Bit] {
        let finishedBits = allBits.filter { $0.status == .finished }
        
        // Apply search filter
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return finishedBits }
        return finishedBits.filter { bit in
            bit.text.localizedCaseInsensitiveContains(q)
            || bit.title.localizedCaseInsensitiveContains(q)
            || bit.tags.contains(where: { $0.localizedCaseInsensitiveContains(q) })
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if filtered.isEmpty {
                    emptyState
                        .padding(.top, 40)
                } else {
                    ForEach(filtered) { bit in
                        NavigationLink(value: bit) {
                            // The Card Itself
                            BitCardRow(bit: bit)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
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
                                Menu("Add to setlist…") {
                                    ForEach(inProgressSetlists) { setlist in
                                        Button(setlist.title.isEmpty ? "Untitled Set" : setlist.title) {
                                            add(bit: bit, to: setlist)
                                        }
                                    }
                                }
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                withAnimation(.snappy) { softDeleteBit(bit) }
                            } label: {
                                Label("Delete", systemImage: "trash")
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
        .hideKeyboardInteractively()
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Text("No finished bits yet")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            Text("Move a bit to Finished when it's stage-ready.")
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

    private func softDeleteBit(_ bit: Bit) {
        bit.softDelete(context: modelContext)
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

// MARK: - Bit Detail View
private struct BitDetailView: View {
    @Bindable var bit: Bit
    @State private var showVariationComparison = false
    @State private var showShareSheet = false
    @ObservedObject private var keyboard = TFKeyboardState.shared
    @Environment(\.undoManager) private var undoManager
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Main Bit Card
                VStack(alignment: .leading, spacing: 16) {
                    Text(bit.titleLine)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(TFTheme.yellow)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)
                    
                    Divider()
                        .background(.white.opacity(0.2))
                    
                    // Read-only text view that scales to content
                    Text(bit.text)
                        .font(.body)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
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

// MARK: - Bit Card Row (shared component)
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

// MARK: - Share Card (shared component)
private struct BitShareCard: View {
    let bit: Bit
    let userName: String
    
    var body: some View {
        VStack(spacing: 0) {
            contentArea
            bottomBar
        }
        .frame(width: 500)
        .background(Color("TFCard"))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
    }
    
    private var contentArea: some View {
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
    }
    
    private var bottomBar: some View {
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
        .background(Color("TFCard"))
    }
}
