import SwiftUI
import SwiftData

/// Trashcan - A recovery and permanent deletion interface for soft-deleted items.
///
/// **Features:**
/// - View all deleted bits, setlists, and performances
/// - Restore items back to their original location
/// - Permanently delete items (hard delete with confirmation)
/// - Shows deletion date and time
struct TrashcanView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // Query all soft-deleted items
    @Query(
        filter: #Predicate<Bit> { $0.isDeleted },
        sort: \Bit.deletedAt,
        order: .reverse
    ) private var deletedBits: [Bit]
    
    @Query(
        filter: #Predicate<Setlist> { $0.isDeleted },
        sort: \Setlist.deletedAt,
        order: .reverse
    ) private var deletedSetlists: [Setlist]
    
    @Query(
        filter: #Predicate<Performance> { $0.isDeleted },
        sort: \Performance.deletedAt,
        order: .reverse
    ) private var deletedPerformances: [Performance]
    
    @State private var itemToHardDelete: TrashItem?
    @State private var showHardDeleteConfirmation = false
    @State private var showEmptyTrashConfirmation = false
    
    private var isEmpty: Bool {
        deletedBits.isEmpty && deletedSetlists.isEmpty && deletedPerformances.isEmpty
    }
    
    private var totalItemCount: Int {
        deletedBits.count + deletedSetlists.count + deletedPerformances.count
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if isEmpty {
                    emptyState
                } else {
                    trashcanList
                }
            }
            .navigationTitle("Trashcan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    TFWordmarkTitle(title: "Trashcan", size: 22)
                }
                
                if !isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showEmptyTrashConfirmation = true
                        } label: {
                            Text("Empty")
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .tfBackground()
            .alert("Permanently Delete?", isPresented: $showHardDeleteConfirmation, presenting: itemToHardDelete) { item in
                Button("Cancel", role: .cancel) {
                    itemToHardDelete = nil
                }
                Button("Delete Forever", role: .destructive) {
                    hardDelete(item)
                }
            } message: { item in
                Text("This will permanently delete \"\(item.title)\" and cannot be undone.")
            }
            .alert("Empty Trashcan?", isPresented: $showEmptyTrashConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete All (\(totalItemCount))", role: .destructive) {
                    emptyTrash()
                }
            } message: {
                Text("This will permanently delete all \(totalItemCount) items in the trashcan. This cannot be undone.")
            }
        }
    }
    
    // MARK: - Trashcan List
    
    private var trashcanList: some View {
        List {
            // Deleted Bits Section
            if !deletedBits.isEmpty {
                Section {
                    ForEach(deletedBits) { bit in
                        TrashItemRow(
                            title: bit.titleLine,
                            subtitle: deletedDateString(bit.deletedAt),
                            type: .bit,
                            onRestore: {
                                withAnimation {
                                    bit.restore()
                                    try? modelContext.save()
                                }
                            },
                            onDelete: {
                                itemToHardDelete = TrashItem(
                                    id: bit.id,
                                    title: bit.titleLine,
                                    type: .bit
                                )
                                showHardDeleteConfirmation = true
                            }
                        )
                    }
                } header: {
                    Text("BITS (\(deletedBits.count))")
                        .appFont(.caption, weight: .bold)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            
            // Deleted Setlists Section
            if !deletedSetlists.isEmpty {
                Section {
                    ForEach(deletedSetlists) { setlist in
                        TrashItemRow(
                            title: setlist.title,
                            subtitle: deletedDateString(setlist.deletedAt),
                            type: .setlist,
                            onRestore: {
                                withAnimation {
                                    setlist.restore()
                                    try? modelContext.save()
                                }
                            },
                            onDelete: {
                                itemToHardDelete = TrashItem(
                                    id: setlist.id,
                                    title: setlist.title,
                                    type: .setlist
                                )
                                showHardDeleteConfirmation = true
                            }
                        )
                    }
                } header: {
                    Text("SETLISTS (\(deletedSetlists.count))")
                        .appFont(.caption, weight: .bold)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            
            // Deleted Performances Section
            if !deletedPerformances.isEmpty {
                Section {
                    ForEach(deletedPerformances) { performance in
                        TrashItemRow(
                            title: performance.displayTitle,
                            subtitle: deletedDateString(performance.deletedAt),
                            type: .performance,
                            onRestore: {
                                withAnimation {
                                    performance.restore()
                                    try? modelContext.save()
                                }
                            },
                            onDelete: {
                                itemToHardDelete = TrashItem(
                                    id: performance.id,
                                    title: performance.displayTitle,
                                    type: .performance
                                )
                                showHardDeleteConfirmation = true
                            }
                        )
                    }
                } header: {
                    Text("SHOW NOTES (\(deletedPerformances.count))")
                        .appFont(.caption, weight: .bold)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "trash")
                .font(.system(size: 60))
                .foregroundStyle(.white.opacity(0.25))
            
            Text("Trashcan is Empty")
                .appFont(.title2, weight: .semibold)
                .foregroundStyle(.white)
            
            Text("Deleted items will appear here.\nYou can restore them or delete permanently.")
                .appFont(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 80)
    }
    
    // MARK: - Helper Functions
    
    private func deletedDateString(_ date: Date?) -> String {
        guard let date = date else { return "Unknown date" }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return "Deleted \(formatter.localizedString(for: date, relativeTo: Date()))"
    }
    
    private func hardDelete(_ item: TrashItem) {
        withAnimation {
            switch item.type {
            case .bit:
                if let bit = deletedBits.first(where: { $0.id == item.id }) {
                    // Hard delete: remove from context completely
                    modelContext.delete(bit)
                }
                
            case .setlist:
                if let setlist = deletedSetlists.first(where: { $0.id == item.id }) {
                    setlist.hardDelete(context: modelContext)
                }
                
            case .performance:
                if let performance = deletedPerformances.first(where: { $0.id == item.id }) {
                    performance.hardDelete(context: modelContext)
                }
            }
            
            try? modelContext.save()
            itemToHardDelete = nil
        }
    }
    
    private func emptyTrash() {
        withAnimation {
            // Hard delete all bits
            for bit in deletedBits {
                modelContext.delete(bit)
            }
            
            // Hard delete all setlists
            for setlist in deletedSetlists {
                setlist.hardDelete(context: modelContext)
            }
            
            // Hard delete all performances
            for performance in deletedPerformances {
                performance.hardDelete(context: modelContext)
            }
            
            try? modelContext.save()
        }
    }
}

// MARK: - Trash Item Row

private struct TrashItemRow: View {
    let title: String
    let subtitle: String
    let type: TrashItemType
    let onRestore: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image(systemName: iconName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(iconColor)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .appFont(.subheadline, weight: .medium)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                
                Text(subtitle)
                    .appFont(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
            
            Spacer()
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                onRestore()
            } label: {
                Label("Restore", systemImage: "arrow.uturn.backward")
            }
            .tint(.green)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash.fill")
            }
        }
        .contextMenu {
            Button {
                onRestore()
            } label: {
                Label("Restore", systemImage: "arrow.uturn.backward")
            }
            
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete Permanently", systemImage: "trash.fill")
            }
        }
    }
    
    private var iconName: String {
        switch type {
        case .bit: return "doc.text"
        case .setlist: return "list.bullet.clipboard"
        case .performance: return "waveform"
        }
    }
    
    private var iconColor: Color {
        switch type {
        case .bit: return TFTheme.yellow
        case .setlist: return .blue
        case .performance: return .purple
        }
    }
}

// MARK: - Supporting Types

private struct TrashItem: Identifiable {
    let id: UUID
    let title: String
    let type: TrashItemType
}

private enum TrashItemType {
    case bit
    case setlist
    case performance
}

// MARK: - Preview

#Preview {
    TrashcanView()
        .modelContainer(for: [Bit.self, Setlist.self, Performance.self])
}
