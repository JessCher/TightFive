import SwiftUI
import SwiftData
import UIKit

/// Main Notebook page displaying all notes as collapsed cards sorted by creation date.
///
/// **Architecture:**
/// - Notes display as collapsed cards showing title + content preview
/// - Tapping a card opens the full note editor (pushed via NavigationStack)
/// - Swipe left to delete, swipe right to add to folder (matches CardSwipeView style)
/// - "Folders" button slides in the folders navigation stack from the right
/// - "Create New Note" button in the header
struct NotebookView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<Note> { note in
        !note.isDeleted
    }, sort: \Note.createdAt, order: .reverse) private var allNotes: [Note]

    @State private var selectedNote: Note?
    @State private var showFolders = false
    @State private var showDeleteConfirmation = false
    @State private var noteToDelete: Note?
    @State private var noteForFolderPicker: Note?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if allNotes.isEmpty {
                    emptyState
                        .padding(.top, 60)
                } else {
                    ForEach(allNotes) { note in
                        CardSwipeView(
                            swipeRightEnabled: true,
                            swipeRightIcon: "folder.badge.plus",
                            swipeRightColor: TFTheme.yellow,
                            swipeRightLabel: "Folder",
                            swipeLeftIcon: "trash.fill",
                            swipeLeftColor: .red,
                            swipeLeftLabel: "Delete",
                            onSwipeRight: {
                                noteForFolderPicker = note
                            },
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
        .navigationDestination(isPresented: $showFolders) {
            NoteFoldersView()
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                TFWordmarkTitle(title: "Notebook", size: 22)
                    .offset(x: -6)
            }

            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showFolders = true
                } label: {
                    Image(systemName: "folder")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(TFTheme.yellow)
                        .frame(width: 40, height: 40)
                }
                .accessibilityLabel("Folders")
                .accessibilityHint("Open folder management")
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
        .sheet(item: $noteForFolderPicker) { note in
            NoteFolderPickerView(note: note)
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

                if let folder = note.folder {
                    Text("\u{2022}")
                        .appFont(.caption)
                        .foregroundStyle(TFTheme.text.opacity(0.3))

                    HStack(spacing: 4) {
                        Image(systemName: "folder")
                            .appFont(.caption2)
                            .foregroundStyle(TFTheme.yellow)
                        Text(folder.displayName)
                            .appFont(.caption)
                            .foregroundStyle(TFTheme.text.opacity(0.45))
                    }
                }
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
/// - Folder assignment via dropdown
/// - Export/Duplicate/Copy menu (matches Setlist Builder)
/// - Auto-saves on changes
struct NoteEditorView: View {
    @Bindable var note: Note
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.undoManager) private var undoManager
    @ObservedObject private var keyboard = TFKeyboardState.shared

    @Query(sort: \NoteFolder.name) private var allFolders: [NoteFolder]
    @State private var showFolderPicker = false

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

            // Folder indicator
            Button {
                showFolderPicker = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "folder")
                        .appFont(.caption)
                        .foregroundStyle(TFTheme.yellow)

                    Text(note.folder?.displayName ?? "No Folder")
                        .appFont(.subheadline)
                        .foregroundStyle(TFTheme.text.opacity(0.6))

                    Image(systemName: "chevron.right")
                        .appFont(.caption2)
                        .foregroundStyle(TFTheme.text.opacity(0.3))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }
            .accessibilityLabel("Folder: \(note.folder?.displayName ?? "None")")
            .accessibilityHint("Tap to change folder")

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
        .sheet(isPresented: $showFolderPicker) {
            NoteFolderPickerView(note: note)
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
        clone.folder = note.folder
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

// MARK: - Folder Picker

/// Sheet for assigning a note to a folder (or removing folder assignment).
private struct NoteFolderPickerView: View {
    @Bindable var note: Note
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \NoteFolder.name) private var allFolders: [NoteFolder]

    var body: some View {
        NavigationStack {
            List {
                // "No Folder" option
                Button {
                    note.folder = nil
                    note.updatedAt = Date()
                    try? modelContext.save()
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "tray")
                            .foregroundStyle(TFTheme.text.opacity(0.5))
                        Text("No Folder")
                            .foregroundStyle(TFTheme.text)
                        Spacer()
                        if note.folder == nil {
                            Image(systemName: "checkmark")
                                .foregroundStyle(TFTheme.yellow)
                        }
                    }
                }
                .accessibilityLabel("No Folder")
                .accessibilityHint(note.folder == nil ? "Currently selected" : "Remove from folder")

                // Folder options
                ForEach(allFolders) { folder in
                    Button {
                        note.folder = folder
                        note.updatedAt = Date()
                        try? modelContext.save()
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "folder.fill")
                                .foregroundStyle(TFTheme.yellow)
                            Text(folder.displayName)
                                .foregroundStyle(TFTheme.text)
                            Spacer()
                            if note.folder?.id == folder.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(TFTheme.yellow)
                            }
                        }
                    }
                    .accessibilityLabel(folder.displayName)
                    .accessibilityHint(note.folder?.id == folder.id ? "Currently selected" : "Move note to this folder")
                }
            }
            .scrollContentBackground(.hidden)
            .tfBackground()
            .navigationTitle("Move to Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(TFTheme.yellow)
                }
            }
        }
    }
}

