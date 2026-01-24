import SwiftUI
import SwiftData

/// The Setlist Builder - a performance script editor with modular bit insertion.
///
/// **Architecture:**
/// - Script Tab: The blended performance document (freeform + bits)
/// - Notes Tab: Auxiliary notes (delivery ideas, reminders) - NOT for performance
/// - Bit Drawer: Available bits to insert into the script
///
/// **Key Features:**
/// - Insert bits from drawer into script
/// - Freeform writing between bits
/// - Drag & drop reordering
/// - Inline editing
struct SetlistBuilderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
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
    @State private var showRunMode = false
    
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
        .fullScreenCover(isPresented: $showStageMode) {
            StageModeView(setlist: setlist)
        }
        .fullScreenCover(isPresented: $showRunMode) {
            RunModeView(setlist: setlist)
        }
    }
    
    // MARK: - Title Field
    
    private var titleField: some View {
        TextField("Set title", text: $setlist.title)
            .font(.title2.weight(.semibold))
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
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
            
            Text("Add bits from your library or write\ntransitions and tags directly.")
                .font(.subheadline)
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
                    .font(.headline)
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
                    .font(.headline)
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
        List {
            ForEach(Array(setlist.scriptBlocks.enumerated()), id: \.element.id) { index, block in
                ScriptBlockRowView(
                    block: block,
                    assignment: setlist.assignment(for: block),
                    isEditing: editingBlockId == block.id,
                    onStartEdit: { editingBlockId = block.id },
                    onEndEdit: { text in
                        setlist.updateFreeformBlock(id: block.id, text: text)
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
                Text("Auxiliary notes - not shown in performance modes")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            
            RichTextEditor(rtfData: $setlist.notesRTF)
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
        
        ToolbarItem(placement: .principal) {
            TFWordmarkTitle(title: "Setlist", size: 22)
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
                
                Button(role: .destructive) {
                    modelContext.delete(setlist)
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
        setlist.addFreeformBlock(text: "", at: index)
        if let idx = index ?? (setlist.scriptBlocks.count - 1) as Int?,
           idx < setlist.scriptBlocks.count {
            editingBlockId = setlist.scriptBlocks[idx].id
        }
    }
}

// MARK: - Script Block Row

private struct ScriptBlockRowView: View {
    let block: ScriptBlock
    let assignment: SetlistAssignment?
    let isEditing: Bool
    let onStartEdit: () -> Void
    let onEndEdit: (String) -> Void
    let onInsertAbove: () -> Void
    let onAddTextAbove: () -> Void
    
    @State private var editText: String = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch block {
            case .freeform(_, let text):
                freeformContent(text: text)
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
    
    private func freeformContent(text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "pencil.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
                Text("FREEFORM")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.4))
                    .kerning(1)
            }
            
            if isEditing {
                TextEditor(text: $editText)
                    .scrollContentBackground(.hidden)
                    .font(.body)
                    .foregroundStyle(.white)
                    .frame(minHeight: 100)
                    .padding(8)
                    .background(Color.black.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .focused($isFocused)
                    .onAppear {
                        editText = text
                        isFocused = true
                    }
                    .onChange(of: isFocused) { _, focused in
                        if !focused {
                            onEndEdit(editText)
                        }
                    }
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") {
                                onEndEdit(editText)
                                isFocused = false
                            }
                            .foregroundStyle(TFTheme.yellow)
                        }
                    }
            } else {
                Text(text.isEmpty ? "Tap to write..." : text)
                    .font(.body)
                    .foregroundStyle(text.isEmpty ? .white.opacity(0.4) : .white.opacity(0.9))
                    .italic(text.isEmpty)
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
                        .font(.caption)
                        .foregroundStyle(TFTheme.yellow.opacity(0.8))
                    Text("BIT")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(TFTheme.yellow.opacity(0.8))
                        .kerning(1)
                    
                    Spacer()
                    
                    Text(assignment.bitTitleSnapshot)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                }
                
                Text(assignment.plainText)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(6)
            } else {
                Text("Bit not found")
                    .font(.body)
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
}

// MARK: - Bit Drawer Sheet

private struct BitDrawerSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let setlist: Setlist
    let insertionIndex: Int?
    let onInsert: (Bit, Int?) -> Void
    
    @Query(sort: \Bit.updatedAt, order: .reverse) private var allBits: [Bit]
    @State private var searchQuery = ""
    @State private var showAllBits = false
    
    private var filteredBits: [Bit] {
        var bits = allBits.filter { !$0.isDeleted }
        if !showAllBits {
            bits = bits.filter { $0.status == .finished }
        }
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if !q.isEmpty {
            bits = bits.filter { $0.text.localizedCaseInsensitiveContains(q) }
        }
        return bits
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
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
                                BitDrawerRowView(bit: bit, isInSetlist: setlist.containsBit(withId: bit.id)) {
                                    onInsert(bit, insertionIndex)
                                    dismiss()
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
            .searchable(text: $searchQuery, prompt: "Search bits")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(TFTheme.yellow)
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
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
            Text(showAllBits ? "Create some bits first." : "Mark bits as Finished when ready.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
            Spacer()
        }
    }
}

private struct BitDrawerRowView: View {
    let bit: Bit
    let isInSetlist: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Image(systemName: bit.status == .finished ? "checkmark.seal.fill" : "pencil.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(bit.status == .finished ? TFTheme.yellow : .white.opacity(0.5))
                    .frame(width: 28)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(bit.titleLine)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    
                    HStack(spacing: 8) {
                        Text(bit.updatedAt, style: .date)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                        
                        if isInSetlist {
                            Text("In Set")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(TFTheme.yellow.opacity(0.8))
                                .clipShape(Capsule())
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(TFTheme.yellow)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color("TFCard"))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color("TFCardStroke").opacity(0.6), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let setlist = Setlist(title: "Friday Night Set")
    return SetlistBuilderView(setlist: setlist)
}
