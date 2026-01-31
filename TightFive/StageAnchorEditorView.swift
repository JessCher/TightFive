import SwiftUI
import SwiftData
import UIKit

/// Editor for configuring Stage Mode anchor phrases.
struct StageAnchorEditorView: View {
    @Environment(\.dismiss) private var dismiss
    
    let setlist: Setlist
    
    @State private var anchors: [StageAnchor]
    @State private var editingAnchorId: UUID?
    @State private var editingText: String = ""
    @State private var showTestMode = false
    @State private var hasChanges = false
    
    init(setlist: Setlist) {
        self.setlist = setlist
        let existing = setlist.stageAnchors
        if existing.isEmpty {
            self._anchors = State(initialValue: setlist.generateDefaultAnchors())
        } else {
            self._anchors = State(initialValue: existing)
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                instructionsHeader
                
                Divider().opacity(0.25)
                
                if anchors.isEmpty {
                    noBitsState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(Array(anchors.enumerated()), id: \.element.id) { index, anchor in
                                anchorRow(anchor: anchor, index: index)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                    }
                }
                
                bottomBar
            }
            .navigationTitle("Configure Anchors")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(TFTheme.yellow)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveAnchors() }
                        .appFont(.headline)
                        .foregroundStyle(hasChanges ? TFTheme.yellow : .white.opacity(0.4))
                        .disabled(!hasChanges)
                }
            }
            .tfBackground()
            .sheet(isPresented: $showTestMode) {
                AnchorTestView(anchors: anchors.filter { $0.isEnabled && $0.isValid })
            }
        }
    }
    
    private var instructionsHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "waveform")
                    .foregroundStyle(TFTheme.yellow)
                Text("Anchor Phrases")
                    .appFont(.headline)
                    .foregroundStyle(.white)
            }
            
            Text("Say these opening lines to navigate to each bit during your performance.")
                .appFont(.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.black.opacity(0.2))
    }
    
    private var noBitsState: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.3))
            
            Text("No bits in script")
                .appFont(.title3, weight: .semibold)
                .foregroundStyle(.white)
            
            Text("Add bits to your setlist to configure anchors.")
                .appFont(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
            
            Spacer()
        }
    }
    
    private func anchorRow(anchor: StageAnchor, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("\(index + 1)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.black)
                    .frame(width: 24, height: 24)
                    .background(anchor.isEnabled ? TFTheme.yellow : Color.gray)
                    .clipShape(Circle())
                
                if let assignment = setlist.assignments.first(where: { $0.id == anchor.assignmentId }) {
                    Text(assignment.bitTitleSnapshot)
                        .appFont(.subheadline, weight: .medium)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                } else {
                    Text("Unknown Bit")
                        .appFont(.subheadline, weight: .medium)
                        .foregroundStyle(.white.opacity(0.5))
                }
                
                Spacer()
                
                Toggle("", isOn: binding(for: anchor.id))
                    .labelsHidden()
                    .tint(TFTheme.yellow)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "quote.opening")
                        .appFont(.caption2)
                        .foregroundStyle(TFTheme.yellow.opacity(0.7))
                    
                    Text("Anchor phrase:")
                        .appFont(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                    
                    Spacer()
                    
                    if !anchor.isValid && anchor.isEnabled {
                        Text("Too short")
                            .appFont(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
                
                if editingAnchorId == anchor.id {
                    TextField("Enter phrase...", text: $editingText)
                        .textFieldStyle(.plain)
                        .appFont(.body)
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(Color.black.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(TFTheme.yellow.opacity(0.5), lineWidth: 1)
                        )
                        .onSubmit { commitEdit(for: anchor.id) }
                } else {
                    Button {
                        startEditing(anchor)
                    } label: {
                        Text(anchor.phrase)
                            .appFont(.body)
                            .foregroundStyle(anchor.isEnabled ? .white.opacity(0.9) : .white.opacity(0.4))
                            .italic()
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 14)
            .opacity(anchor.isEnabled ? 1.0 : 0.5)
        }
        .background(Color("TFCard"))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    anchor.isValid && anchor.isEnabled ? Color("TFCardStroke").opacity(0.6) : Color.orange.opacity(0.5),
                    lineWidth: 1
                )
        )
    }
    
    private var bottomBar: some View {
        VStack(spacing: 12) {
            Button {
                showTestMode = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "mic.fill")
                    Text("Test Recognition")
                }
                .appFont(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color("TFCard"))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color("TFCardStroke").opacity(0.6), lineWidth: 1)
                )
            }
            .disabled(anchors.filter { $0.isEnabled && $0.isValid }.isEmpty)
            
            Button {
                resetToDefaults()
            } label: {
                Text("Reset to Defaults")
                    .appFont(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(16)
        .background(Color.black.opacity(0.3))
    }
    
    private func binding(for id: UUID) -> Binding<Bool> {
        Binding(
            get: { anchors.first { $0.id == id }?.isEnabled ?? false },
            set: { newValue in
                if let index = anchors.firstIndex(where: { $0.id == id }) {
                    anchors[index].isEnabled = newValue
                    hasChanges = true
                }
            }
        )
    }
    
    private func startEditing(_ anchor: StageAnchor) {
        if let currentId = editingAnchorId {
            commitEdit(for: currentId)
        }
        editingAnchorId = anchor.id
        editingText = anchor.phrase
    }
    
    private func commitEdit(for id: UUID) {
        if let index = anchors.firstIndex(where: { $0.id == id }) {
            let trimmed = editingText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                anchors[index].phrase = trimmed
                hasChanges = true
            }
        }
        editingAnchorId = nil
        editingText = ""
    }
    
    private func saveAnchors() {
        if let editId = editingAnchorId {
            commitEdit(for: editId)
        }
        setlist.saveAnchors(anchors)
        dismiss()
    }
    
    private func resetToDefaults() {
        anchors = setlist.generateDefaultAnchors()
        hasChanges = true
        editingAnchorId = nil
        editingText = ""
    }
}

