import SwiftUI
import SwiftData

/// A drawer sheet for selecting bits to add to a setlist.
///
/// Shows finished bits by default (stage-ready material), with option to show all.
/// Bits already in the setlist are marked but can be added again (same bit, different spot).
struct BitDrawerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    /// The setlist we're adding bits to
    let setlist: Setlist
    
    /// Callback when a bit is selected
    let onSelect: (Bit) -> Void
    
    @Query(sort: \Bit.updatedAt, order: .reverse) private var allBits: [Bit]
    
    @State private var searchQuery: String = ""
    @State private var showAllBits: Bool = false
    
    @State private var isSelecting: Bool = false
    @State private var selectedBitIDs: Set<UUID> = []
    
    /// Filter: non-deleted, optionally finished-only, search query
    private var filteredBits: [Bit] {
        var bits = allBits.filter { !$0.isDeleted }
        
        // Filter by status unless showing all
        if !showAllBits {
            bits = bits.filter { $0.status == .finished }
        }
        
        // Apply search
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if !q.isEmpty {
            bits = bits.filter { $0.text.localizedCaseInsensitiveContains(q) }
        }
        
        return bits
    }
    
    /// Check if a bit is already in this setlist
    private func isInSetlist(_ bit: Bit) -> Bool {
        setlist.containsBit(withId: bit.id)
    }
    
    private func toggleSelection(for bit: Bit) {
        if selectedBitIDs.contains(bit.id) {
            selectedBitIDs.remove(bit.id)
        } else {
            selectedBitIDs.insert(bit.id)
        }
    }

    private func addSelectedBits() {
        let selected = filteredBits.filter { selectedBitIDs.contains($0.id) }
        guard !selected.isEmpty else { return }
        // Append in current visible order
        for bit in selected {
            onSelect(bit)
        }
        selectedBitIDs.removeAll()
        isSelecting = false
        dismiss()
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter toggle
                Picker("Filter", selection: $showAllBits) {
                    Text("Finished").tag(false)
                    Text("All Bits").tag(true)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
                
                Divider().opacity(0.25)
                
                // Bit list
                if filteredBits.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(filteredBits) { bit in
                                BitDrawerRow(
                                    bit: bit,
                                    isInSetlist: isInSetlist(bit),
                                    isSelected: selectedBitIDs.contains(bit.id),
                                    onTap: {
                                        if isSelecting {
                                            toggleSelection(for: bit)
                                        } else {
                                            onSelect(bit)
                                            dismiss()
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
            }
            .navigationTitle("Add Bit")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchQuery, prompt: "Search bits")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if isSelecting {
                        Button("Cancel") {
                            isSelecting = false
                            selectedBitIDs.removeAll()
                        }
                        .foregroundStyle(TFTheme.yellow)
                    } else {
                        Button("Cancel") {
                            dismiss()
                        }
                        .foregroundStyle(TFTheme.yellow)
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    TFWordmarkTitle(title: "Add Bit", size: 20)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    if isSelecting {
                        Button("Add Selected") { addSelectedBits() }
                            .foregroundStyle(TFTheme.yellow)
                            .disabled(selectedBitIDs.isEmpty)
                    } else {
                        Button("Select") { isSelecting = true }
                            .foregroundStyle(TFTheme.yellow)
                    }
                }
            }
            .tfBackground()
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            
            Image(systemName: showAllBits ? "tray" : "checkmark.seal")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.3))
            
            Text(showAllBits ? "No bits yet" : "No finished bits")
                .appFont(.title3, weight: .semibold)
                .foregroundStyle(.white)
            
            Text(showAllBits
                 ? "Create some bits first, then add them here."
                 : "Mark bits as Finished when they're stage-ready.")
                .appFont(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            if !showAllBits {
                Button("Show All Bits") {
                    withAnimation { showAllBits = true }
                }
                .appFont(.subheadline, weight: .medium)
                .foregroundStyle(TFTheme.yellow)
                .padding(.top, 8)
            }
            
            Spacer()
        }
    }
}

// MARK: - Drawer Row

private struct BitDrawerRow: View {
    let bit: Bit
    let isInSetlist: Bool
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Status indicator
                Image(systemName: bit.status == .finished ? "checkmark.seal.fill" : "pencil.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(bit.status == .finished ? TFTheme.yellow : .white.opacity(0.5))
                    .frame(width: 28)
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(bit.titleLine)
                        .appFont(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    
                    HStack(spacing: 8) {
                        Text(bit.updatedAt, style: .date)
                            .appFont(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                        
                        if isInSetlist {
                            Text("In Set")
                                .appFont(.caption, weight: .medium)
                                .foregroundStyle(.black)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(TFTheme.yellow.opacity(0.8))
                                .clipShape(Capsule())
                        }
                        
                        if bit.variationCount > 0 {
                            Text("\(bit.variationCount) var")
                                .appFont(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                }
                
                Spacer()
                
                // Add or Selected indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Color.green)
                } else {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(TFTheme.yellow)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color("TFCard"))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color("TFCardStroke").opacity(0.6), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    BitDrawerView(
        setlist: Setlist(title: "Test Set"),
        onSelect: { _ in }
    )
}
