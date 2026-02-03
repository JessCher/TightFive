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
    @State private var showStageMode = false
    @State private var showStageRehearsal = false
    @State private var showCueCardSettings = false
    @State private var showRunMode = false
    @State private var showScriptModeSettings = false
    @State private var showCustomCueCardEditor = false

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
        .sheet(isPresented: $showCueCardSettings) {
            CueCardSettingsView(setlist: setlist)
        }
        .sheet(isPresented: $showScriptModeSettings) {
            ScriptModeSettingsView(setlist: setlist)
        }
        .sheet(isPresented: $showCustomCueCardEditor) {
            CustomCueCardEditorView(setlist: setlist)
        }
        .fullScreenCover(isPresented: $showStageMode) {
            StageModeView(setlist: setlist)
        }
        .fullScreenCover(isPresented: $showStageRehearsal) {
            StageRehearsalView(setlist: setlist)
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
        VStack(spacing: 0) {
            // Script Mode Banner
            scriptModeBanner
            
            switch setlist.currentScriptMode {
            case .modular:
                modularScriptEditor
            case .traditional:
                traditionalScriptEditor
            }
        }
    }
    
    private var scriptModeBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: setlist.currentScriptMode == .modular ? "square.grid.2x2" : "doc.text")
                .font(.caption)
                .foregroundStyle(TFTheme.yellow.opacity(0.8))
            
            Text("\(setlist.currentScriptMode.displayName) Mode")
                .appFont(.caption, weight: .semibold)
                .foregroundStyle(TFTheme.yellow.opacity(0.8))
            
            Spacer()
            
            Button {
                showScriptModeSettings = true
            } label: {
                HStack(spacing: 4) {
                    Text("Change Mode")
                        .appFont(.caption2, weight: .medium)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.3))
    }
    
    private var modularScriptEditor: some View {
        ZStack(alignment: .bottomTrailing) {
            if setlist.scriptBlocks.isEmpty {
                scriptEmptyState
            } else {
                scriptBlockList
            }
            
            addContentFAB
        }
    }
    
    private var traditionalScriptEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "doc.text")
                    .foregroundStyle(TFTheme.yellow)
                Text("Write your full script here with rich text formatting")
                    .appFont(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            
            RichTextEditor(rtfData: $setlist.traditionalScriptRTF, undoManager: undoManager)
                .onChange(of: setlist.traditionalScriptRTF) { _, _ in
                    setlist.updatedAt = Date()
                }
        }
    }
    
    // MARK: - Modular Script Components
    
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
                    // Configure Cue Cards - available for both modes
                    Button {
                        showCustomCueCardEditor = true
                    } label: {
                        Label("Configure Cue Cards", systemImage: "rectangle.stack")
                    }
                    
                    Button {
                        showStageRehearsal = true
                    } label: {
                        Label("Stage Rehearsal", systemImage: "waveform")
                    }
                    
                    Button {
                        showStageMode = true
                    } label: {
                        Label("Stage Mode", systemImage: "play.fill")
                    }
                    
                    Button {
                        showCueCardSettings = true
                    } label: {
                        Label("Stage Mode Settings", systemImage: "gearshape")
                    }
                    
                    Divider()
                }
                
                // Script Mode Settings
                Button {
                    showScriptModeSettings = true
                } label: {
                    Label("Script Mode", systemImage: "doc.text.magnifyingglass")
                }
                
                Divider()
                
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

// MARK: - Script Mode Settings View

