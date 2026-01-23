import SwiftUI
import SwiftData

/// Editor view for a single setlist assignment.
///
/// Allows editing the performed content (RTF) of an assignment.
/// Changes are committed as variations when saved (if linked to a live bit).
struct AssignmentEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let setlist: Setlist
    @Bindable var assignment: SetlistAssignment
    
    @State private var rtfData: Data
    @State private var variationNote: String = ""
    @State private var showNoteField: Bool = false
    @State private var hasChanges: Bool = false
    
    /// Whether the original bit still exists
    private var hasLiveBit: Bool {
        assignment.hasLiveBit(in: modelContext)
    }
    
    /// Whether original bit was deleted
    private var isOrphaned: Bool {
        assignment.isOrphaned(in: modelContext)
    }
    
    init(setlist: Setlist, assignment: SetlistAssignment) {
        self.setlist = setlist
        self.assignment = assignment
        self._rtfData = State(initialValue: assignment.performedRTF)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Status banner if orphaned
                if isOrphaned {
                    orphanedBanner
                }
                
                // Title display
                HStack {
                    Text(assignment.bitTitleSnapshot)
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.7))
                    
                    Spacer()
                    
                    if assignment.isModified {
                        Text("Modified")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
                
                Divider().opacity(0.25)
                
                // Rich text editor
                RichTextEditor(rtfData: $rtfData)
                    .onChange(of: rtfData) { oldValue, newValue in
                        hasChanges = (newValue != assignment.performedRTF)
                    }
                
                // Optional note field for variation
                if showNoteField && hasLiveBit {
                    noteField
                }
            }
            .tfBackground()
            .hideKeyboardInteractively()
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(TFTheme.yellow)
                }
                
                ToolbarItem(placement: .principal) {
                    TFWordmarkTitle(title: "Edit Bit", size: 20)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .font(.headline)
                    .foregroundStyle(hasChanges ? TFTheme.yellow : .white.opacity(0.4))
                    .disabled(!hasChanges)
                }
            }
            .toolbar {
                // Note toggle (only if linked to live bit)
                if hasLiveBit && hasChanges {
                    ToolbarItem(placement: .bottomBar) {
                        Button {
                            withAnimation { showNoteField.toggle() }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: showNoteField ? "note.text.badge.plus" : "note.text")
                                Text(showNoteField ? "Hide Note" : "Add Note")
                            }
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Components
    
    private var orphanedBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            
            Text("Original bit was deleted. Changes won't create a variation.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
            
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.orange.opacity(0.15))
    }
    
    private var noteField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Variation Note (optional)")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
            
            TextField("e.g., Tightened the tag, New opener...", text: $variationNote)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Color("TFCard"))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color("TFCardStroke").opacity(0.5), lineWidth: 1)
                )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.2))
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
    
    // MARK: - Actions
    
    private func saveChanges() {
        // Commit the variation (handles all the logic internally)
        let note = variationNote.trimmingCharacters(in: .whitespacesAndNewlines)
        setlist.commitVariation(
            for: assignment,
            newRTF: rtfData,
            note: note.isEmpty ? nil : note,
            context: modelContext
        )
        
        // Save context
        try? modelContext.save()
        
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    let setlist = Setlist(title: "Test Setlist")
    let assignment = SetlistAssignment(
        order: 0,
        performedRTF: "Test content for editing".toRTF(),
        bitTitleSnapshot: "Test Bit Title"
    )
    
    return AssignmentEditorView(setlist: setlist, assignment: assignment)
}
