import SwiftUI
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
                        let s = Setlist(title: "Untitled Set", bodyRTF: Data(), isDraft: true)
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

struct InProgressSetlistsView: View {
    init() {}

    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate { $0.isDraft == true }, sort: \Setlist.updatedAt, order: .reverse) private var setlists: [Setlist]

    var body: some View {
        List {
            ForEach(setlists) { s in
                NavigationLink { SetlistEditorView(setlist: s) } label: { row(s) }
            }
            .onDelete { indexSet in
                for i in indexSet { modelContext.delete(setlists[i]) }
            }
        }
        .scrollContentBackground(.hidden)
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

    private func row(_ s: Setlist) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(s.title).font(.headline)
            Text(s.updatedAt, style: .date).font(.caption).foregroundStyle(.secondary)
        }
        .listRowBackground(Color.clear)
    }
}

struct FinishedSetlistsView: View {
    init() {}

    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate { $0.isDraft == false }, sort: \Setlist.updatedAt, order: .reverse) private var setlists: [Setlist]

    var body: some View {
        List {
            ForEach(setlists) { s in
                NavigationLink { SetlistEditorView(setlist: s) } label: { row(s) }
            }
            .onDelete { indexSet in
                for i in indexSet { modelContext.delete(setlists[i]) }
            }
        }
        .scrollContentBackground(.hidden)
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

    private func row(_ s: Setlist) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(s.title).font(.headline)
            Text(s.updatedAt, style: .date).font(.caption).foregroundStyle(.secondary)
        }
        .listRowBackground(Color.clear)
    }
}

struct SetlistEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.undoManager) private var undoManager
    @Environment(\.dismiss) private var dismiss

    @Bindable var setlist: Setlist
    @State private var saveWorkItem: DispatchWorkItem? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Title field
            TextField("Set title", text: $setlist.title)
                .font(.title2.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

                .onChange(of: setlist.title) { _, _ in
                    setlist.updatedAt = Date()
                    scheduleDebouncedSave(reason: "content changed")
                }

            Divider().opacity(0.25)

            // Rich editor
            RichTextEditor(rtfData: $setlist.bodyRTF)
                .onChange(of: setlist.bodyRTF) { _, _ in
                    setlist.updatedAt = Date()
                    scheduleDebouncedSave(reason: "content changed")
                }
        }
        .tfBackground()
        .hideKeyboardInteractively()
        // Swipe-down keyboard dismissal now works with .hideKeyboardInteractively()
        .background(NavigationGestureDisabler())
        .onDisappear { saveContext(reason: "onDisappear") }
        .task { saveContext(reason: "onAppear task") }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                TFWordmarkTitle(title: "Setlist", size: 22)
                    .offset(x: -6)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Done") {
                    saveContext(reason: "Done tapped")
                    dismiss()
                }
                .accessibilityLabel("Done")
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    undoManager?.undo()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                }
                .disabled(!(undoManager?.canUndo ?? false))
                .accessibilityLabel("Undo")
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    undoManager?.redo()
                } label: {
                    Image(systemName: "arrow.uturn.forward")
                }
                .disabled(!(undoManager?.canRedo ?? false))
                .accessibilityLabel("Redo")
            }

            ToolbarItem(placement: .topBarTrailing) {
                Menu {
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
            }
        }
    }
}

private extension SetlistEditorView {
    func duplicateSetlist() {
        let copy = Setlist(title: setlist.title, bodyRTF: setlist.bodyRTF, isDraft: setlist.isDraft)
        modelContext.insert(copy)
        try? modelContext.save()
    }

    func copyTextToClipboard() {
        // Relies on RTFHelpers.swift
        guard let attributed = NSAttributedString.fromRTF(setlist.bodyRTF) else { return }
        UIPasteboard.general.string = attributed.string
    }

    func deleteSetlist() {
        modelContext.delete(setlist)
        try? modelContext.save()
        dismiss()
    }

    func saveContext(reason: String) {
        do {
            try modelContext.save()
            print("[Save] success -", reason)
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

struct SetlistDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.undoManager) private var undoManager
    @Environment(\.dismiss) private var dismiss
    @Bindable var setlist: Setlist

    var body: some View {
        VStack {
            RichTextEditor(rtfData: $setlist.bodyRTF)
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
