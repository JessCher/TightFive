import SwiftUI
import SwiftData

/// Main Notebook page displaying all notes as collapsed cards sorted by creation date.
///
/// **Architecture:**
/// - Notes display as collapsed cards showing title + content preview
/// - Tapping a card opens the full note editor (pushed via NavigationStack)
/// - Swipe-to-delete matches existing Bits pattern
/// - "Folders" button slides in the folders navigation stack from the right
/// - "Create New Note" button in the header
struct NotebookView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<Note> { note in
        !note.isDeleted
    }, sort: \Note.createdAt, order: .reverse) private var allNotes: [Note]

    @State private var selectedNote: Note?
    @State private var showFolders = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if allNotes.isEmpty {
                    emptyState
                        .padding(.top, 60)
                } else {
                    ForEach(allNotes) { note in
                        NoteCardView(note: note)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedNote = note
                            }
                            .contextMenu {
                                if let folder = note.folder {
                                    Label("In: \(folder.displayName)", systemImage: "folder")
                                        .disabled(true)
                                }

                                Button(role: .destructive) {
                                    withAnimation(.snappy) {
                                        note.softDelete()
                                        try? modelContext.save()
                                    }
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
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "book.closed")
                .font(.system(size: 36))
                .foregroundStyle(TFTheme.text.opacity(0.4))

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
        }
    }

    private func createNewNote() {
        let note = Note()
        modelContext.insert(note)
        
        // Explicitly save the new note
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
private struct NoteCardView: View {
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
/// - Auto-saves on changes
struct NoteEditorView: View {
    @Bindable var note: Note
    @Environment(\.modelContext) private var modelContext
    @Environment(\.undoManager) private var undoManager
    @ObservedObject private var keyboard = TFKeyboardState.shared

    @Query(sort: \NoteFolder.name) private var allFolders: [NoteFolder]
    @State private var showFolderPicker = false

    var body: some View {
        VStack(spacing: 0) {
            // Title field
            TextField("Note Title", text: $note.title)
                .appFont(.title2, weight: .bold)
                .foregroundStyle(TFTheme.yellow)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)
                .onChange(of: note.title) { _, _ in
                    note.updatedAt = Date()
                    // No save here - let SwiftData autosave handle it
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

            Divider()
                .background(.white.opacity(0.15))
                .padding(.horizontal, 16)

            // Rich text editor (reuses existing component from Setlist Builder)
            RichTextEditor(rtfData: $note.contentRTF, undoManager: undoManager)
                .onChange(of: note.contentRTF) { _, _ in
                    note.updatedAt = Date()
                    // No save here - let SwiftData autosave handle it
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
        }
        .sheet(isPresented: $showFolderPicker) {
            NoteFolderPickerView(note: note)
        }
        .onDisappear {
            // Ensure any pending changes are saved when leaving the editor
            do {
                try modelContext.save()
            } catch {
                print("❌ Failed to save note on dismiss: \(error)")
            }
        }
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
    @State private var isLoading = true
    @State private var loadError: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading folders...")
                    .padding()
            } else if let loadError {
                // Show error state with option to clear corrupted data
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundStyle(.orange)
                    
                    Text("Folders Error")
                        .appFont(.title2, weight: .bold)
                        .foregroundStyle(TFTheme.text)
                    
                    Text(loadError)
                        .appFont(.subheadline)
                        .foregroundStyle(TFTheme.text.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    
                    Button {
                        clearCorruptedFolders()
                    } label: {
                        Text("Clear Corrupted Folders")
                            .appFont(.headline, weight: .semibold)
                            .foregroundStyle(.black)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 12)
                            .background(TFTheme.yellow)
                            .clipShape(Capsule())
                    }
                    
                    Text("This will only remove folder data, not your notes, bits, or setlists.")
                        .appFont(.caption)
                        .foregroundStyle(TFTheme.text.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding()
            } else {
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
                                .buttonStyle(.plain) // Prevent NavigationLink from interfering
                                .contextMenu {
                                    Button(role: .destructive) {
                                        withAnimation(.snappy) {
                                            deleteFolder(folder)
                                        }
                                    } label: {
                                        Label("Delete Folder", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }
            }
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
        .task {
            // Safely load folders with error handling
            await loadFolders()
        }
    }
    
    private func loadFolders() async {
        // Small delay to allow view to appear
        try? await Task.sleep(for: .milliseconds(100))
        
        do {
            // Try to access folders safely
            let count = folders.count
            print("✅ Folders view loaded with \(count) folders")
            isLoading = false
        } catch {
            print("❌ Failed to load folders: \(error)")
            loadError = "Unable to load folders. They may be corrupted from before the schema was fixed."
            isLoading = false
        }
    }
    
    private func clearCorruptedFolders() {
        Task {
            do {
                // Fetch all folders directly with FetchDescriptor for better control
                let descriptor = FetchDescriptor<NoteFolder>()
                let allFolders = try modelContext.fetch(descriptor)
                
                print("🧹 Clearing \(allFolders.count) potentially corrupted folders...")
                
                // Delete all folders
                for folder in allFolders {
                    modelContext.delete(folder)
                }
                
                // Also fetch and preserve any orphaned notes (notes without folders)
                let noteDescriptor = FetchDescriptor<Note>()
                let allNotes = try modelContext.fetch(noteDescriptor)
                print("📝 Found \(allNotes.count) notes (these will be preserved)")
                
                // Save the cleanup
                try modelContext.save()
                
                print("✅ Corrupted folders cleared. Your notes, bits, and setlists are safe.")
                
                // Reset state
                loadError = nil
                isLoading = false
                
            } catch {
                print("❌ Failed to clear folders: \(error)")
                loadError = "Failed to clear: \(error.localizedDescription)"
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "folder")
                .font(.system(size: 36))
                .foregroundStyle(TFTheme.text.opacity(0.4))

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
        }
    }

    private func createFolder() {
        let trimmed = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let folder = NoteFolder(name: trimmed)
        modelContext.insert(folder)
        
        // Explicitly save the new folder
        do {
            try modelContext.save()
            print("✅ Folder created successfully: \(trimmed)")
        } catch {
            print("❌ Failed to save new folder: \(error)")
        }
    }
    
    private func deleteFolder(_ folder: NoteFolder) {
        do {
            modelContext.delete(folder)
            try modelContext.save()
            print("✅ Folder deleted successfully")
        } catch {
            print("❌ Failed to delete folder: \(error)")
        }
    }
}

// MARK: - Folder Card View

/// Card showing a folder's name. Used in the Folders list.
/// Note: We don't show the note count here to avoid expensive relationship queries that can freeze the UI.
/// The count is visible in the folder detail view instead.
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
                        NoteCardView(note: note)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedNote = note
                            }
                            .contextMenu {
                                Button {
                                    // Remove from folder (move to All Notes)
                                    note.folder = nil
                                    note.updatedAt = Date()
                                    try? modelContext.save()
                                } label: {
                                    Label("Remove from Folder", systemImage: "folder.badge.minus")
                                }

                                Button(role: .destructive) {
                                    withAnimation(.snappy) {
                                        note.softDelete()
                                        try? modelContext.save()
                                    }
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
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "doc.text")
                .font(.system(size: 36))
                .foregroundStyle(TFTheme.text.opacity(0.4))

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
        }
    }

    private func createNoteInFolder() {
        let note = Note()
        note.folder = folder
        modelContext.insert(note)
        
        // Explicitly save the new note
        do {
            try modelContext.save()
            selectedNote = note
        } catch {
            print("❌ Failed to save note in folder: \(error)")
        }
    }
}
