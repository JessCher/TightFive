import SwiftUI
import SwiftData

/// Displays all variations of a bit for comparison.
///
/// Shows the original master text alongside variations from different setlists,
/// allowing comedians to see how their material has evolved.
struct VariationComparisonView: View {
    @Environment(\.dismiss) private var dismiss
    
    let bit: Bit
    
    @State private var selectedVariationId: UUID?
    
    private var sortedVariations: [BitVariation] {
        bit.variations.sorted { $0.createdAt > $1.createdAt }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Master (original) card
                    masterCard
                    
                    if !sortedVariations.isEmpty {
                        // Variations header
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
                        .padding(.horizontal, 4)
                        .padding(.top, 8)
                        
                        // Variation cards
                        ForEach(sortedVariations) { variation in
                            variationCard(variation)
                        }
                    } else {
                        noVariationsState
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
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
        }
    }
    
    // MARK: - Master Card
    
    private var masterCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Label("Master", systemImage: "star.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(TFTheme.yellow)
                
                Spacer()
                
                Text("Original")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
            
            Divider().opacity(0.2)
            
            // Content
            Text(bit.text)
                .font(.body)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            
            // Meta
            HStack {
                Text("Created \(bit.createdAt, style: .date)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
                
                Spacer()
                
                Text("\(bit.text.count) chars")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding(16)
        .background(Color("TFCard"))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(TFTheme.yellow.opacity(0.5), lineWidth: 2)
        )
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
                
                // Content
                Text(variation.plainText)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.9))
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
}

// MARK: - Preview

#Preview {
    let bit = Bit(text: "So I was at the coffee shop the other day...\n\nAnd the barista asks me, 'What size?'\n\nI said, 'Surprise me.'\n\nThey handed me an empty cup.")
    
    return VariationComparisonView(bit: bit)
}
