import Foundation
import SwiftData
import SwiftUI

@Model
final class Setlist {
    var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date

    /// Rich text stored as RTF data (like Notes exports).
    var bodyRTF: Data

    /// True = still being developed
    var isDraft: Bool

    init(title: String = "Untitled Set", bodyRTF: Data = Data(), isDraft: Bool = true) {
        self.id = UUID()
        self.title = title
        let now = Date()
        self.createdAt = now
        self.updatedAt = now
        self.bodyRTF = bodyRTF
        self.isDraft = isDraft
    }
}
import UIKit

struct SetlistDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.undoManager) private var undoManager

    @Bindable var setlist: Setlist

    var body: some View {
        VStack {
            RichTextEditor(rtfData: $setlist.bodyRTF)
                .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .navigationTitle(setlist.title)
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            // Undo
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    undoManager?.undo()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                }
                .disabled(!(undoManager?.canUndo ?? false))
                .accessibilityLabel("Undo")
            }
            // Redo
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    undoManager?.redo()
                } label: {
                    Image(systemName: "arrow.uturn.forward")
                }
                .disabled(!(undoManager?.canRedo ?? false))
                .accessibilityLabel("Redo")
            }
            // Options menu
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        duplicateSetlist()
                    } label: {
                        Label("Duplicate", systemImage: "plus.square.on.square")
                    }

                    Button {
                        copyTextToClipboard()
                    } label: {
                        Label("Copy Text", systemImage: "doc.on.doc")
                    }

                    Button(role: .destructive) {
                        deleteSetlist()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Options")
            }
        }
    }

    private func duplicateSetlist() {
        let copy = Setlist(title: setlist.title, bodyRTF: setlist.bodyRTF, isDraft: setlist.isDraft)
        modelContext.insert(copy)
        try? modelContext.save()
    }

    private func copyTextToClipboard() {
        guard let attributed = NSAttributedString.fromRTF(setlist.bodyRTF) else { return }
        UIPasteboard.general.string = attributed.string
    }

    private func deleteSetlist() {
        modelContext.delete(setlist)
        try? modelContext.save()
        dismiss()
    }
}

// Local helper for RTF decoding if not globally available
private extension NSAttributedString {
    static func fromRTF(_ data: Data) -> NSAttributedString? {
        guard !data.isEmpty else { return NSAttributedString(string: "") }
        return try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        )
    }
}

#Preview {
    // Lightweight preview with an in-memory model container
    let sample = Setlist(title: "Sample Set", bodyRTF: (NSAttributedString(string: "Hello world").rtfData() ?? Data()), isDraft: true)
    return NavigationStack {
        SetlistDetailView(setlist: sample)
    }
}

private extension NSAttributedString {
    func rtfData() -> Data? {
        try? data(
            from: NSRange(location: 0, length: length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )
    }
}

