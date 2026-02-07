import SwiftUI
import SwiftData
import UIKit

/// Main Notebook page displaying all notes as collapsed cards sorted by creation date.
///
/// **Architecture:**
/// - Notes display as collapsed cards showing title + content preview
/// - Tapping a card opens the full note editor (pushed via NavigationStack)
/// - Swipe left to delete
/// - "Create New Note" button in the header
struct NotebookView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<Note> { note in
        !note.isDeleted
    }, sort: \Note.createdAt, order: .reverse) private var allNotes: [Note]

    @State private var selectedNote: Note?
    @State private var showDeleteConfirmation = false
    @State private var noteToDelete: Note?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if allNotes.isEmpty {
                    emptyState
                        .padding(.top, 60)
                } else {
                    ForEach(allNotes) { note in
                        CardSwipeView(
                            swipeRightEnabled: false,
                            swipeRightIcon: "",
                            swipeRightColor: .clear,
                            swipeRightLabel: "",
                            swipeLeftIcon: "trash.fill",
                            swipeLeftColor: .red,
                            swipeLeftLabel: "Delete",
                            onSwipeRight: {},
                            onSwipeLeft: {
                                noteToDelete = note
                                showDeleteConfirmation = true
                            },
                            onTap: { selectedNote = note }
                        ) {
                            NoteCardView(note: note)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .tfBackground()
        .navigationTitle("Notebook")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedNote) { note in
            NoteEditorView(note: note)
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                TFWordmarkTitle(title: "Notebook", size: 22)
                    .offset(x: -6)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    createNewNote()
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
                .accessibilityLabel("New Note")
                .accessibilityHint("Create a new note")
            }
        }
        .alert("Delete Note?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                if let note = noteToDelete {
                    withAnimation(.snappy) {
                        note.softDelete()
                        try? modelContext.save()
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This note will be moved to the trash.")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "book.closed")
                .font(.system(size: 36))
                .foregroundStyle(TFTheme.text.opacity(0.4))
                .accessibilityHidden(true)

            Text("No notes yet")
                .appFont(.title3, weight: .semibold)
                .foregroundStyle(TFTheme.text)

            Text("Tap + to start writing. Jot down thoughts, ideas, or anything creative.")
                .appFont(.subheadline)
                .foregroundStyle(TFTheme.text.opacity(0.65))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 26)

            Button {
                createNewNote()
            } label: {
                Text("New Note")
                    .appFont(.headline, weight: .semibold)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(TFTheme.yellow)
                    .clipShape(Capsule())
            }
            .padding(.top, 6)
            .accessibilityLabel("New Note")
            .accessibilityHint("Create your first note")
        }
        .accessibilityElement(children: .contain)
    }

    private func createNewNote() {
        let note = Note()
        modelContext.insert(note)

        do {
            try modelContext.save()
            selectedNote = note
        } catch {
            print("❌ Failed to save new note: \(error)")
        }
    }
}

// MARK: - Note Card View

/// Collapsed card for a note, showing title + content preview.
/// Matches the visual style of Bit cards (tfDynamicCard).
struct NoteCardView: View {
    let note: Note

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title
            Text(note.displayTitle)
                .appFont(.headline, weight: .semibold)
                .foregroundStyle(TFTheme.text)
                .lineLimit(2)

            // Content preview
            if note.hasContent {
                Text(note.contentPreview)
                    .appFont(.subheadline)
                    .foregroundStyle(TFTheme.text.opacity(0.65))
                    .lineLimit(3)
            }

            // Metadata row
            HStack(spacing: 8) {
                Text(note.createdAt, style: .date)
                    .appFont(.caption)
                    .foregroundStyle(TFTheme.text.opacity(0.45))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .tfDynamicCard(cornerRadius: 18)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(note.displayTitle)\(note.hasContent ? ", \(note.contentPreview)" : "")")
        .accessibilityHint("Tap to edit note")
    }
}

// MARK: - Note Editor View