// MARK: - Anchor Test View

struct AnchorTestView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var recognizer = StageAnchorRecognizer()
    
    let anchors: [StageAnchor]
    
    @State private var matchedAnchor: StageAnchor?
    @State private var matchConfidence: Double = 0
    @State private var isListening = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(isListening ? Color.green.opacity(0.2) : Color.white.opacity(0.1))
                            .frame(width: 100, height: 100)
                        
                        Image(systemName: isListening ? "waveform" : "mic.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(isListening ? .green : .white.opacity(0.5))
                            .symbolEffect(.variableColor, isActive: isListening)
                    }
                    
                    Text(isListening ? "Listening..." : "Tap to Start")
                        .appFont(.headline)
                        .foregroundStyle(.white)
                    
                    if !recognizer.lastTranscript.isEmpty {
                        Text("\"\(recognizer.lastTranscript)\"")
                            .appFont(.subheadline)
                            .foregroundStyle(.white.opacity(0.6))
                            .italic()
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                .padding(.top, 20)
                
                if let anchor = matchedAnchor {
                    matchResultView(anchor: anchor)
                        .transition(.scale.combined(with: .opacity))
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("LISTENING FOR:")
                        .appFont(.caption, weight: .bold)
                        .foregroundStyle(.white.opacity(0.5))
                        .kerning(1.5)
                    
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(anchors) { anchor in
                                HStack(spacing: 8) {
                                    Image(systemName: matchedAnchor?.id == anchor.id ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(matchedAnchor?.id == anchor.id ? .green : .white.opacity(0.3))
                                    
                                    Text(anchor.shortPhrase)
                                        .appFont(.subheadline)
                                        .foregroundStyle(.white.opacity(0.8))
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                    .frame(height: 200)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color("TFCard"))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 16)
                
                Button {
                    toggleListening()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: isListening ? "stop.fill" : "mic.fill")
                        Text(isListening ? "Stop" : "Start Listening")
                    }
                    .appFont(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(TFTheme.yellow)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
            .navigationTitle("Test Recognition")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        recognizer.stopListening()
                        dismiss()
                    }
                    .foregroundStyle(TFTheme.yellow)
                }
            }
            .tfBackground()
        }
        .onDisappear { recognizer.stopListening() }
    }
    
    private func matchResultView(anchor: StageAnchor) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Match Found!")
                    .appFont(.headline)
                    .foregroundStyle(.white)
            }
            
            Text(anchor.phrase)
                .appFont(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
                .italic()
                .multilineTextAlignment(.center)
            
            Text("\(Int(matchConfidence * 100))% confidence")
                .appFont(.caption)
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(16)
        .background(Color.green.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.green.opacity(0.5), lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }
    
    private func toggleListening() {
        if isListening {
            recognizer.stopListening()
            isListening = false
        } else {
            matchedAnchor = nil
            matchConfidence = 0
            
            Task {
                recognizer.onAnchorDetected = { anchor, confidence in
                    withAnimation {
                        matchedAnchor = anchor
                        matchConfidence = confidence
                    }
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    
                    // CRITICAL: Clear after short delay to allow user to see the match
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        Task { @MainActor in
                            recognizer.clearLastDetection()
                        }
                    }
                }
                let success = await recognizer.startListening(for: anchors)
                isListening = success
            }
        }
    }
}

#Preview {
    let setlist = Setlist(title: "Test Set", isDraft: false)
    return StageAnchorEditorView(setlist: setlist)
}
