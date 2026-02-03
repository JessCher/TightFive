import SwiftUI
import SwiftUI
import Foundation
import SwiftData
import UIKit

/// The Setlist Builder - a performance script editor with modular bit insertion.
///
/// **Architecture:**
/// - Script Tab: The blended performance document (freeform + bits) - uses PlainTextEditor
/// - Notes Tab: Auxiliary notes (delivery ideas, reminders) - uses RichTextEditor for formatting
/// - Bit Drawer: Available bits to insert into the script
///
/// **Key Features:**
/// - Insert bits from drawer into script
/// - Freeform writing between bits (plain text)
/// - Drag & drop reordering
/// - Inline editing with full undo/redo support
/// - Rich text formatting available in Notes tab only
struct SetlistBuilderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.undoManager) private var undoManager

    @Bindable var setlist: Setlist
    
    enum Tab: String, CaseIterable {
        case script = "Script"
        case notes = "Notes"
    }
    
    @State private var selectedTab: Tab = .script
    @State private var showBitDrawer = false
    @State private var editingBlockId: UUID?
    @State private var insertionIndex: Int?
    
    // Stage Mode
    @State private var showAnchorEditor = false
    @State private var showStageMode = false
    @State private var showCueCardSettings = false
    @State private var showRunMode = false

    @ObservedObject private var keyboard = TFKeyboardState.shared
    
    @State private var showCopyChoice = false
    @State private var exportItems: [Any] = []
    @State private var showShareSheet = false
    
    @State private var showExportChoice = false
    @State private var exportURL: URL?
    
    var body: some View {
        VStack(spacing: 0) {
            titleField
            tabPicker
            Divider().opacity(0.25)
            
            switch selectedTab {
            case .script:
                scriptEditor
            case .notes:
                notesEditor
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar { toolbarContent }
        .tfBackground()
        .onAppear { setlist.migrateToScriptBlocksIfNeeded() }
        .sheet(isPresented: $showBitDrawer) {
            BitDrawerSheet(setlist: setlist, insertionIndex: insertionIndex) { bit, index in
                insertBit(bit, at: index)
            }
        }
        .sheet(isPresented: $showAnchorEditor) {
            StageAnchorEditorView(setlist: setlist)
        }
        .sheet(isPresented: $showCueCardSettings) {
            CueCardSettingsView()
        }
        .fullScreenCover(isPresented: $showStageMode) {
            StageModeView(setlist: setlist)
        }
        .fullScreenCover(isPresented: $showRunMode) {
            RunModeView(setlist: setlist)
        }
        .confirmationDialog("Copy", isPresented: $showCopyChoice, titleVisibility: .visible) {
            Button("Copy Script") { copyScriptToClipboard() }
            Button("Copy Notes") { copyNotesToClipboard() }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Export", isPresented: $showExportChoice, titleVisibility: .visible) {
            Button("Export Script") { exportSetlist(as: .script) }
            Button("Export Notes") { exportSetlist(as: .notes) }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(item: $exportURL) { url in
            ShareSheet(items: [url]) { _ in }
        }
    }
    
    // MARK: - Title Field
    
    private var titleField: some View {
        TextField("Set title", text: $setlist.title)
            .appFont(.title2, weight: .semibold)
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)
            .onChange(of: setlist.title) { _, _ in
                setlist.updatedAt = Date()
            }
    }
    
    // MARK: - Tab Picker
    
    private var tabPicker: some View {
        Picker("View", selection: $selectedTab) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
    
    // MARK: - Script Editor
    
    private var scriptEditor: some View {
        ZStack(alignment: .bottomTrailing) {
            if setlist.scriptBlocks.isEmpty {
                scriptEmptyState
            } else {
                scriptBlockList
            }
            
            addContentFAB
        }
    }
    
    private var scriptEmptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "doc.text")
                .font(.system(size: 56))
                .foregroundStyle(.white.opacity(0.25))
            
            Text("Start Your Script")
                .appFont(.title3, weight: .semibold)
                .foregroundStyle(.white)
            
            Text("Add bits from your library or write\ntransitions and tags directly.")
                .appFont(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
            
            HStack(spacing: 16) {
                Button {
                    insertionIndex = 0
                    showBitDrawer = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "tray.and.arrow.down")
                        Text("Add Bit")
                    }
                    .appFont(.headline)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(TFTheme.yellow)
                    .clipShape(Capsule())
                }
                
                Button {
                    addFreeformBlock(at: 0)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "pencil")
                        Text("Write")
                    }
                    .appFont(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color("TFCard"))
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(Color("TFCardStroke").opacity(0.6), lineWidth: 1))
                }
            }
            .padding(.top, 8)
            
            Spacer()
        }
    }
    
    private var scriptBlockList: some View {
        // Pre-compute assignment lookup for O(1) access instead of O(n) per block
        let lookup = setlist.assignmentLookup
        return List {
            ForEach(Array(setlist.scriptBlocks.enumerated()), id: \.element.id) { index, block in
                ScriptBlockRowView(
                    block: block,
                    assignment: block.assignmentId.flatMap { lookup[$0] },
                    isEditing: editingBlockId == block.id,
                    onStartEdit: { editingBlockId = block.id },
                    onEndEdit: { rtfData in
                        // For freeform blocks only
                        if block.isFreeform {
                            setlist.updateFreeformBlock(id: block.id, rtfData: rtfData)
                        }
                        editingBlockId = nil
                    },
                    onInsertAbove: {
                        insertionIndex = index
                        showBitDrawer = true
                    },
                    onAddTextAbove: {
                        addFreeformBlock(at: index)
                    }
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            }
            .onMove { source, destination in
                setlist.moveBlocks(from: source, to: destination)
            }
            .onDelete { indices in
                for index in indices.sorted().reversed() {
                    setlist.removeBlock(at: index, context: modelContext)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
    
    private var addContentFAB: some View {
        Menu {
            Button {
                insertionIndex = setlist.scriptBlocks.count
                showBitDrawer = true
            } label: {
                Label("Insert Bit", systemImage: "tray.and.arrow.down")
            }
            
            Button {
                addFreeformBlock(at: setlist.scriptBlocks.count)
            } label: {
                Label("Add Text Block", systemImage: "pencil")
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 56, height: 56)
                .background(TFTheme.yellow)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 20)
    }
    
    // MARK: - Notes Editor
    
    private var notesEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb")
                    .foregroundStyle(TFTheme.yellow)
                Text("Any riff ideas? Any moments for crowd work? Any notes you want to leave about your delivery? Work it all out here, this is the space to plan your performance")
                    .appFont(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            
            RichTextEditor(rtfData: $setlist.notesRTF, undoManager: undoManager)
                .onChange(of: setlist.notesRTF) { _, _ in
                    setlist.updatedAt = Date()
                }
        }
    }
    
    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Done") {
                try? modelContext.save()
                dismiss()
            }
            .foregroundStyle(TFTheme.yellow)
        }
        
        ToolbarItem(placement: .topBarTrailing) {
            if keyboard.isVisible {
                TFUndoRedoControls()
            } else {
                EmptyView()
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            if setlist.hasScriptContent {
                Button {
                    showRunMode = true
                } label: {
                    Image(systemName: "timer")
                        .foregroundStyle(TFTheme.yellow)
                }
            }
        }
        
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                if setlist.hasScriptContent && !setlist.isDraft {
                    Button {
                        showStageMode = true
                    } label: {
                        Label("Stage Mode", systemImage: "play.fill")
                    }
                    
                    Button {
                        showAnchorEditor = true
                    } label: {
                        Label("Configure Anchors", systemImage: "waveform")
                    }
                    
                    Button {
                        showCueCardSettings = true
                    } label: {
                        Label("Stage Mode Settings", systemImage: "gearshape")
                    }
                    
                    Divider()
                }
                
                Button {
                    setlist.isDraft = true
                    setlist.updatedAt = Date()
                } label: {
                    Label("Mark In Progress", systemImage: "hammer")
                }
                
                Button {
                    setlist.isDraft = false
                    setlist.updatedAt = Date()
                } label: {
                    Label("Mark Finished", systemImage: "checkmark.seal")
                }
                
                Divider()
                
                // Export
                Button {
                    showExportChoice = true
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                
                // Duplicate
                Button {
                    duplicateSetlist()
                } label: {
                    Label("Duplicate", systemImage: "plus.square.on.square")
                }
                
                // Copy
                Button {
                    showCopyChoice = true
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                
                Divider()
                
                Button(role: .destructive) {
                    setlist.softDelete()
                    try? modelContext.save()
                    dismiss()
                } label: {
                    Label("Delete Setlist", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(TFTheme.yellow)
            }
        }
    }
    
    // MARK: - Actions
    
    private func insertBit(_ bit: Bit, at index: Int?) {
        setlist.insertBit(bit, at: index, context: modelContext)
        try? modelContext.save()
    }
    
    private func addFreeformBlock(at index: Int?) {
        setlist.addFreeformBlock(rtfData: TFRTFTheme.body(""), at: index)
        if let idx = index ?? (setlist.scriptBlocks.count - 1) as Int?,
           idx < setlist.scriptBlocks.count {
            editingBlockId = setlist.scriptBlocks[idx].id
        }
    }
    
    private enum ExportKind { case script, notes }

    private func exportSetlist(as kind: ExportKind) {
        let text: String
        switch kind {
        case .script:
            text = setlist.exportPlainText()
        case .notes:
            text = NSAttributedString.fromRTF(setlist.notesRTF)?.string ?? ""
        }
        let filenameBase = setlist.title.isEmpty ? "Setlist" : setlist.title
        let safe = filenameBase.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(safe).txt")
        do {
            try text.data(using: .utf8)?.write(to: url, options: .atomic)
            exportURL = url
        } catch {
            print("Export failed: \(error)")
            exportURL = nil
        }
    }
    
    private func duplicateSetlist() {
        let clone = setlist.duplicate()
        clone.updatedAt = Date()
        try? modelContext.save()
    }
    
    private func copyScriptToClipboard() {
        let plain = setlist.exportPlainText()
        UIPasteboard.general.string = plain
    }
    
    private func copyNotesToClipboard() {
        let notes = NSAttributedString.fromRTF(setlist.notesRTF)?.string ?? ""
        UIPasteboard.general.string = notes
    }
}

// MARK: - Script Block Row

private struct ScriptBlockRowView: View {
    @Environment(\.modelContext) private var modelContext
    
    let block: ScriptBlock
    let assignment: SetlistAssignment?
    let isEditing: Bool
    let onStartEdit: () -> Void
    let onEndEdit: (Data) -> Void
    let onInsertAbove: () -> Void
    let onAddTextAbove: () -> Void
    
    var setlist: Setlist? {
        assignment?.setlist
    }

    @State private var editText: String = ""
    @State private var showVariationNote = false
    @State private var variationNote = ""
    @FocusState private var isFocused: Bool
    @Environment(\.undoManager) private var undoManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch block {
            case .freeform(_, let rtfData):
                freeformContent(rtfData: rtfData)
            case .bit:
                bitContent
            }
        }
        .contextMenu {
            Button { onInsertAbove() } label: {
                Label("Insert Bit Above", systemImage: "tray.and.arrow.down")
            }
            Button { onAddTextAbove() } label: {
                Label("Add Text Above", systemImage: "pencil")
            }
        }
    }
    
    private func freeformContent(rtfData: Data) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "pencil.circle.fill")
                    .appFont(.caption)
                    .foregroundStyle(.white.opacity(0.4))
                Text("FREEFORM")
                    .appFont(.caption2, weight: .bold)
                    .foregroundStyle(.white.opacity(0.4))
                    .kerning(1)
            }
            
            if isEditing {
                PlainTextEditor(text: $editText, undoManager: undoManager)
                    .frame(minHeight: 140)
                    .padding(6)
                    .background(Color.black.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .onAppear {
                        // Convert RTF to plain text for editing
                        editText = NSAttributedString.fromRTF(rtfData)?.string ?? ""
                    }
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") {
                                // Convert plain text back to RTF
                                let rtf = TFRTFTheme.body(editText)
                                onEndEdit(rtf)
                                isFocused = false
                            }
                            .foregroundStyle(TFTheme.yellow)
                        }
                    }
                    .onChange(of: isFocused) { oldValue, newValue in
                        if oldValue == true && newValue == false {
                            let rtf = TFRTFTheme.body(editText)
                            onEndEdit(rtf)
                        }
                    }
                    .onDisappear {
                        // Fallback commit in case the row disappears while editing
                        let rtf = TFRTFTheme.body(editText)
                        onEndEdit(rtf)
                    }
            } else {
                let plain = NSAttributedString.fromRTF(rtfData)?.string ?? ""
                Text(plain.isEmpty ? "Tap to write..." : plain)
                    .appFont(.body)
                    .foregroundStyle(plain.isEmpty ? .white.opacity(0.4) : .white.opacity(0.9))
                    .italic(plain.isEmpty)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture { onStartEdit() }
            }
        }
        .padding(14)
        .background(Color("TFCard").opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color("TFCardStroke").opacity(0.4), lineWidth: 1)
        )
    }
    
    private var bitContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let assignment = assignment {
                HStack(spacing: 6) {
                    Image(systemName: "doc.text.fill")
                        .appFont(.caption)
                        .foregroundStyle(TFTheme.yellow.opacity(0.8))
                    Text("BIT")
                        .appFont(.caption2, weight: .bold)
                        .foregroundStyle(TFTheme.yellow.opacity(0.8))
                        .kerning(1)
                    
                    Spacer()
                    
                    Text(assignment.bitTitleSnapshot)
                        .appFont(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                    
                    if assignment.isModified {
                        Image(systemName: "pencil.circle.fill")
                            .appFont(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                
                if isEditing {
                    VStack(alignment: .leading, spacing: 8) {
                        PlainTextEditor(text: $editText, undoManager: undoManager)
                            .frame(minHeight: 140)
                            .padding(6)
                            .background(Color.black.opacity(0.3))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .onAppear {
                                // Convert RTF to plain text for editing
                                editText = assignment.plainText
                            }
                        
                        Button {
                            showVariationNote = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "note.text")
                                    .appFont(.caption)
                                Text(variationNote.isEmpty ? "Add variation note (optional)" : variationNote)
                                    .appFont(.caption)
                                    .lineLimit(1)
                            }
                            .foregroundStyle(.white.opacity(0.6))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.3))
                            .clipShape(Capsule())
                        }
                    }
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") {
                                saveVariation()
                            }
                            .foregroundStyle(TFTheme.yellow)
                        }
                    }
                    .alert("Variation Note", isPresented: $showVariationNote) {
                        TextField("What changed?", text: $variationNote)
                        Button("Cancel", role: .cancel) {}
                        Button("Save") {}
                    } message: {
                        Text("Add a note about what you changed in this version (e.g., 'tightened tag', 'new opener')")
                    }
                    .onChange(of: isFocused) { oldValue, newValue in
                        if oldValue == true && newValue == false {
                            saveVariation()
                        }
                    }
                    .onDisappear {
                        saveVariation()
                    }
                } else {
                    Text(assignment.plainText)
                        .appFont(.body)
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onStartEdit()
                        }
                }
            } else {
                Text("Bit not found")
                    .appFont(.body)
                    .foregroundStyle(.red.opacity(0.7))
            }
        }
        .padding(14)
        .background(Color("TFCard"))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(TFTheme.yellow.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func saveVariation() {
        guard let assignment = assignment,
              let setlist = setlist else {
            // Convert plain text back to RTF for freeform blocks
            let rtf = TFRTFTheme.body(editText)
            onEndEdit(rtf)
            return
        }
        
        // Convert plain text to RTF
        let newRTF = TFRTFTheme.body(editText)
        
        // Check if text actually changed
        guard newRTF != assignment.performedRTF else {
            onEndEdit(newRTF)
            return
        }
        
        // Create variation and update assignment
        setlist.commitVariation(
            for: assignment,
            newRTF: newRTF,
            note: variationNote.isEmpty ? nil : variationNote,
            context: modelContext
        )
        
        variationNote = ""
        onEndEdit(newRTF)
    }
}