/// Full note editor that opens when a card is tapped.
/// Reuses the existing RichTextEditor component (same as Setlist Builder Notes).
///
/// **Features:**
/// - Title input at the top
/// - Rich text editor for note content
/// - Export/Duplicate/Copy menu (matches Setlist Builder)
/// - Auto-saves on changes
struct NoteEditorView: View {
    @Bindable var note: Note
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.undoManager) private var undoManager
    @ObservedObject private var keyboard = TFKeyboardState.shared

    // Export state
    @State private var showExportFormatChoice = false
    @State private var exportURL: URL?
    @State private var showDeleteConfirmation = false

    private enum ExportFormat: String { case txt, pdf, rtf, markdown }

    var body: some View {
        VStack(spacing: 0) {
            // Title field
            TextField("Note Title", text: $note.title)
                .appFont(.title2, weight: .bold)
                .foregroundStyle(TFTheme.yellow)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)
                .accessibilityLabel("Note title")
                .onChange(of: note.title) { _, _ in
                    note.updatedAt = Date()
                }

            Divider()
                .background(.white.opacity(0.15))
                .padding(.horizontal, 16)

            // Rich text editor (reuses existing component from Setlist Builder)
            RichTextEditor(rtfData: $note.contentRTF, undoManager: undoManager)
                .onChange(of: note.contentRTF) { _, _ in
                    note.updatedAt = Date()
                }
                .padding(.horizontal, 8)
        }
        .tfBackground()
        .tfUndoRedoToolbar(isVisible: keyboard.isVisible)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(note.displayTitle)
                    .appFont(.headline, weight: .semibold)
                    .foregroundStyle(TFTheme.text)
                    .lineLimit(1)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    // Export
                    Button {
                        showExportFormatChoice = true
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }

                    // Duplicate
                    Button {
                        duplicateNote()
                    } label: {
                        Label("Duplicate", systemImage: "plus.square.on.square")
                    }

                    // Copy
                    Button {
                        copyNoteToClipboard()
                    } label: {
                        Label("Copy Content", systemImage: "doc.on.doc")
                    }

                    Divider()

                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete Note", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(TFTheme.yellow)
                }
                .accessibilityLabel("Note options")
            }
        }
        .confirmationDialog("Choose Format", isPresented: $showExportFormatChoice, titleVisibility: .visible) {
            Button("Plain Text (.txt)") { exportNote(format: .txt) }
            Button("PDF (.pdf)") { exportNote(format: .pdf) }
            Button("Rich Text (.rtf)") { exportNote(format: .rtf) }
            Button("Markdown (.md)") { exportNote(format: .markdown) }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(item: $exportURL) { url in
            ShareSheet(items: [url]) { _ in }
        }
        .alert("Delete Note?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                note.softDelete()
                try? modelContext.save()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This note will be moved to the trash.")
        }
        .onDisappear {
            do {
                try modelContext.save()
            } catch {
                print("❌ Failed to save note on dismiss: \(error)")
            }
        }
    }

    // MARK: - Export

    private func exportNote(format: ExportFormat) {
        let plainText = noteContentAsPlainText()
        let rtfData = note.contentRTF

        let filenameBase = note.title.isEmpty ? "Note" : note.title
        let safe = filenameBase
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
            .replacingOccurrences(of: ":", with: "-")

        do {
            let url: URL
            switch format {
            case .txt:
                url = FileManager.default.temporaryDirectory.appendingPathComponent("\(safe).txt")
                try plainText.data(using: .utf8)?.write(to: url, options: .atomic)
            case .pdf:
                url = FileManager.default.temporaryDirectory.appendingPathComponent("\(safe).pdf")
                let pdfData = ExportHelpers.generatePDF(title: note.displayTitle, body: plainText)
                try pdfData.write(to: url, options: .atomic)
            case .rtf:
                url = FileManager.default.temporaryDirectory.appendingPathComponent("\(safe).rtf")
                if let noteAttr = NSAttributedString.fromRTF(rtfData),
                   let normalizedData = ExportHelpers.normalizeRTFColors(noteAttr) {
                    try normalizedData.write(to: url, options: .atomic)
                } else {
                    let attributed = NSAttributedString(string: plainText, attributes: [
                        .font: UIFont.systemFont(ofSize: 14),
                        .foregroundColor: UIColor.black
                    ])
                    let data = try attributed.data(
                        from: NSRange(location: 0, length: attributed.length),
                        documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
                    )
                    try data.write(to: url, options: .atomic)
                }
            case .markdown:
                url = FileManager.default.temporaryDirectory.appendingPathComponent("\(safe).md")
                let md = "# \(note.displayTitle)\n\n\(plainText)"
                try md.data(using: .utf8)?.write(to: url, options: .atomic)
            }
            exportURL = url
        } catch {
            print("Export failed: \(error)")
            exportURL = nil
        }
    }

    private func duplicateNote() {
        let clone = Note(title: note.title + " Copy", contentRTF: note.contentRTF)
        modelContext.insert(clone)
        try? modelContext.save()
    }

    private func copyNoteToClipboard() {
        UIPasteboard.general.string = noteContentAsPlainText()
    }

    private func noteContentAsPlainText() -> String {
        NSAttributedString.fromRTF(note.contentRTF)?.string ?? ""
    }
}