// MARK: - Folders View

/// Lists all user-created folders with note counts.
/// Pushed via NavigationStack from the main Notebook page.
struct NoteFoldersView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \NoteFolder.name) private var folders: [NoteFolder]

    @State private var showCreateFolder = false
    @State private var newFolderName = ""

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if folders.isEmpty {
                    emptyState
                        .padding(.top, 60)
                } else {
                    ForEach(folders) { folder in
                        NavigationLink(value: folder) {
                            FolderCardView(folder: folder)
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(folder.displayName) folder")
                        .accessibilityHint("Opens folder to view notes")
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .tfBackground()
        .navigationTitle("Folders")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: NoteFolder.self) { folder in
            FolderDetailView(folder: folder)
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                TFWordmarkTitle(title: "Folders", size: 22)
                    .offset(x: -6)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    newFolderName = ""
                    showCreateFolder = true
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
                .accessibilityLabel("New Folder")
                .accessibilityHint("Create a new folder")
            }
        }
        .alert("New Folder", isPresented: $showCreateFolder) {
            TextField("Folder Name", text: $newFolderName)
            Button("Create") {
                createFolder()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter a name for the new folder.")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "folder")
                .font(.system(size: 36))
                .foregroundStyle(TFTheme.text.opacity(0.4))
                .accessibilityHidden(true)

            Text("No folders yet")
                .appFont(.title3, weight: .semibold)
                .foregroundStyle(TFTheme.text)

            Text("Create folders to organize your notes by topic or project.")
                .appFont(.subheadline)
                .foregroundStyle(TFTheme.text.opacity(0.65))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 26)

            Button {
                newFolderName = ""
                showCreateFolder = true
            } label: {
                Text("Create Folder")
                    .appFont(.headline, weight: .semibold)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(TFTheme.yellow)
                    .clipShape(Capsule())
            }
            .padding(.top, 6)
            .accessibilityLabel("Create Folder")
        }
        .accessibilityElement(children: .contain)
    }

    private func createFolder() {
        let trimmed = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let folder = NoteFolder(name: trimmed)
        modelContext.insert(folder)

        do {
            try modelContext.save()
        } catch {
            print("❌ Failed to save new folder: \(error)")
        }
    }

    private func deleteFolder(_ folder: NoteFolder) {
        do {
            modelContext.delete(folder)
            try modelContext.save()
        } catch {
            print("❌ Failed to delete folder: \(error)")
        }
    }
}

// MARK: - Folder Card View

