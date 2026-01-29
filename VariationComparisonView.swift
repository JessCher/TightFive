import SwiftUI
import SwiftData

/// Displays all variations of a bit for comparison.
///
/// Shows the original master text alongside variations from different setlists,
/// allowing comedians to see how their material has evolved.
struct VariationComparisonView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Bindable var bit: Bit
    
    @State private var selectedVariationId: UUID?
    @State private var variationToDelete: BitVariation?
    @State private var showDeleteConfirmation = false
    @State private var variationToPromote: BitVariation?
    @State private var showPromoteConfirmation = false
    
    private var sortedVariations: [BitVariation] {
        bit.variations.sorted { $0.createdAt > $1.createdAt }
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Master (original) card section
                Section {
                    masterCard
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
                
                // Variations section
                if !sortedVariations.isEmpty {
                    Section {
                        ForEach(sortedVariations) { variation in
                            variationCard(variation)
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                .listRowSeparator(.hidden)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        variationToDelete = variation
                                        showDeleteConfirmation = true
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                    Button {
                                        variationToPromote = variation
                                        showPromoteConfirmation = true
                                    } label: {
                                        Label("Make Master", systemImage: "star.fill")
                                    }
                                    .tint(TFTheme.yellow)
                                }
                                .contextMenu {
                                    Button {
                                        variationToPromote = variation
                                        showPromoteConfirmation = true
                                    } label: {
                                        Label("Make Master", systemImage: "star.fill")
                                    }
                                    
                                    Button(role: .destructive) {
                                        variationToDelete = variation
                                        showDeleteConfirmation = true
                                    } label: {
                                        Label("Delete Variation", systemImage: "trash")
                                    }
                                }
                        }
                    } header: {
                        HStack {
                            Text("VARIATIONS")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white.opacity(0.5))
                                .kerning(1.5)
                            
                            Spacer()
                            
                            Text("\(sortedVariations.count)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(TFTheme.yellow)
                                .clipShape(Capsule())
                        }
                        .textCase(nil)
                    }
                } else {
                    Section {
                        noVariationsState
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 20, leading: 16, bottom: 20, trailing: 16))
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .navigationTitle("Compare Variations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(TFTheme.yellow)
                }
                
                ToolbarItem(placement: .principal) {
                    TFWordmarkTitle(title: "Variations", size: 20)
                }
            }
            .tfBackground()
            .alert("Delete Variation?", isPresented: $showDeleteConfirmation, presenting: variationToDelete) { variation in
                Button("Cancel", role: .cancel) {
                    variationToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    deleteVariation(variation)
                }
            } message: { variation in
                Text("This will permanently delete the variation from \"\(variation.setlistTitle)\". This cannot be undone.")
            }
            .confirmationDialog(
                "Promote this variation to master?",
                isPresented: $showPromoteConfirmation,
                titleVisibility: .visible,
                presenting: variationToPromote
            ) { variation in
                Button("Promote to Master") {
                    promoteToMaster(variation)
                }
                Button("Cancel", role: .cancel) {
                    variationToPromote = nil
                }
            } message: { variation in
                Text("This will replace the current master version with this variation from \"\(variation.setlistTitle)\".")
            }
        }
    }
    
    // MARK: - Master Card
    
    private var masterCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Master")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(TFTheme.yellow)
                    .clipShape(Capsule())
                
                Spacer()
                
                Text(bit.createdAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            
            Divider()
                .background(.white.opacity(0.2))
            
            // Content
            Text(bit.text)
                .font(.body)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            
            // Meta
            HStack {
                Text("\(bit.text.count) characters")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
                
                Spacer()
            }
        }
        .padding(20)
        .tfDynamicCard(cornerRadius: 20)
    }
    
    // MARK: - Variation Card
    
    private func variationCard(_ variation: BitVariation) -> some View {
        let isExpanded = selectedVariationId == variation.id
        
        return VStack(alignment: .leading, spacing: 12) {
            // Header (always visible)
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedVariationId = isExpanded ? nil : variation.id
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(variation.setlistTitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        
                        Text(variation.formattedDate)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                Divider().opacity(0.2)
                
                // Diff Legend
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green.opacity(0.3))
                            .frame(width: 8, height: 8)
                        Text("Added")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.orange.opacity(0.3))
                            .frame(width: 8, height: 8)
                        Text("Removed")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .padding(.bottom, 8)
                
                // Content with diff highlighting
                Text(diffHighlightedAttributedString(original: bit.text, modified: variation.plainText))
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Note if present
                if let note = variation.note, !note.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "quote.opening")
                            .font(.caption)
                            .foregroundStyle(TFTheme.yellow.opacity(0.7))
                        
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                            .italic()
                    }
                    .padding(.top, 4)
                }
                
                // Diff indicator
                diffIndicator(original: bit.text, modified: variation.plainText)
            }
        }
        .padding(16)
        .background(Color("TFCard"))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color("TFCardStroke").opacity(0.6), lineWidth: 1)
        )
    }
    
    // MARK: - Diff Highlighting
    
    private func diffHighlightedAttributedString(original: String, modified: String) -> AttributedString {
        let diff = computeDiff(original: original, modified: modified)
        var result = AttributedString()
        
        for change in diff {
            switch change {
            case .unchanged(let text):
                var unchanged = AttributedString(text)
                unchanged.foregroundColor = .white.opacity(0.9)
                result.append(unchanged)
                
            case .added(let text):
                var added = AttributedString(text)
                added.foregroundColor = .white
                added.backgroundColor = .green.opacity(0.3)
                result.append(added)
                
            case .removed(let text):
                var removed = AttributedString(text)
                removed.foregroundColor = .white.opacity(0.6)
                removed.strikethroughStyle = .single
                removed.strikethroughColor = .orange
                removed.backgroundColor = .orange.opacity(0.2)
                result.append(removed)
            }
        }
        
        return result
    }
    
    private enum DiffChange {
        case unchanged(String)
        case added(String)
        case removed(String)
    }
    
    private func computeDiff(original: String, modified: String) -> [DiffChange] {
        // Split into words for better readability
        let originalWords = original.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
        let modifiedWords = modified.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
        
        // Use longest common subsequence algorithm
        let lcs = longestCommonSubsequence(originalWords, modifiedWords)
        
        var result: [DiffChange] = []
        var i = 0  // index in original
        var j = 0  // index in modified
        var k = 0  // index in lcs
        
        while i < originalWords.count || j < modifiedWords.count {
            if k < lcs.count {
                let commonWord = lcs[k]
                
                // Add removed words
                while i < originalWords.count && originalWords[i] != commonWord {
                    result.append(.removed(originalWords[i] + " "))
                    i += 1
                }
                
                // Add added words
                while j < modifiedWords.count && modifiedWords[j] != commonWord {
                    result.append(.added(modifiedWords[j] + " "))
                    j += 1
                }
                
                // Add common word
                if i < originalWords.count && j < modifiedWords.count {
                    result.append(.unchanged(commonWord + " "))
                    i += 1
                    j += 1
                    k += 1
                }
            } else {
                // Process remaining words
                while i < originalWords.count {
                    result.append(.removed(originalWords[i] + " "))
                    i += 1
                }
                
                while j < modifiedWords.count {
                    result.append(.added(modifiedWords[j] + " "))
                    j += 1
                }
            }
        }
        
        return result
    }
    
    private func longestCommonSubsequence(_ a: [String], _ b: [String]) -> [String] {
        let m = a.count
        let n = b.count
        
        // Build DP table
        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        
        for i in 1...m {
            for j in 1...n {
                if a[i-1] == b[j-1] {
                    dp[i][j] = dp[i-1][j-1] + 1
                } else {
                    dp[i][j] = max(dp[i-1][j], dp[i][j-1])
                }
            }
        }
        
        // Backtrack to find LCS
        var lcs: [String] = []
        var i = m
        var j = n
        
        while i > 0 && j > 0 {
            if a[i-1] == b[j-1] {
                lcs.insert(a[i-1], at: 0)
                i -= 1
                j -= 1
            } else if dp[i-1][j] > dp[i][j-1] {
                i -= 1
            } else {
                j -= 1
            }
        }
        
        return lcs
    }
    
    // MARK: - Diff Indicator
    
    private func diffIndicator(original: String, modified: String) -> some View {
        let originalCount = original.count
        let modifiedCount = modified.count
        let diff = modifiedCount - originalCount
        let percentChange = originalCount > 0 ? abs(Double(diff) / Double(originalCount) * 100) : 0
        
        return HStack(spacing: 12) {
            // Character count change
            HStack(spacing: 4) {
                Image(systemName: diff >= 0 ? "plus" : "minus")
                    .font(.caption2)
                Text("\(abs(diff)) chars")
                    .font(.caption)
            }
            .foregroundStyle(diff >= 0 ? .green : .orange)
            
            // Percent change
            if percentChange > 0 {
                Text(String(format: "%.0f%% %@", percentChange, diff >= 0 ? "longer" : "shorter"))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
            }
            
            Spacer()
        }
        .padding(.top, 8)
    }
    
    // MARK: - No Variations
    
    private var noVariationsState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.on.doc")
                .font(.system(size: 36))
                .foregroundStyle(.white.opacity(0.3))
            
            Text("No variations yet")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.7))
            
            Text("Variations are created when you edit a bit's content in a setlist.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
    }
    
    // MARK: - Delete Action
    
    private func deleteVariation(_ variation: BitVariation) {
        withAnimation {
            // Remove from bit's variations array
            bit.variations.removeAll { $0.id == variation.id }
            
            // Delete from context
            modelContext.delete(variation)
            
            // Save changes
            try? modelContext.save()
            
            // Clear selection if deleting the currently selected variation
            if selectedVariationId == variation.id {
                selectedVariationId = nil
            }
            
            // Clear the deletion state
            variationToDelete = nil
        }
    }
    
    // MARK: - Promote to Master Action
    
    private func promoteToMaster(_ variation: BitVariation) {
        withAnimation {
            // Save current master as a variation first
            let currentMasterRTF = bit.text.toRTFData() ?? Data()
            let oldMaster = BitVariation(
                setlistId: UUID(), // Use a placeholder since it's the original master
                setlistTitle: "Previous Master",
                rtfData: currentMasterRTF,
                note: "Replaced by variation from \"\(variation.setlistTitle)\""
            )
            oldMaster.bit = bit
            bit.variations.append(oldMaster)
            
            // Update the master bit with variation content
            bit.text = variation.plainText
            bit.updatedAt = Date()
            
            // Remove the promoted variation from variations list
            bit.variations.removeAll { $0.id == variation.id }
            modelContext.delete(variation)
            
            // Save changes
            try? modelContext.save()
            
            // Clear the promotion state
            variationToPromote = nil
            
            // Clear selection if promoting the currently selected variation
            if selectedVariationId == variation.id {
                selectedVariationId = nil
            }
        }
    }
}

// MARK: - String to RTF Helper

extension String {
    func toRTFData() -> Data? {
        let attributedString = NSAttributedString(string: self)
        let range = NSRange(location: 0, length: attributedString.length)
        return try? attributedString.data(
            from: range,
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )
    }
}

// MARK: - Preview

#Preview {
    let bit = Bit(text: "So I was at the coffee shop the other day...\n\nAnd the barista asks me, 'What size?'\n\nI said, 'Surprise me.'\n\nThey handed me an empty cup.")
    
    return VariationComparisonView(bit: bit)
}
