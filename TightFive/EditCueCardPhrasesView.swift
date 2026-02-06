import SwiftUI
import SwiftData

/// View for editing anchor and exit phrases for cue cards.
/// 
/// **Purpose**: Allow comedians to customize the exact phrases used for voice recognition,
/// giving them full control over auto-advance triggers in Stage Mode.
///
/// **Works for both**:
/// - Modular setlists: Edit phrases for each script block
/// - Traditional setlists: Edit phrases for each custom cue card
struct EditCueCardPhrasesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Bindable var setlist: Setlist
    
    @State private var editableCards: [EditableCueCard] = []
    @State private var selectedCardId: UUID?
    @State private var hasUnsavedChanges: Bool = false
    @State private var showingSaveConfirmation: Bool = false
    
    var body: some View {
        NavigationStack {
            Group {
                if editableCards.isEmpty {
                    emptyState
                } else {
                    cardList
                }
            }
            .tfBackground()
            .navigationTitle("Edit Cue Card Phrases")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    TFWordmarkTitle(title: "Edit Cue Card Phrases", size: 20)
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        if hasUnsavedChanges {
                            showingSaveConfirmation = true
                        } else {
                            dismiss()
                        }
                    }
                    .foregroundStyle(.white.opacity(0.7))
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveChanges()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(TFTheme.yellow)
                    .disabled(!hasUnsavedChanges)
                }
            }
            .alert("Unsaved Changes", isPresented: $showingSaveConfirmation) {
                Button("Discard", role: .destructive) {
                    dismiss()
                }
                Button("Save") {
                    saveChanges()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You have unsaved changes to your cue card phrases. Would you like to save them?")
            }
        }
        .onAppear {
            loadEditableCards()
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "rectangle.stack.badge.minus")
                .font(.system(size: 60))
                .foregroundStyle(.white.opacity(0.3))
            
            Text("No Cue Cards Found")
                .appFont(.title2, weight: .semibold)
                .foregroundStyle(.white)
            
            Text("This setlist doesn't have any content to create cue cards from. Add some bits or text to your script first.")
                .appFont(.body)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Card List
    
    private var cardList: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Instructions
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(TFTheme.yellow)
                        Text("Customize Recognition Phrases")
                            .appFont(.headline)
                            .foregroundStyle(.white)
                    }
                    
                    Text("Edit the anchor (start) and exit (end) phrases for each card. Stage Mode uses these for voice-activated auto-advance.")
                        .appFont(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(16)
                .tfDynamicCard(cornerRadius: 12)
                
                // Card editors
                ForEach($editableCards) { $card in
                    CueCardPhraseEditor(
                        card: $card,
                        cardNumber: (editableCards.firstIndex(where: { $0.id == card.id }) ?? 0) + 1,
                        totalCards: editableCards.count,
                        isSelected: selectedCardId == card.id,
                        onSelect: { selectedCardId = card.id },
                        onChange: { hasUnsavedChanges = true }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
    }
    
    // MARK: - Data Management
    
    private func loadEditableCards() {
        switch setlist.currentScriptMode {
        case .modular:
            loadFromModularSetlist()
        case .traditional:
            loadFromTraditionalSetlist()
        }
    }
    
    private func loadFromModularSetlist() {
        var cards: [EditableCueCard] = []
        
        // Load existing custom phrases
        let customPhrasesMap = setlist.modularCustomPhrases
        
        for (index, block) in setlist.scriptBlocks.enumerated() {
            let text = block.plainText(using: setlist.assignments ?? [])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard !text.isEmpty else { continue }
            
            // Extract default phrases if none exist
            let (defaultAnchor, defaultExit) = extractDefaultPhrases(from: text)
            
            // Load custom phrases if they exist
            let customOverride = customPhrasesMap[block.id]
            
            cards.append(EditableCueCard(
                id: block.id,
                cardNumber: index,
                content: text,
                anchorPhrase: defaultAnchor,
                exitPhrase: defaultExit,
                customAnchorPhrase: customOverride?.anchorPhrase,
                customExitPhrase: customOverride?.exitPhrase,
                isModular: true
            ))
        }
        
        editableCards = cards
    }
    
    private func loadFromTraditionalSetlist() {
        let customCards = setlist.customCueCards.sorted { $0.order < $1.order }
        
        editableCards = customCards.enumerated().map { index, customCard in
            EditableCueCard(
                id: customCard.id,
                cardNumber: index,
                content: customCard.content,
                anchorPhrase: extractDefaultPhrases(from: customCard.content).0,
                exitPhrase: extractDefaultPhrases(from: customCard.content).1,
                customAnchorPhrase: customCard.anchorPhrase,
                customExitPhrase: customCard.exitPhrase,
                isModular: false
            )
        }
    }
    
    private func extractDefaultPhrases(from text: String) -> (anchor: String, exit: String) {
        let words = text.split(whereSeparator: \.isWhitespace).map(String.init)
        let targetWords = 15
        
        let anchorWords = Array(words.prefix(min(targetWords, words.count)))
        let anchor = anchorWords.joined(separator: " ")
        
        let exitWords = Array(words.suffix(min(targetWords, words.count)))
        let exit = exitWords.joined(separator: " ")
        
        return (anchor, exit)
    }
    
    private func saveChanges() {
        switch setlist.currentScriptMode {
        case .modular:
            saveToModularSetlist()
        case .traditional:
            saveToTraditionalSetlist()
        }
        
        setlist.updatedAt = Date()
        try? modelContext.save()
        
        hasUnsavedChanges = false
    }
    
    private func saveToModularSetlist() {
        var customPhrasesMap = setlist.modularCustomPhrases
        
        for card in editableCards {
            if card.hasCustomPhrases {
                customPhrasesMap[card.id] = CustomPhraseOverride(
                    anchorPhrase: card.customAnchorPhrase,
                    exitPhrase: card.customExitPhrase
                )
            } else {
                // Remove override if comedian reset to defaults
                customPhrasesMap.removeValue(forKey: card.id)
            }
        }
        
        setlist.modularCustomPhrases = customPhrasesMap
        print("💾 Saved custom phrases for \(customPhrasesMap.count) modular blocks")
    }
    
    private func saveToTraditionalSetlist() {
        var updatedCards = setlist.customCueCards
        
        for card in editableCards {
            if let index = updatedCards.firstIndex(where: { $0.id == card.id }) {
                updatedCards[index].anchorPhrase = card.customAnchorPhrase
                updatedCards[index].exitPhrase = card.customExitPhrase
            }
        }
        
        setlist.customCueCards = updatedCards
        print("💾 Saved custom phrases for \(editableCards.count) traditional cue cards")
    }
}

// MARK: - Editable Cue Card Model

struct EditableCueCard: Identifiable, Equatable {
    let id: UUID
    let cardNumber: Int
    let content: String
    let anchorPhrase: String  // Default extracted phrase
    let exitPhrase: String     // Default extracted phrase
    var customAnchorPhrase: String? // Comedian's override
    var customExitPhrase: String?   // Comedian's override
    let isModular: Bool
    
    var effectiveAnchorPhrase: String {
        customAnchorPhrase ?? anchorPhrase
    }
    
    var effectiveExitPhrase: String {
        customExitPhrase ?? exitPhrase
    }
    
    var hasCustomAnchor: Bool {
        customAnchorPhrase != nil && customAnchorPhrase != anchorPhrase
    }
    
    var hasCustomExit: Bool {
        customExitPhrase != nil && customExitPhrase != exitPhrase
    }
    
    var hasCustomPhrases: Bool {
        hasCustomAnchor || hasCustomExit
    }
}

// MARK: - Card Phrase Editor

struct CueCardPhraseEditor: View {
    @Binding var card: EditableCueCard
    let cardNumber: Int
    let totalCards: Int
    let isSelected: Bool
    let onSelect: () -> Void
    let onChange: () -> Void
    
    @State private var showingContentPreview: Bool = false
    @FocusState private var focusedField: Field?
    
    enum Field {
        case anchor
        case exit
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Card header
            Button {
                onSelect()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showingContentPreview.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    // Card number badge
                    Text("\(cardNumber)")
                        .appFont(.headline, weight: .bold)
                        .foregroundStyle(.black)
                        .frame(width: 36, height: 36)
                        .background(TFTheme.yellow)
                        .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Card \(cardNumber) of \(totalCards)")
                            .appFont(.headline)
                            .foregroundStyle(.white)
                        
                        if card.hasCustomPhrases {
                            HStack(spacing: 4) {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.caption)
                                Text("Custom phrases")
                                    .appFont(.caption)
                            }
                            .foregroundStyle(TFTheme.yellow)
                        } else {
                            Text("Using default phrases")
                                .appFont(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: showingContentPreview ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Content preview (collapsible)
            if showingContentPreview {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Card Content")
                        .appFont(.caption, weight: .semibold)
                        .foregroundStyle(.white.opacity(0.7))
                    
                    Text(card.content)
                        .appFont(.body)
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(6)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.black.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(16)
                .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
                
                Divider()
                    .background(Color.white.opacity(0.1))
            }
            
            // Phrase editors
            VStack(spacing: 16) {
                // Anchor phrase
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Anchor Phrase (Start)", systemImage: "arrow.down.to.line")
                            .appFont(.subheadline, weight: .semibold)
                            .foregroundStyle(.white)
                        
                        Spacer()
                        
                        if card.hasCustomAnchor {
                            Button {
                                card.customAnchorPhrase = nil
                                onChange()
                            } label: {
                                Text("Reset")
                                    .appFont(.caption, weight: .medium)
                                    .foregroundStyle(TFTheme.yellow)
                            }
                        }
                    }
                    
                    Text("First ~15 words that confirm you're at this card")
                        .appFont(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                    
                    TextField("Enter anchor phrase...", text: Binding(
                        get: { card.customAnchorPhrase ?? card.anchorPhrase },
                        set: { newValue in
                            card.customAnchorPhrase = newValue.isEmpty ? nil : newValue
                            onChange()
                        }
                    ), axis: .vertical)
                    .focused($focusedField, equals: .anchor)
                    .appFont(.body)
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(Color.black.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(focusedField == .anchor ? TFTheme.yellow : Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .lineLimit(3...6)
                }
                
                // Exit phrase
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Exit Phrase (End)", systemImage: "arrow.right.to.line")
                            .appFont(.subheadline, weight: .semibold)
                            .foregroundStyle(.white)
                        
                        Spacer()
                        
                        if card.hasCustomExit {
                            Button {
                                card.customExitPhrase = nil
                                onChange()
                            } label: {
                                Text("Reset")
                                    .appFont(.caption, weight: .medium)
                                    .foregroundStyle(TFTheme.yellow)
                            }
                        }
                    }
                    
                    Text("Last ~15 words that trigger advance to next card")
                        .appFont(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                    
                    TextField("Enter exit phrase...", text: Binding(
                        get: { card.customExitPhrase ?? card.exitPhrase },
                        set: { newValue in
                            card.customExitPhrase = newValue.isEmpty ? nil : newValue
                            onChange()
                        }
                    ), axis: .vertical)
                    .focused($focusedField, equals: .exit)
                    .appFont(.body)
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(Color.black.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(focusedField == .exit ? TFTheme.yellow : Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .lineLimit(3...6)
                }
            }
            .padding(16)
        }
        .tfDynamicCard(cornerRadius: 16)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var testSetlist = Setlist(title: "Test Set")
        
        init() {
            // Add some test script blocks
            _testSetlist = State(initialValue: {
                let setlist = Setlist(title: "Test Set")
                setlist.scriptBlocks = [
                    .newFreeform(text: "Hey everybody, how's it going tonight? Great to be here!"),
                    .newFreeform(text: "So I was at the grocery store the other day, and I realized something. Why do they call it a 'self-checkout' when you're doing all the work? Shouldn't it be called 'we're not paying you checkout'?")
                ]
                return setlist
            }())
        }
        
        var body: some View {
            EditCueCardPhrasesView(setlist: testSetlist)
        }
    }
    
    return PreviewWrapper()
        .modelContainer(for: [Setlist.self], inMemory: true)
}
