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
    @State private var selectedBit: Bit?
    
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
                                selectedBit = bit
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
        .navigationDestination(item: $selectedBit) { bit in
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
                        .appFont(.title2, weight: .bold)
                        .foregroundStyle(TFTheme.yellow)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)
                    
                    Divider()
                        .background(.white.opacity(0.2))
                    
                    // Read-only text view that scales to content
                    Text(bit.text)
                        .appFont(.body)
                        .foregroundStyle(TFTheme.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
                .tfDynamicCard(cornerRadius: 20)
                
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
                if !bit.variations.isEmpty {
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

// MARK: - Bit Card Row (shared component)
private struct BitCardRow: View {
    let bit: Bit

    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            // MARK: - HIDDEN: Favorite and variation badges removed for consistency
            // HStack {
            //     Text(bit.titleLine)
            //         .appFont(.title3, weight: .semibold)
            //         .foregroundStyle(TFTheme.text)
            //         .lineLimit(3)
            //         .fixedSize(horizontal: false, vertical: true)
            //     
            //     Spacer()
            //     
            //     HStack(spacing: 8) {
            //         // Favorite indicator
            //         if bit.isFavorite {
            //             Image(systemName: "star.fill")
            //                 .appFont(.caption)
            //                 .foregroundStyle(TFTheme.yellow)
            //         }
            //         
            //         // Show variation count badge if any
            //         if bit.variationCount > 0 {
            //             Text("\(bit.variationCount)")
            //                 .appFont(.caption, weight: .semibold)
            //                 .foregroundStyle(.black)
            //                 .padding(.horizontal, 8)
            //                 .padding(.vertical, 4)
            //                 .background(TFTheme.yellow)
            //                 .clipShape(Capsule())
            //         }
            //     }
            // }

            Text(bit.titleLine)
                .appFont(.title3, weight: .semibold)
                .foregroundStyle(TFTheme.text)
                .lineLimit(3)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(bit.updatedAt, style: .date)
                .appFont(.subheadline)
                .foregroundStyle(TFTheme.text.opacity(0.55))
            
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

// MARK: - Share Card (shared component)
private struct BitShareCard: View {
    let bit: Bit
    let userName: String
    let frameColor: Color
    let bottomBarColor: Color
    let windowTheme: BitWindowTheme
    
    init(bit: Bit, userName: String) {
        self.bit = bit
        self.userName = userName
        
        // Resolve frame color (handle custom)
        let frameColorEnum = AppSettings.shared.bitCardFrameColor
        if frameColorEnum == .custom {
            self.frameColor = Color(hex: AppSettings.shared.customFrameColorHex) ?? Color("TFCard")
        } else {
            self.frameColor = frameColorEnum.color(customHex: nil)
        }
        
        // Resolve bottom bar color (handle custom)
        let bottomBarColorEnum = AppSettings.shared.bitCardBottomBarColor
        if bottomBarColorEnum == .custom {
            self.bottomBarColor = Color(hex: AppSettings.shared.customBottomBarColorHex) ?? Color("TFCard")
        } else {
            self.bottomBarColor = bottomBarColorEnum.color(customHex: nil)
        }
        
        self.windowTheme = AppSettings.shared.bitWindowTheme
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main content area with dynamic card texture - rounded only at top
            VStack(alignment: .leading, spacing: 16) {
                // Bit text only (no title or tags)
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
                    if windowTheme == .chalkboard {
                        // Original chalkboard theme
                        Color("TFCard")
                        
                        if AppSettings.shared.bitCardGritLevel > 0 {
                            StaticGritLayer(
                                density: AppSettings.shared.adjustedBitCardGritDensity(300),
                                opacity: 0.55,
                                seed: 1234,
                                particleColor: Color("TFYellow")
                            )
                            
                            StaticGritLayer(
                                density: AppSettings.shared.adjustedBitCardGritDensity(300),
                                opacity: 0.35,
                                seed: 5678
                            )
                        }
                    } else {
                        // Yellow grit theme (matches Quick Bit button)
                        Color("TFYellow")
                        
                        if AppSettings.shared.bitCardGritLevel > 0 {
                            StaticGritLayer(
                                density: AppSettings.shared.adjustedBitCardGritDensity(800),
                                opacity: 0.85,
                                seed: 7777,
                                particleColor: .brown
                            )
                            
                            StaticGritLayer(
                                density: AppSettings.shared.adjustedBitCardGritDensity(100),
                                opacity: 0.88,
                                seed: 8888,
                                particleColor: .black
                            )
                            
                            StaticGritLayer(
                                density: AppSettings.shared.adjustedBitCardGritDensity(400),
                                opacity: 0.88,
                                seed: 8888,
                                particleColor: Color(red: 0.8, green: 0.4, blue: 0.0)
                            )
                        }
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
                            colors: [.clear, .black.opacity(windowTheme == .chalkboard ? 0.3 : 0.15)],
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
                        .foregroundStyle(AppSettings.shared.bitCardBottomBarColor.hasTexture && AppSettings.shared.bitCardBottomBarColor == .yellowGrit ? .black.opacity(0.7) : .white.opacity(0.7))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(
                ZStack {
                    if AppSettings.shared.bitCardBottomBarColor.hasTexture, let theme = AppSettings.shared.bitCardBottomBarColor.textureTheme {
                        // Render textured background
                        if theme == .chalkboard {
                            Color("TFCard")
                            
                            if AppSettings.shared.bitCardGritLevel > 0 {
                                StaticGritLayer(
                                    density: AppSettings.shared.adjustedBitCardGritDensity(300),
                                    opacity: 0.55,
                                    seed: 1234,
                                    particleColor: Color("TFYellow")
                                )
                                
                                StaticGritLayer(
                                    density: AppSettings.shared.adjustedBitCardGritDensity(300),
                                    opacity: 0.35,
                                    seed: 5678
                                )
                            }
                        } else {
                            Color("TFYellow")
                            
                            if AppSettings.shared.bitCardGritLevel > 0 {
                                StaticGritLayer(
                                    density: AppSettings.shared.adjustedBitCardGritDensity(800),
                                    opacity: 0.85,
                                    seed: 7777,
                                    particleColor: .brown
                                )
                                
                                StaticGritLayer(
                                    density: AppSettings.shared.adjustedBitCardGritDensity(100),
                                    opacity: 0.88,
                                    seed: 8888,
                                    particleColor: .black
                                )
                                
                                StaticGritLayer(
                                    density: AppSettings.shared.adjustedBitCardGritDensity(400),
                                    opacity: 0.88,
                                    seed: 8888,
                                    particleColor: Color(red: 0.8, green: 0.4, blue: 0.0)
                                )
                            }
                        }
                    }
                    
                    UnevenRoundedRectangle(
                        topLeadingRadius: 0,
                        bottomLeadingRadius: 12,
                        bottomTrailingRadius: 12,
                        topTrailingRadius: 0,
                        style: .continuous
                    )
                    .fill(AppSettings.shared.bitCardBottomBarColor.hasTexture ? .clear : bottomBarColor)
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
        .frame(width: 500)
        .padding(12) // This creates the frame effect around everything
        .background(
            ZStack {
                if AppSettings.shared.bitCardFrameColor.hasTexture, let theme = AppSettings.shared.bitCardFrameColor.textureTheme {
                    // Render textured frame background
                    if theme == .chalkboard {
                        Color("TFCard")
                        
                        if AppSettings.shared.bitCardGritLevel > 0 {
                            StaticGritLayer(
                                density: AppSettings.shared.adjustedBitCardGritDensity(300),
                                opacity: 0.55,
                                seed: 9999,
                                particleColor: Color("TFYellow")
                            )
                            
                            StaticGritLayer(
                                density: AppSettings.shared.adjustedBitCardGritDensity(300),
                                opacity: 0.35,
                                seed: 1111
                            )
                        }
                    } else if theme == .yellowGrit {
                        Color("TFYellow")
                        
                        if AppSettings.shared.bitCardGritLevel > 0 {
                            StaticGritLayer(
                                density: AppSettings.shared.adjustedBitCardGritDensity(800),
                                opacity: 0.85,
                                seed: 2222,
                                particleColor: .brown
                            )
                            
                            StaticGritLayer(
                                density: AppSettings.shared.adjustedBitCardGritDensity(100),
                                opacity: 0.88,
                                seed: 3333,
                                particleColor: .black
                            )
                            
                            StaticGritLayer(
                                density: AppSettings.shared.adjustedBitCardGritDensity(400),
                                opacity: 0.88,
                                seed: 4444,
                                particleColor: Color(red: 0.8, green: 0.4, blue: 0.0)
                            )
                        }
                    }
                } else {
                    // Solid color frame
                    frameColor
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
    }
}