struct ScriptModeSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var setlist: Setlist
    
    @State private var selectedMode: ScriptMode
    @State private var showModeChangeWarning = false
    
    init(setlist: Setlist) {
        self.setlist = setlist
        _selectedMode = State(initialValue: setlist.currentScriptMode)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Mode Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Script Mode")
                            .appFont(.title3, weight: .semibold)
                            .foregroundStyle(TFTheme.yellow)
                            .padding(.horizontal, 4)
                        
                        ForEach(ScriptMode.allCases) { mode in
                            Button {
                                if mode != setlist.currentScriptMode {
                                    selectedMode = mode
                                    showModeChangeWarning = true
                                }
                            } label: {
                                HStack(spacing: 16) {
                                    Image(systemName: mode == .modular ? "square.grid.2x2" : "doc.text")
                                        .font(.system(size: 24))
                                        .foregroundStyle(TFTheme.yellow)
                                        .frame(width: 40)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(mode.displayName)
                                            .appFont(.headline)
                                            .foregroundStyle(.white)
                                        
                                        Text(mode.description)
                                            .appFont(.caption)
                                            .foregroundStyle(.white.opacity(0.6))
                                            .multilineTextAlignment(.leading)
                                    }
                                    
                                    Spacer()
                                    
                                    if mode == setlist.currentScriptMode {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundStyle(TFTheme.yellow)
                                    }
                                }
                                .padding(16)
                                .background(mode == setlist.currentScriptMode ? Color("TFCard") : Color("TFCard").opacity(0.6))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .strokeBorder(
                                            mode == setlist.currentScriptMode ? TFTheme.yellow.opacity(0.5) : Color("TFCardStroke").opacity(0.4),
                                            lineWidth: mode == setlist.currentScriptMode ? 2 : 1
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    // Current Mode Info
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Current Mode Features")
                            .appFont(.title3, weight: .semibold)
                            .foregroundStyle(TFTheme.yellow)
                            .padding(.horizontal, 4)
                            .padding(.top, 8)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            switch setlist.currentScriptMode {
                            case .modular:
                                featureRow(icon: "plus.square.on.square", text: "Insert bits from your library")
                                featureRow(icon: "pencil", text: "Write freeform text between bits")
                                featureRow(icon: "arrow.up.arrow.down", text: "Drag and drop to reorder")
                                featureRow(icon: "rectangle.stack", text: "Auto-generated cue cards for Stage Mode")
                                featureRow(icon: "waveform", text: "Anchor and exit phrase detection")
                            case .traditional:
                                featureRow(icon: "doc.richtext", text: "Full rich text editor with formatting")
                                featureRow(icon: "textformat", text: "Bold, italic, fonts, colors, and more")
                                featureRow(icon: "scroll", text: "Script and Teleprompter modes available")
                                featureRow(icon: "rectangle.stack", text: "Create custom cue cards (optional)")
                            }
                        }
                        .padding(16)
                        .tfDynamicCard(cornerRadius: 16)
                    }
                    
                    // Info Footer
                    VStack(spacing: 8) {
                        Text("You can switch modes at any time. Your content will be preserved.")
                            .appFont(.footnote)
                            .foregroundStyle(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                        
                        if setlist.currentScriptMode == .traditional && !setlist.hasCustomCueCards {
                            Text("⚠️ Cue Card mode is disabled until you configure custom cue cards")
                                .appFont(.footnote, weight: .medium)
                                .foregroundStyle(.orange)
                                .multilineTextAlignment(.center)
                                .padding(.top, 4)
                        }
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
            .tfBackground()
            .navigationTitle("Script Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    TFWordmarkTitle(title: "Script Mode", size: 20)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(TFTheme.yellow)
                }
            }
            .alert("Change Script Mode?", isPresented: $showModeChangeWarning) {
                Button("Cancel", role: .cancel) {
                    selectedMode = setlist.currentScriptMode
                }
                Button("Change Mode") {
                    changeScriptMode(to: selectedMode)
                }
            } message: {
                Text(modeChangeMessage)
            }
        }
    }
    
    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(TFTheme.yellow.opacity(0.8))
                .frame(width: 24)
            
            Text(text)
                .appFont(.subheadline)
                .foregroundStyle(.white.opacity(0.9))
            
            Spacer()
        }
    }
    
    private var modeChangeMessage: String {
        if selectedMode == .traditional {
            return "Switching to Traditional mode will keep your modular content but you'll edit it as a single document. Cue Cards will be disabled until you configure custom cards."
        } else {
            return "Switching to Modular mode will keep your traditional script but you'll need to restructure it into blocks."
        }
    }
    
    private func changeScriptMode(to newMode: ScriptMode) {
        // If switching from modular to traditional, copy content
        if setlist.currentScriptMode == .modular && newMode == .traditional {
            // Convert script blocks to plain RTF
            let plainText = setlist.scriptPlainText
            setlist.traditionalScriptRTF = TFRTFTheme.body(plainText)
        }
        
        // If switching from traditional to modular, create a single freeform block
        if setlist.currentScriptMode == .traditional && newMode == .modular {
            if setlist.scriptBlocks.isEmpty {
                // Create a freeform block with the traditional content
                setlist.addFreeformBlock(rtfData: setlist.traditionalScriptRTF, at: nil)
            }
        }
        
        setlist.currentScriptMode = newMode
        setlist.updatedAt = Date()
        
        // Handle Stage Mode defaults
        updateStageModeDefaults(for: newMode)
        
        try? modelContext.save()
    }
    
    private func updateStageModeDefaults(for mode: ScriptMode) {
        let cueCardSettings = CueCardSettingsStore.shared
        
        if mode == .traditional {
            // Disable cue cards unless custom cards are configured
            if !setlist.hasCustomCueCards && cueCardSettings.stageModeType == .cueCards {
                // Check if user previously set teleprompter as default
                let previousTeleprompterPreference = UserDefaults.standard.bool(forKey: "user_prefers_teleprompter")
                
                if previousTeleprompterPreference {
                    cueCardSettings.stageModeType = .teleprompter
                } else {
                    cueCardSettings.stageModeType = .script
                }
            }
        } else {
            // Modular mode: cue cards available again
            // Restore user's preference if they had one
            let previousTeleprompterPreference = UserDefaults.standard.bool(forKey: "user_prefers_teleprompter")
            if !previousTeleprompterPreference && cueCardSettings.stageModeType != .cueCards {
                // Optionally restore to cue cards if they didn't prefer teleprompter
            }
        }
    }
}