// MARK: - Bit Drawer Sheet

private struct BitDrawerSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let setlist: Setlist
    let insertionIndex: Int?
    let onInsert: (Bit, Int?) -> Void
    
    // Filter out deleted bits at the query level for immediate UI updates
    @Query(
        filter: #Predicate<Bit> { !$0.isDeleted },
        sort: \Bit.updatedAt,
        order: .reverse
    ) private var allBits: [Bit]

    @State private var searchQuery = ""
    @State private var debouncedSearchQuery = ""
    @State private var showAllBits = false
    @State private var isMultiSelectMode = false
    @State private var selectedBits: Set<UUID> = []

    /// Cached filtered bits - uses debounced query to avoid filtering on every keystroke
    private var filteredBits: [Bit] {
        var bits = allBits
        if !showAllBits {
            bits = bits.filter { $0.status == .finished }
        }
        let q = debouncedSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if !q.isEmpty {
            bits = bits.filter { bit in
                bit.text.localizedCaseInsensitiveContains(q)
                || bit.title.localizedCaseInsensitiveContains(q)
                || bit.tags.contains(where: { $0.localizedCaseInsensitiveContains(q) })
            }
        }
        return bits
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter picker
                Picker("Filter", selection: $showAllBits) {
                    Text("Finished").tag(false)
                    Text("All Bits").tag(true)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
                
                Divider().opacity(0.25)
                
                if filteredBits.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(filteredBits) { bit in
                                BitDrawerRowView(
                                    bit: bit,
                                    isInSetlist: setlist.containsBit(withId: bit.id),
                                    isMultiSelectMode: isMultiSelectMode,
                                    isSelected: selectedBits.contains(bit.id)
                                ) {
                                    if isMultiSelectMode {
                                        toggleSelection(bit)
                                    } else {
                                        onInsert(bit, insertionIndex)
                                        dismiss()
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
            }
            .navigationTitle("Insert Bit")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchQuery, prompt: "Search by text or tag")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isMultiSelectMode ? "Cancel" : "Close") {
                        if isMultiSelectMode {
                            isMultiSelectMode = false
                            selectedBits.removeAll()
                        } else {
                            dismiss()
                        }
                    }
                    .foregroundStyle(TFTheme.yellow)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    if !filteredBits.isEmpty {
                        if isMultiSelectMode {
                            Button {
                                insertSelectedBits()
                            } label: {
                                Text("Add (\(selectedBits.count))")
                                    .foregroundStyle(TFTheme.yellow)
                            }
                            .disabled(selectedBits.isEmpty)
                        } else {
                            Button {
                                isMultiSelectMode = true
                            } label: {
                                Image(systemName: "checkmark.circle")
                                    .foregroundStyle(TFTheme.yellow)
                            }
                        }
                    }
                }
            }
            .tfBackground()
            .task(id: searchQuery) {
                // Debounce search query to avoid filtering on every keystroke
                try? await Task.sleep(for: .milliseconds(150))
                guard !Task.isCancelled else { return }
                debouncedSearchQuery = searchQuery
            }
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
            Text(showAllBits ? "Create some bits first." : "Mark bits as Finished when ready.")
                .appFont(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
            Spacer()
        }
    }
    
    private func toggleSelection(_ bit: Bit) {
        if selectedBits.contains(bit.id) {
            selectedBits.remove(bit.id)
        } else {
            selectedBits.insert(bit.id)
        }
    }
    
    private func insertSelectedBits() {
        let bitsToInsert = filteredBits.filter { selectedBits.contains($0.id) }
        var currentIndex = insertionIndex
        
        for bit in bitsToInsert {
            onInsert(bit, currentIndex)
            if let index = currentIndex {
                currentIndex = index + 1
            }
        }
        
        dismiss()
    }
}

