import SwiftUI
import SwiftData
import UIKit

struct SetlistsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Setlist.updatedAt, order: .reverse) private var setlists: [Setlist]

    @State private var newlyCreated: Setlist?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                NavigationLink {
                    InProgressSetlistsView()
                } label: {
                    SetlistMenuTile(title: "In Progress",
                                    subtitle: "Keep working on drafts.",
                                    iconName: "IconInProgress",
                                    isAsset: true)
                }

                NavigationLink {
                    FinishedSetlistsView()
                } label: {
                    SetlistMenuTile(title: "Finished",
                                    subtitle: "Ready for the stage.",
                                    iconName: "IconFinishedSetlist",
                                    isAsset: true)
                }

                Spacer()
            }
            .hideKeyboardInteractively()
            .padding()
            .navigationTitle("Set lists")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    TFWordmarkTitle(title: "Set lists", size: 22)
                        .offset(x: -6)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        let s = Setlist(title: "Untitled Set", notesRTF: Data(), isDraft: true)
                        modelContext.insert(s)
                        try? modelContext.save()
                        newlyCreated = s
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("New Setlist")
                }
            }
            .tfBackground()
            .navigationDestination(item: $newlyCreated) { set in
                SetlistEditorView(setlist: set)
            }
        }
    }
}

private struct SetlistMenuTile: View {
    let title: String
    let subtitle: String
    let iconName: String
    let isAsset: Bool

    var body: some View {
        HStack(spacing: 14) {
            if isAsset {
                Image(iconName)
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 34, height: 34)
            } else {
                Image(systemName: iconName)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(TFTheme.yellow)
                    .frame(width: 34, height: 34)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.62))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.28))
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 16)
        .tfDynamicCard(cornerRadius: 20)
    }
}

// MARK: - In Progress List