// MARK: - Custom Cue Card Editor View

struct CustomCueCardEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var setlist: Setlist
    
    @State private var customCueCards: [CustomCueCard] = []
    @State private var autoGeneratedCards: [CueCard] = []
    @State private var showAddCard = false
    @State private var editingCard: CustomCueCard?
    
    private var isModularMode: Bool {
        setlist.currentScriptMode == .modular
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Info Banner
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .foregroundStyle(TFTheme.yellow)
                            Text(isModularMode ? "Auto-Generated Cue Cards" : "Create Custom Cue Cards")
                                .appFont(.headline)
                                .foregroundStyle(.white)
                        }
                        
                        Text(isModularMode 
                            ? "These cue cards are automatically generated from your script blocks. They show exactly what you'll see in Stage Mode, including anchor and exit phrases for voice-driven advancement."
                            : "In Traditional mode, you can manually create cue cards for Stage Mode. Each card represents a section of your script with optional anchor and exit phrases for voice-driven advancement.")
                            .appFont(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(16)
                    .tfDynamicCard(cornerRadius: 16)
                    
                    // Cue Cards Display
                    if isModularMode {
                        autoGeneratedCardsView
                    } else {
                        customCardsView
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
            .tfBackground()
            .navigationTitle(isModularMode ? "Cue Cards Preview" : "Custom Cue Cards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    TFWordmarkTitle(title: isModularMode ? "Cue Cards Preview" : "Custom Cue Cards", size: 20)
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    Button(isModularMode ? "Done" : "Cancel") { 
                        if !isModularMode {
                            // Don't save for traditional mode if they tap Cancel
                        }
                        dismiss() 
                    }
                    .foregroundStyle(TFTheme.yellow)
                }
                
                if !isModularMode {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            saveCustomCueCards()
                        } label: {
                            Text("Save")
                                .fontWeight(.semibold)
                                .foregroundStyle(TFTheme.yellow)
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddCard) {
                CustomCueCardDetailView(
                    card: nil,
                    order: customCueCards.count
                ) { newCard in
                    customCueCards.append(newCard)
                    reorderCards()
                }
            }
            .sheet(item: $editingCard) { card in
                CustomCueCardDetailView(
                    card: card,
                    order: card.order
                ) { updatedCard in
                    if let index = customCueCards.firstIndex(where: { $0.id == updatedCard.id }) {
                        customCueCards[index] = updatedCard
                    }
                }
            }
            .onAppear {
                if isModularMode {
                    loadAutoGeneratedCards()
                } else {
                    loadCustomCueCards()
                }
            }
        }
    }
    
    // MARK: - Auto-Generated Cards View (Modular Mode)
    
    private var autoGeneratedCardsView: some View {
        VStack(spacing: 12) {
            if autoGeneratedCards.isEmpty {
                autoGeneratedEmptyState
            } else {
                ForEach(Array(autoGeneratedCards.enumerated()), id: \.element.id) { index, card in
                    AutoGeneratedCueCardRow(card: card, index: index)
                }
            }
        }
    }
    
    private var autoGeneratedEmptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.stack")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.3))
            
            Text("No cue cards yet")
                .appFont(.title3, weight: .semibold)
                .foregroundStyle(.white)
            
            Text("Add content to your script to see cue cards here")
                .appFont(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Custom Cards View (Traditional Mode)
    
    private var customCardsView: some View {
        VStack(spacing: 12) {
            if customCueCards.isEmpty {
                customEmptyState
            } else {
                cardsListView
            }
        }
    }
    
    private var customEmptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.stack")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.3))
            
            Text("No custom cue cards yet")
                .appFont(.title3, weight: .semibold)
                .foregroundStyle(.white)
            
            Text("Create cue cards to enable Cue Card mode in Stage Mode")
                .appFont(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
            
            Button {
                showAddCard = true
            } label: {
                Text("Create First Card")
                    .appFont(.headline)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(TFTheme.yellow)
                    .clipShape(Capsule())
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private var cardsListView: some View {
        VStack(spacing: 12) {
            // Add Card Button
            Button {
                showAddCard = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                    Text("Add Cue Card")
                        .appFont(.headline)
                    Spacer()
                }
                .foregroundStyle(TFTheme.yellow)
                .padding(16)
                .background(Color("TFCard").opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(TFTheme.yellow.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            
            // Cards
            ForEach(customCueCards) { card in
                CustomCueCardRow(card: card)
                    .onTapGesture {
                        editingCard = card
                    }
                    .contextMenu {
                        Button {
                            editingCard = card
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        
                        Button(role: .destructive) {
                            deleteCard(card)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        
                        Divider()
                        
                        if let index = customCueCards.firstIndex(where: { $0.id == card.id }) {
                            if index > 0 {
                                Button {
                                    moveCard(from: index, to: index - 1)
                                } label: {
                                    Label("Move Up", systemImage: "arrow.up")
                                }
                            }
                            
                            if index < customCueCards.count - 1 {
                                Button {
                                    moveCard(from: index, to: index + 1)
                                } label: {
                                    Label("Move Down", systemImage: "arrow.down")
                                }
                            }
                        }
                    }
            }
            .onMove { source, destination in
                customCueCards.move(fromOffsets: source, toOffset: destination)
                reorderCards()
            }
            .onDelete { indices in
                customCueCards.remove(atOffsets: indices)
                reorderCards()
            }
        }
    }
    
    private func loadCustomCueCards() {
        customCueCards = setlist.customCueCards
    }
    
    private func loadAutoGeneratedCards() {
        autoGeneratedCards = CueCard.extractCards(from: setlist)
    }
    
    private func saveCustomCueCards() {
        // Save cards to setlist
        setlist.customCueCards = customCueCards
        setlist.hasCustomCueCards = !customCueCards.isEmpty
        setlist.updatedAt = Date()
        
        // Re-enable cue cards in Stage Mode if cards exist
        if setlist.hasCustomCueCards {
            let cueCardSettings = CueCardSettingsStore.shared
            if cueCardSettings.stageModeType == .script {
                // Offer to switch back to cue cards
                cueCardSettings.stageModeType = .cueCards
            }
        }
        
        try? modelContext.save()
        dismiss()
    }
    
    private func deleteCard(_ card: CustomCueCard) {
        customCueCards.removeAll { $0.id == card.id }
        reorderCards()
    }
    
    private func moveCard(from: Int, to: Int) {
        let card = customCueCards.remove(at: from)
        customCueCards.insert(card, at: to)
        reorderCards()
    }
    
    private func reorderCards() {
        for (index, _) in customCueCards.enumerated() {
            customCueCards[index].order = index
        }
    }
}

// MARK: - Custom Cue Card Detail View

struct CustomCueCardDetailView: View {
    @Environment(\.dismiss) private var dismiss
    
    let card: CustomCueCard?
    let order: Int
    let onSave: (CustomCueCard) -> Void
    
    @State private var content: String = ""
    @State private var anchorPhrase: String = ""
    @State private var exitPhrase: String = ""
    @State private var showValidationError = false
    @State private var validationMessage = ""
    
    @FocusState private var focusedField: Field?
    
    enum Field {
        case content, anchor, exit
    }
    
    init(card: CustomCueCard?, order: Int, onSave: @escaping (CustomCueCard) -> Void) {
        self.card = card
        self.order = order
        self.onSave = onSave
        
        _content = State(initialValue: card?.content ?? "")
        _anchorPhrase = State(initialValue: card?.anchorPhrase ?? "")
        _exitPhrase = State(initialValue: card?.exitPhrase ?? "")
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Card Content
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Card Content")
                                .appFont(.headline)
                                .foregroundStyle(.white)
                            
                            Spacer()
                            
                            Text("Required")
                                .appFont(.caption2, weight: .medium)
                                .foregroundStyle(.orange.opacity(0.8))
                        }
                        
                        Text("The text that will be displayed on this cue card during performance")
                            .appFont(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                        
                        TextEditor(text: $content)
                            .appFont(.body)
                            .foregroundStyle(.white)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 150)
                            .padding(12)
                            .background(Color.black.opacity(0.3))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(focusedField == .content ? TFTheme.yellow.opacity(0.5) : Color("TFCardStroke").opacity(0.4), lineWidth: 1)
                            )
                            .focused($focusedField, equals: .content)
                    }
                    .padding(16)
                    .tfDynamicCard(cornerRadius: 16)
                    
                    // Anchor Phrase
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.right.circle.fill")
                                    .foregroundStyle(.green)
                                Text("Anchor Phrase")
                                    .appFont(.headline)
                                    .foregroundStyle(.white)
                            }
                            
                            Spacer()
                            
                            Text("Optional")
                                .appFont(.caption2, weight: .medium)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        
                        Text("A phrase at the beginning of this card that the system can recognize to confirm you're at the right place")
                            .appFont(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                        
                        TextField("e.g., \"So I was at the store...\"", text: $anchorPhrase)
                            .appFont(.body)
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.3))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(focusedField == .anchor ? TFTheme.yellow.opacity(0.5) : Color("TFCardStroke").opacity(0.4), lineWidth: 1)
                            )
                            .focused($focusedField, equals: .anchor)
                    }
                    .padding(16)
                    .tfDynamicCard(cornerRadius: 16)
                    
                    // Exit Phrase
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.forward.circle.fill")
                                    .foregroundStyle(.orange)
                                Text("Exit Phrase")
                                    .appFont(.headline)
                                    .foregroundStyle(.white)
                            }
                            
                            Spacer()
                            
                            Text("Optional")
                                .appFont(.caption2, weight: .medium)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        
                        Text("The final phrase of this card that triggers auto-advance to the next card")
                            .appFont(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                        
                        TextField("e.g., \"...and that's the story!\"", text: $exitPhrase)
                            .appFont(.body)
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.3))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(focusedField == .exit ? TFTheme.yellow.opacity(0.5) : Color("TFCardStroke").opacity(0.4), lineWidth: 1)
                            )
                            .focused($focusedField, equals: .exit)
                    }
                    .padding(16)
                    .tfDynamicCard(cornerRadius: 16)
                    
                    // Tips
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundStyle(TFTheme.yellow.opacity(0.8))
                            Text("Tips")
                                .appFont(.headline)
                                .foregroundStyle(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            tipRow(icon: "mic.fill", text: "Keep phrases 4-8 words for best voice recognition")
                            tipRow(icon: "text.quote", text: "Use distinctive phrases, not common words")
                            tipRow(icon: "waveform", text: "Test phrases in Stage Mode to verify recognition")
                        }
                    }
                    .padding(16)
                    .background(Color("TFCard").opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
            .tfBackground()
            .navigationTitle(card == nil ? "New Cue Card" : "Edit Cue Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(TFTheme.yellow)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveCard()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(TFTheme.yellow)
                    .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("Validation Error", isPresented: $showValidationError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(validationMessage)
            }
        }
    }
    
    private func tipRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(TFTheme.yellow.opacity(0.6))
                .frame(width: 20)
            
            Text(text)
                .appFont(.caption)
                .foregroundStyle(.white.opacity(0.7))
            
            Spacer()
        }
    }
    
    private func saveCard() {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Validate
        guard !trimmedContent.isEmpty else {
            validationMessage = "Card content is required"
            showValidationError = true
            return
        }
        
        // Create or update card
        let savedCard = CustomCueCard(
            id: card?.id ?? UUID(),
            content: trimmedContent,
            anchorPhrase: anchorPhrase.isEmpty ? nil : anchorPhrase,
            exitPhrase: exitPhrase.isEmpty ? nil : exitPhrase,
            order: card?.order ?? order
        )
        
        onSave(savedCard)
        dismiss()
    }
}

