import SwiftUI
import SwiftData
import UIKit

private enum NotebookFolderFilter: Hashable {
    case allNotes
    case unfiled
    case folder(UUID)
}

/// Main Notebook page displaying all notes as collapsed cards sorted by creation date.
///
/// **Architecture:**
/// - Notes display as collapsed cards showing title + content preview
/// - Folder chips at the top provide quick filtering
/// - Swipe right to move to folder, swipe left to delete
/// - "Create New Note" button in the header
struct NotebookView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<Note> { note in
        !note.isDeleted
    }, sort: \Note.createdAt, order: .reverse) private var allNotes: [Note]

    @Query(sort: [SortDescriptor(\NoteFolder.sortOrder), SortDescriptor(\NoteFolder.createdAt)])
    private var folders: [NoteFolder]

    @State private var selectedFolderFilter: NotebookFolderFilter = .allNotes

    @State private var selectedNote: Note?
    @State private var showDeleteConfirmation = false
    @State private var noteToDelete: Note?

    @State private var noteToMove: Note?

    @State private var showCreateFolderPrompt = false
    @State private var newFolderTitle = ""

    @State private var folderToRename: NoteFolder?
    @State private var renamedFolderTitle = ""

    @State private var folderToDelete: NoteFolder?
    @State private var showDeleteFolderConfirmation = false

    private var filteredNotes: [Note] {
        switch selectedFolderFilter {
        case .allNotes:
            return allNotes
        case .unfiled:
            return allNotes.filter { $0.folder == nil }
        case .folder(let folderID):
            return allNotes.filter { $0.folder?.id == folderID }
        }
    }

    private var folderNoteCounts: [UUID: Int] {
        var counts: [UUID: Int] = [:]
        for note in allNotes {
            if let folderID = note.folder?.id {
                counts[folderID, default: 0] += 1
            }
        }
        return counts
    }

    private var unfiledCount: Int {
        allNotes.filter { $0.folder == nil }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            folderFilterBar

            ScrollView {
                LazyVStack(spacing: 12) {
                    if filteredNotes.isEmpty {
                        emptyState
                            .padding(.top, 60)
                    } else {
                        ForEach(filteredNotes) { note in
                            CardSwipeView(
                                swipeRightEnabled: true,
                                swipeRightIcon: "folder.fill",
                                swipeRightColor: .blue,
                                swipeRightLabel: "Move",
                                swipeLeftIcon: "trash.fill",
                                swipeLeftColor: .red,
                                swipeLeftLabel: "Delete",
                                onSwipeRight: {
                                    noteToMove = note
                                },
                                onSwipeLeft: {
                                    noteToDelete = note
                                    showDeleteConfirmation = true
                                },
                                onTap: { selectedNote = note }
                            ) {
                                NoteCardView(
                                    note: note,
                                    folderTitle: note.folder?.displayTitle ?? "Unfiled"
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
        }
        .tfBackground()
        .navigationTitle("Notebook")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedNote) { note in
            NoteEditorView(note: note)
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                TFWordmarkTitle(title: "Note book", size: 22)
                    .offset(x: -3)
            }

            ToolbarItem(placement: .topBarLeading) {
                Button {
                    newFolderTitle = ""
                    showCreateFolderPrompt = true
                } label: {
                    Image(systemName: "folder.badge.plus")
                        .appFont(size: 16, weight: .bold)
                        .foregroundStyle(TFTheme.yellow)
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.10))
                        .clipShape(Circle())
                        .overlay(
                            Circle().stroke(Color("TFCardStroke").opacity(0.9), lineWidth: 1)
                        )
                }
                .accessibilityLabel("Add Folder")
                .accessibilityHint("Create a new notebook folder")
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
        .sheet(item: $noteToMove) { note in
            NoteFolderPickerSheet(
                noteTitle: note.displayTitle,
                folders: folders,
                currentFolderID: note.folder?.id
            ) { folder in
                assign(note: note, to: folder)
            }
        }
        .alert("Delete Note?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                if let note = noteToDelete {
                    withAnimation(.snappy) {
                        note.softDelete(context: modelContext)
                    }
                    // Save after animation completes
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        try? modelContext.save()
                    }
                }
                noteToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                noteToDelete = nil
            }
        } message: {
            Text("This note will be moved to the trash.")
        }
        .alert("New Folder", isPresented: $showCreateFolderPrompt) {
            TextField("Folder name", text: $newFolderTitle)
            Button("Create") {
                createFolder()
            }
            Button("Cancel", role: .cancel) {
                newFolderTitle = ""
            }
        } message: {
            Text("Create a folder to organize your notes.")
        }
        .alert("Rename Folder", isPresented: renameFolderPromptBinding) {
            TextField("Folder name", text: $renamedFolderTitle)
            Button("Save") {
                renameFolder()
            }
            Button("Cancel", role: .cancel) {
                folderToRename = nil
                renamedFolderTitle = ""
            }
        } message: {
            Text("Choose a new folder name.")
        }
        .alert("Delete Folder?", isPresented: $showDeleteFolderConfirmation, presenting: folderToDelete) { folder in
            Button("Delete", role: .destructive) {
                deleteFolder(folder)
            }
            Button("Cancel", role: .cancel) {
                folderToDelete = nil
            }
        } message: { folder in
            let count = folderNoteCounts[folder.id, default: 0]
            Text("\(count) notes will be moved to Unfiled.")
        }
        .onChange(of: folders.map(\.id)) { _, ids in
            guard case .folder(let selectedID) = selectedFolderFilter else { return }
            if !ids.contains(selectedID) {
                selectedFolderFilter = .allNotes
            }
        }
    }

    private var folderFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FolderFilterChip(
                    title: "All Notes",
                    count: allNotes.count,
                    isSelected: selectedFolderFilter == .allNotes
                ) {
                    selectedFolderFilter = .allNotes
                }

                FolderFilterChip(
                    title: "Unfiled",
                    count: unfiledCount,
                    isSelected: selectedFolderFilter == .unfiled
                ) {
                    selectedFolderFilter = .unfiled
                }

                ForEach(folders) { folder in
                    FolderFilterChip(
                        title: folder.displayTitle,
                        count: folderNoteCounts[folder.id, default: 0],
                        isSelected: selectedFolderFilter == .folder(folder.id)
                    ) {
                        selectedFolderFilter = .folder(folder.id)
                    }
                    .contextMenu {
                        Button {
                            folderToRename = folder
                            renamedFolderTitle = folder.displayTitle
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            folderToDelete = folder
                            showDeleteFolderConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 4)
        }
    }

    private var renameFolderPromptBinding: Binding<Bool> {
        Binding(
            get: { folderToRename != nil },
            set: { isPresented in
                if !isPresented {
                    folderToRename = nil
                    renamedFolderTitle = ""
                }
            }
        )
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "book.closed")
                .font(.system(size: 36))
                .foregroundStyle(TFTheme.text.opacity(0.4))
                .accessibilityHidden(true)

            Text(emptyStateTitle)
                .appFont(.title3, weight: .semibold)
                .foregroundStyle(TFTheme.text)

            Text(emptyStateMessage)
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
            .accessibilityHint("Create a new note")
        }
        .accessibilityElement(children: .contain)
    }

    private var emptyStateTitle: String {
        switch selectedFolderFilter {
        case .allNotes:
            return "No notes yet"
        case .unfiled:
            return "No unfiled notes"
        case .folder(let folderID):
            return folders.first(where: { $0.id == folderID }) == nil ? "Folder not found" : "Folder is empty"
        }
    }

    private var emptyStateMessage: String {
        switch selectedFolderFilter {
        case .allNotes:
            return "Tap + to start writing. Jot down thoughts, ideas, or anything creative."
        case .unfiled:
            return "Notes that are not assigned to a folder appear here."
        case .folder(let folderID):
            if let folder = folders.first(where: { $0.id == folderID }) {
                return "\(folder.displayTitle) has no notes yet. Create one with +."
            }
            return "This folder no longer exists."
        }
    }

    private func createNewNote() {
        let note = Note(folder: selectedFolder())
        modelContext.insert(note)

        do {
            try modelContext.save()
            selectedNote = note
        } catch {
            print("❌ Failed to save new note: \(error)")
        }
    }

    private func selectedFolder() -> NoteFolder? {
        guard case .folder(let folderID) = selectedFolderFilter else {
            return nil
        }
        return folders.first(where: { $0.id == folderID })
    }

    private func assign(note: Note, to folder: NoteFolder?) {
        note.folder = folder
        note.updatedAt = Date()
        try? modelContext.save()
    }

    private func createFolder() {
        let trimmed = newFolderTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let nextSortOrder = (folders.map(\.sortOrder).max() ?? -1) + 1
        let folder = NoteFolder(title: trimmed, sortOrder: nextSortOrder)

        modelContext.insert(folder)
        try? modelContext.save()

        newFolderTitle = ""
        selectedFolderFilter = .folder(folder.id)
    }

    private func renameFolder() {
        guard let folder = folderToRename else { return }
        let trimmed = renamedFolderTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        folder.title = trimmed
        folder.updatedAt = Date()
        try? modelContext.save()

        folderToRename = nil
        renamedFolderTitle = ""
    }

    private func deleteFolder(_ folder: NoteFolder) {
        for note in allNotes where note.folder?.id == folder.id {
            note.folder = nil
            note.updatedAt = Date()
        }

        if selectedFolderFilter == .folder(folder.id) {
            selectedFolderFilter = .allNotes
        }

        reindexFolders(excluding: folder.id)
        modelContext.delete(folder)
        try? modelContext.save()

        folderToDelete = nil
    }

    private func reindexFolders(excluding folderID: UUID) {
        let remaining = folders
            .filter { $0.id != folderID }
            .sorted {
                if $0.sortOrder == $1.sortOrder {
                    return $0.createdAt < $1.createdAt
                }
                return $0.sortOrder < $1.sortOrder
            }

        for (index, folder) in remaining.enumerated() where folder.sortOrder != index {
            folder.sortOrder = index
            folder.updatedAt = Date()
        }
    }
}