private struct BitDrawerRowView: View {
    let bit: Bit
    let isInSetlist: Bool
    let isMultiSelectMode: Bool
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Multi-select checkbox or status icon
                if isMultiSelectMode {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24))
                        .foregroundStyle(isSelected ? TFTheme.yellow : .white.opacity(0.3))
                        .frame(width: 28)
                } else {
                    Image(systemName: bit.status == .finished ? "checkmark.seal.fill" : "pencil.circle")
                        .font(.system(size: 20))
                        .foregroundStyle(bit.status == .finished ? TFTheme.yellow : .white.opacity(0.5))
                        .frame(width: 28)
                }
                
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
                        
                        // Show tags if any
                        if !bit.tags.isEmpty {
                            ForEach(bit.tags.prefix(2), id: \.self) { tag in
                                Text(tag)
                                    .appFont(.caption2, weight: .medium)
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(TFTheme.yellow.opacity(0.6))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                
                Spacer()
                
                // Show + icon or nothing in multi-select mode
                if !isMultiSelectMode {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(TFTheme.yellow)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(isSelected && isMultiSelectMode ? Color("TFCard").opacity(0.7) : Color("TFCard"))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(
                        isSelected && isMultiSelectMode ? TFTheme.yellow.opacity(0.6) : Color("TFCardStroke").opacity(0.6),
                        lineWidth: isSelected && isMultiSelectMode ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let setlist = Setlist(title: "Friday Night Set")
    return SetlistBuilderView(setlist: setlist)
}

// MARK: - Setlist Extensions
extension Setlist {
    func exportPlainText() -> String {
        var lines: [String] = []
        for block in scriptBlocks {
            switch block {
            case .freeform(_, let rtf):
                let text = NSAttributedString.fromRTF(rtf)?.string ?? ""
                if !text.isEmpty { lines.append(text) }
            case .bit:
                if let assignment = assignment(for: block) {
                    let text = NSAttributedString.fromRTF(assignment.performedRTF)?.string ?? ""
                    if !text.isEmpty { lines.append(text) }
                }
            }
        }
        return lines.joined(separator: "\n\n")
    }

    func duplicate() -> Setlist {
        let copy = Setlist(title: self.title + " Copy")
        copy.isDraft = self.isDraft
        copy.notesRTF = self.notesRTF
        // Duplicate blocks and assignments
        for block in self.scriptBlocks {
            switch block {
            case .freeform(_, let rtf):
                copy.addFreeformBlock(rtfData: rtf, at: nil)
            case .bit:
                if let assign = self.assignment(for: block) {
                    // Preserve performed content when duplicating even if we can't re-link the Bit here.
                    copy.addFreeformBlock(rtfData: assign.performedRTF, at: nil)
                }
            }
        }
        return copy
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    var completion: ((Bool) -> Void)?

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, _ in
            completion?(completed)
        }
        return controller
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// Allow using URL with .sheet(item:)
extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}