struct CustomCueCardRow: View {
    let card: CustomCueCard
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Card \(card.order + 1)")
                    .appFont(.caption, weight: .semibold)
                    .foregroundStyle(TFTheme.yellow.opacity(0.8))
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
            }
            
            Text(card.content)
                .appFont(.body)
                .foregroundStyle(.white)
                .lineLimit(3)
            
            if let anchor = card.anchorPhrase, !anchor.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.green)
                    Text("Anchor: \(anchor)")
                        .appFont(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            
            if let exit = card.exitPhrase, !exit.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.forward.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                    Text("Exit: \(exit)")
                        .appFont(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .padding(16)
        .tfDynamicCard(cornerRadius: 16)
    }
}

struct AutoGeneratedCueCardRow: View {
    let card: CueCard
    let index: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Card \(index + 1)")
                    .appFont(.caption, weight: .semibold)
                    .foregroundStyle(TFTheme.yellow.opacity(0.8))
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "wand.and.stars")
                        .font(.caption2)
                        .foregroundStyle(.blue.opacity(0.7))
                    Text("Auto-Generated")
                        .appFont(.caption2, weight: .medium)
                        .foregroundStyle(.blue.opacity(0.7))
                }
            }
            
            Text(card.fullText)
                .appFont(.body)
                .foregroundStyle(.white)
                .lineLimit(5)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.green)
                    Text("Anchor:")
                        .appFont(.caption2, weight: .semibold)
                        .foregroundStyle(.white.opacity(0.5))
                    Text(card.anchorPhrase)
                        .appFont(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(2)
                }
                
                HStack(spacing: 6) {
                    Image(systemName: "arrow.forward.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                    Text("Exit:")
                        .appFont(.caption2, weight: .semibold)
                        .foregroundStyle(.white.opacity(0.5))
                    Text(card.exitPhrase)
                        .appFont(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(2)
                }
            }
            .padding(.top, 4)
        }
        .padding(16)
        .tfDynamicCard(cornerRadius: 16)
    }
}