// MARK: - Note Card View

/// Collapsed card for a note, showing title + content preview.
/// Matches the visual style of Bit cards (tfDynamicCard).
struct NoteCardView: View {
    let note: Note
    let folderTitle: String

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
                Label(folderTitle, systemImage: "folder")
                    .appFont(.caption)
                    .foregroundStyle(TFTheme.text.opacity(0.50))
                    .lineLimit(1)

                Text("•")
                    .appFont(.caption)
                    .foregroundStyle(TFTheme.text.opacity(0.35))

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
        .accessibilityLabel("\(note.displayTitle), folder \(folderTitle)\(note.hasContent ? ", \(note.contentPreview)" : "")")
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

    @Query(sort: [SortDescriptor(\NoteFolder.sortOrder), SortDescriptor(\NoteFolder.createdAt)])
    private var folders: [NoteFolder]

    // Export state
    @State private var showExportFormatChoice = false
    @State private var exportURL: IdentifiableURL?
    @State private var showDeleteConfirmation = false
    @State private var showFolderPicker = false

    private enum ExportFormat: String { case txt, pdf, rtf, markdown }

    private struct IdentifiableURL: Identifiable {
        let id = UUID()
        let url: URL
    }

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
            RichTextEditor(rtfData: $note.contentRTF)
                .onChange(of: note.contentRTF) { _, _ in
                    note.updatedAt = Date()
                }
                .padding(12)
                .background(Color.black.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)
        }
        .tfBackground()
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
                    Button {
                        showFolderPicker = true
                    } label: {
                        Label("Move to Folder", systemImage: "folder")
                    }

                    Divider()

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
        .sheet(item: $exportURL) { identifiable in
            ShareSheet(items: [identifiable.url]) { _ in }
        }
        .sheet(isPresented: $showFolderPicker) {
            NoteFolderPickerSheet(
                noteTitle: note.displayTitle,
                folders: folders,
                currentFolderID: note.folder?.id
            ) { folder in
                note.folder = folder
                note.updatedAt = Date()
                try? modelContext.save()
            }
        }
        .alert("Delete Note?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                note.softDelete(context: modelContext)
                // Save after a brief delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    try? modelContext.save()
                }
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
            exportURL = IdentifiableURL(url: url)
        } catch {
            print("Export failed: \(error)")
            exportURL = nil
        }
    }

    private func duplicateNote() {
        let clone = Note(title: note.title + " Copy", contentRTF: note.contentRTF, folder: note.folder)
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

private struct FolderFilterChip: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Text(title)
                    .appFont(.subheadline, weight: .semibold)
                    .lineLimit(1)

                Text("\(count)")
                    .appFont(.caption, weight: .bold)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(isSelected ? Color.black.opacity(0.25) : Color.white.opacity(0.12))
                    .clipShape(Capsule())
            }
            .foregroundStyle(isSelected ? .black : TFTheme.text)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? TFTheme.yellow : Color.white.opacity(0.08))
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(Color("TFCardStroke").opacity(isSelected ? 0 : 0.9), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct NoteFolderPickerSheet: View {
    let noteTitle: String
    let folders: [NoteFolder]
    let currentFolderID: UUID?
    let onSelect: (NoteFolder?) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Choose Folder") {
                    folderRow(title: "Unfiled", systemImage: "tray", isSelected: currentFolderID == nil) {
                        onSelect(nil)
                        dismiss()
                    }

                    ForEach(folders) { folder in
                        folderRow(
                            title: folder.displayTitle,
                            systemImage: "folder",
                            isSelected: currentFolderID == folder.id
                        ) {
                            onSelect(folder)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Move Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(noteTitle)
                        .appFont(.headline, weight: .semibold)
                        .lineLimit(1)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(TFTheme.yellow)
                }
            }
            .scrollContentBackground(.hidden)
            .tfBackground()
        }
    }

    private func folderRow(title: String, systemImage: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .foregroundStyle(TFTheme.yellow)
                    .frame(width: 18)

                Text(title)
                    .foregroundStyle(.white)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(TFTheme.yellow)
                }
            }
        }
    }
}