struct InProgressSetlistsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Setlist> { $0.isDraft == true }, sort: \Setlist.updatedAt, order: .reverse) private var setlists: [Setlist]

    var body: some View {
        Group {
            if setlists.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(setlists) { s in
                        NavigationLink { SetlistEditorView(setlist: s) } label: { row(s) }
                    }
                    .onDelete { indexSet in
                        for i in indexSet { modelContext.delete(setlists[i]) }
                    }
                    .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("In Progress")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                TFWordmarkTitle(title: "In Progress", size: 22)
                    .offset(x: -6)
            }
        }
        .tfBackground()
    }
    
    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "hammer")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.3))
            Text("No setlists in progress")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
            Text("Create a new setlist to start building.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
            Spacer()
        }
    }

    private func row(_ s: Setlist) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(s.title).font(.headline).foregroundStyle(.white)
                HStack(spacing: 8) {
                    Text(s.updatedAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                    if s.bitCount > 0 {
                        Text("\(s.bitCount) bits")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Finished List

struct FinishedSetlistsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Setlist> { $0.isDraft == false }, sort: \Setlist.updatedAt, order: .reverse) private var setlists: [Setlist]

    var body: some View {
        Group {
            if setlists.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(setlists) { s in
                        NavigationLink { SetlistEditorView(setlist: s) } label: { row(s) }
                    }
                    .onDelete { indexSet in
                        for i in indexSet { modelContext.delete(setlists[i]) }
                    }
                    .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Finished")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                TFWordmarkTitle(title: "Finished", size: 22)
                    .offset(x: -6)
            }
        }
        .tfBackground()
    }
    
    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "checkmark.seal")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.3))
            Text("No finished setlists")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
            Text("Mark a setlist as finished when it's stage-ready.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
            Spacer()
        }
    }

    private func row(_ s: Setlist) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(s.title).font(.headline).foregroundStyle(.white)
                HStack(spacing: 8) {
                    Text(s.updatedAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                    if s.bitCount > 0 {
                        Text("\(s.bitCount) bits")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Setlist Editor (Phase 3)

struct SetlistEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.undoManager) private var undoManager
    @Environment(\.dismiss) private var dismiss

    @Bindable var setlist: Setlist
    
    // Tab state
    enum EditorTab: String, CaseIterable {
        case bits = "Bits"
        case notes = "Notes"
    }
    @State private var selectedTab: EditorTab = .bits
    
    // Edit mode for reordering
    @State private var editMode: EditMode = .inactive
    
    // Sheet state
    @State private var showBitDrawer = false
    @State private var showRunMode = false
    @State private var showExport = false
    @State private var assignmentToEdit: SetlistAssignment?
    
    // Save debouncing
    @State private var saveWorkItem: DispatchWorkItem?

    var body: some View {
        VStack(spacing: 0) {
            // Title field
            TextField("Set title", text: $setlist.title)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)
                .onChange(of: setlist.title) { _, _ in
                    setlist.updatedAt = Date()
                    scheduleDebouncedSave(reason: "title changed")
                }

            // Tab picker
            Picker("View", selection: $selectedTab) {
                ForEach(EditorTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            
            Divider().opacity(0.25)

            // Tab content
            switch selectedTab {
            case .bits:
                bitsTab
            case .notes:
                notesTab
            }
        }
        .environment(\.editMode, $editMode)
        .tfBackground()
        .hideKeyboardInteractively()
        .background(NavigationGestureDisabler())
        .onDisappear { saveContext(reason: "onDisappear") }
        .task { saveContext(reason: "onAppear task") }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Done") {
                    saveContext(reason: "Done tapped")
                    dismiss()
                }
                .foregroundStyle(TFTheme.yellow)
                .accessibilityLabel("Done")
            }
            
            ToolbarItem(placement: .principal) {
                TFWordmarkTitle(title: "Setlist", size: 22)
                    .offset(x: -6)
            }

            ToolbarItem(placement: .topBarTrailing) {
                // Run Mode button (only if has notes)
                if !setlist.notesPlainText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button {
                        showRunMode = true
                    } label: {
                        Image(systemName: "play.fill")
                            .foregroundStyle(TFTheme.yellow)
                    }
                    .accessibilityLabel("Run Mode")
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    // Edit/Reorder toggle
                    if selectedTab == .bits && !setlist.orderedAssignments.isEmpty {
                        Button {
                            withAnimation {
                                editMode = editMode == .active ? .inactive : .active
                            }
                        } label: {
                            Label(
                                editMode == .active ? "Done Reordering" : "Reorder Bits",
                                systemImage: editMode == .active ? "checkmark" : "arrow.up.arrow.down"
                            )
                        }
                        
                        Divider()
                    }
                    
                    Button {
                        setlist.isDraft = true
                        setlist.updatedAt = Date()
                        saveContext(reason: "status toggled")
                    } label: {
                        Label("Mark In Progress", systemImage: "hammer")
                    }

                    Button {
                        setlist.isDraft = false
                        setlist.updatedAt = Date()
                        saveContext(reason: "status toggled")
                    } label: {
                        Label("Mark Finished", systemImage: "checkmark.seal")
                    }

                    Divider()
                    
                    Button {
                        showExport = true
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }

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
                        .foregroundStyle(TFTheme.yellow)
                }
            }
        }
        .sheet(isPresented: $showBitDrawer) {
            BitDrawerView(setlist: setlist) { bit in
                addBitToSetlist(bit)
            }
        }
        .sheet(item: $assignmentToEdit) { assignment in
            AssignmentEditorView(setlist: setlist, assignment: assignment)
        }
        .sheet(isPresented: $showExport) {
            SetlistShareSheet(setlist: setlist)
        }
        .fullScreenCover(isPresented: $showRunMode) {
            RunModeView(setlist: setlist)
        }
    }
    
    // MARK: - Bits Tab
    
    private var bitsTab: some View {
        Group {
            if setlist.orderedAssignments.isEmpty {
                SetlistEmptyState(onAddBit: { showBitDrawer = true })
            } else {
                List {
                    ForEach(setlist.orderedAssignments) { assignment in
                        let index = setlist.orderedAssignments.firstIndex(where: { $0.id == assignment.id }) ?? 0
                        
                        SetlistBitRow(
                            assignment: assignment,
                            displayOrder: index + 1,
                            onTap: {
                                assignmentToEdit = assignment
                            }
                        )
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                    }
                    .onMove(perform: moveAssignments)
                    .onDelete(perform: deleteAssignments)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .overlay(alignment: .bottomTrailing) {
                    if editMode == .inactive {
                        addBitFAB
                    }
                }
            }
        }
    }
    
    // MARK: - Notes Tab
    
    private var notesTab: some View {
        RichTextEditor(rtfData: $setlist.notesRTF)
            .onChange(of: setlist.notesRTF) { _, _ in
                setlist.updatedAt = Date()
                scheduleDebouncedSave(reason: "notes changed")
            }
    }
    
    // MARK: - FAB
    
    private var addBitFAB: some View {
        Button {
            showBitDrawer = true
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
        .accessibilityLabel("Add Bit")
    }
    
    // MARK: - Actions
    
    private func addBitToSetlist(_ bit: Bit) {
        withAnimation(.snappy) {
            setlist.addBit(bit, context: modelContext)
            saveContext(reason: "bit added")
        }
    }
    
    private func moveAssignments(from source: IndexSet, to destination: Int) {
        // Get current ordered list as mutable copy
        var ordered = setlist.orderedAssignments
        
        // Perform the move
        ordered.move(fromOffsets: source, toOffset: destination)
        
        // Update all orders
        for (index, assignment) in ordered.enumerated() {
            assignment.order = index
        }
        
        setlist.updatedAt = Date()
        saveContext(reason: "assignments reordered")
    }
    
    private func deleteAssignments(at offsets: IndexSet) {
        let ordered = setlist.orderedAssignments
        for index in offsets {
            let assignment = ordered[index]
            setlist.removeAssignment(assignment, context: modelContext)
        }
        saveContext(reason: "assignment deleted")
    }
}

// MARK: - Setlist Bit Row (for List with reorder support)

private struct SetlistBitRow: View {
    @Environment(\.modelContext) private var modelContext
    
    let assignment: SetlistAssignment
    let displayOrder: Int
    let onTap: () -> Void
    
    private var isOrphaned: Bool {
        assignment.isOrphaned(in: modelContext)
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Order number badge
                Text("\(displayOrder)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.black)
                    .frame(width: 28, height: 28)
                    .background(TFTheme.yellow)
                    .clipShape(Circle())
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(assignment.titleLine)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    // Status indicators
                    HStack(spacing: 6) {
                        if assignment.isModified {
                            StatusBadge(text: "Modified", color: .blue)
                        }
                        
                        if isOrphaned {
                            StatusBadge(text: "Original Deleted", color: .orange)
                        }
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color("TFCard"))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color("TFCardStroke").opacity(0.7), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct StatusBadge: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }
}

// MARK: - Editor Helpers

private extension SetlistEditorView {
    func duplicateSetlist() {
        let copy = Setlist(title: setlist.title + " (Copy)", notesRTF: setlist.notesRTF, isDraft: setlist.isDraft)
        
        // Duplicate assignments too
        for assignment in setlist.orderedAssignments {
            let assignmentCopy = SetlistAssignment(
                order: assignment.order,
                performedRTF: assignment.performedRTF,
                bitId: assignment.bitId,
                bitTitleSnapshot: assignment.bitTitleSnapshot
            )
            assignmentCopy.setlist = copy
            copy.assignments.append(assignmentCopy)
            modelContext.insert(assignmentCopy)
        }
        
        modelContext.insert(copy)
        try? modelContext.save()
    }

    func copyTextToClipboard() {
        UIPasteboard.general.string = SetlistExporter.generatePlainText(for: setlist)
    }

    func deleteSetlist() {
        modelContext.delete(setlist)
        try? modelContext.save()
        dismiss()
    }

    func saveContext(reason: String) {
        do {
            try modelContext.save()
            #if DEBUG
            print("[Save] success -", reason)
            #endif
        } catch {
            print("[Save] error -", reason, error.localizedDescription)
        }
    }

    func scheduleDebouncedSave(reason: String, delay: TimeInterval = 0.5) {
        saveWorkItem?.cancel()
        let work = DispatchWorkItem { [weak undoManager] in
            _ = undoManager
            saveContext(reason: reason)
        }
        saveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }
}

// MARK: - Detail View (Legacy)

struct SetlistDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.undoManager) private var undoManager
    @Environment(\.dismiss) private var dismiss
    @Bindable var setlist: Setlist

    var body: some View {
        VStack {
            RichTextEditor(rtfData: $setlist.notesRTF)
                .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                TFWordmarkTitle(title: "Detail", size: 22)
                    .offset(x: -6)
            }
        }
        .hideKeyboardInteractively()
    }
}