/// Card showing a folder's name. Used in the Folders list.
private struct FolderCardView: View {
    let folder: NoteFolder

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "folder.fill")
                .font(.system(size: 24))
                .foregroundStyle(TFTheme.yellow)

            VStack(alignment: .leading, spacing: 4) {
                Text(folder.displayName)
                    .appFont(.headline, weight: .semibold)
                    .foregroundStyle(TFTheme.text)

                Text(folder.createdAt, style: .date)
                    .appFont(.caption)
                    .foregroundStyle(TFTheme.text.opacity(0.45))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .appFont(.caption)
                .foregroundStyle(TFTheme.text.opacity(0.3))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .tfDynamicCard(cornerRadius: 18)
    }
}

// MARK: - Folder Detail View

/// Shows all notes in a specific folder with edit/delete options.
struct FolderDetailView: View {
    @Bindable var folder: NoteFolder
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedNote: Note?
    @State private var showEditName = false
    @State private var editedName = ""
    @State private var showDeleteConfirmation = false
    @State private var showDeleteNoteConfirmation = false
    @State private var noteToDelete: Note?

    /// Active (non-deleted) notes in this folder, sorted by creation date
    private var folderNotes: [Note] {
        (folder.notes ?? [])
            .filter { !$0.isDeleted }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if folderNotes.isEmpty {
                    emptyState
                        .padding(.top, 60)
                } else {
                    ForEach(folderNotes) { note in
                        CardSwipeView(
                            swipeRightEnabled: true,
                            swipeRightIcon: "folder.badge.minus",
                            swipeRightColor: TFTheme.yellow,
                            swipeRightLabel: "Remove",
                            swipeLeftIcon: "trash.fill",
                            swipeLeftColor: .red,
                            swipeLeftLabel: "Delete",
                            onSwipeRight: {
                                note.folder = nil
                                note.updatedAt = Date()
                                try? modelContext.save()
                            },
                            onSwipeLeft: {
                                noteToDelete = note
                                showDeleteNoteConfirmation = true
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
        .navigationTitle(folder.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedNote) { note in
            NoteEditorView(note: note)
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                TFWordmarkTitle(title: folder.displayName, size: 22)
                    .offset(x: -6)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        editedName = folder.name
                        showEditName = true
                    } label: {
                        Label("Edit Folder Name", systemImage: "pencil")
                    }

                    Button {
                        createNoteInFolder()
                    } label: {
                        Label("New Note in Folder", systemImage: "plus")
                    }

                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete Folder", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(TFTheme.yellow)
                        .frame(width: 40, height: 40)
                }
                .accessibilityLabel("Folder options")
            }
        }
        .alert("Rename Folder", isPresented: $showEditName) {
            TextField("Folder Name", text: $editedName)
            Button("Save") {
                let trimmed = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                folder.name = trimmed
                try? modelContext.save()
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Delete Folder?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                modelContext.delete(folder)
                try? modelContext.save()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete the folder and all \(folderNotes.count) note\(folderNotes.count == 1 ? "" : "s") inside it.")
        }
        .alert("Delete Note?", isPresented: $showDeleteNoteConfirmation) {
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
            Image(systemName: "doc.text")
                .font(.system(size: 36))
                .foregroundStyle(TFTheme.text.opacity(0.4))
                .accessibilityHidden(true)

            Text("No notes in this folder")
                .appFont(.title3, weight: .semibold)
                .foregroundStyle(TFTheme.text)

            Text("Create a new note or move existing notes here.")
                .appFont(.subheadline)
                .foregroundStyle(TFTheme.text.opacity(0.65))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 26)

            Button {
                createNoteInFolder()
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
            .accessibilityHint("Create a note in this folder")
        }
        .accessibilityElement(children: .contain)
    }

    private func createNoteInFolder() {
        let note = Note()
        note.folder = folder
        modelContext.insert(note)

        do {
            try modelContext.save()
            selectedNote = note
        } catch {
            print("❌ Failed to save note in folder: \(error)")
        }
    }
}
