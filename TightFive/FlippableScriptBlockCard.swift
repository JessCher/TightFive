import SwiftUI
import SwiftData

// MARK: - Flippable Script Block Card

/// A flippable script block card for show notes that shows the bit content on the front
/// and rating + notes on the back, using the same animation as FlippableBitCard.
struct FlippableScriptBlockCard: View {
    let block: ScriptBlock
    let assignments: [SetlistAssignment]
    @Binding var isFlipped: Bool
    @Binding var rating: Int
    @Binding var notes: String
    var onTextFieldFocus: ((UUID) -> Void)?
    
    @FocusState private var isNotesFocused: Bool
    
    // Create a unique ID for the text editor to enable precise scrolling
    private var textEditorID: UUID {
        UUID(uuidString: block.id.uuidString.replacingOccurrences(of: "-", with: "").prefix(8) + "-0000-0000-0000-" + block.id.uuidString.suffix(12))!
    }
    
    var body: some View {
        FlippableBitCard(isFlipped: $isFlipped) {
            frontCard
        } back: {
            backCard
        }
    }
    
    private var frontCard: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 8) {
                Text(blockContentText(block, assignments: assignments))
                    .appFont(.body)
                    .foregroundStyle(TFTheme.text.opacity(0.85))
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .tfDynamicCard(cornerRadius: 14)
            
            // Flip button
            Button {
                withAnimation { isFlipped = true }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: rating > 0 ? "star.fill" : "note.text")
                        .appFont(.caption)
                    if rating > 0 || !notes.isEmpty {
                        Circle()
                            .fill(TFTheme.yellow)
                            .frame(width: 6, height: 6)
                    }
                }
                .foregroundStyle(TFTheme.yellow)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.4))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(TFTheme.yellow.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .padding(.trailing, 12)
            .padding(.bottom, 12)
        }
    }
    
    private var backCard: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 12) {
                // Rating Section
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "star.fill")
                            .appFont(.subheadline)
                            .foregroundStyle(TFTheme.yellow)
                        Text("Rating")
                            .appFont(.subheadline, weight: .semibold)
                            .foregroundStyle(TFTheme.text)
                    }
                    
                    HStack(spacing: 6) {
                        ForEach(1...5, id: \.self) { index in
                            Button {
                                rating = (rating == index) ? 0 : index
                            } label: {
                                Image(systemName: index <= rating ? "star.fill" : "star")
                                    .font(.system(size: 24))
                                    .foregroundStyle(index <= rating ? TFTheme.yellow : .white.opacity(0.3))
                            }
                        }
                    }
                }
                
                Divider()
                    .background(.white.opacity(0.2))
                
                // Notes Section - Fixed height, scrollable
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "note.text")
                            .appFont(.subheadline)
                            .foregroundStyle(TFTheme.yellow)
                        Text("Notes")
                            .appFont(.subheadline, weight: .semibold)
                            .foregroundStyle(TFTheme.text)
                    }
                    
                    ZStack(alignment: .topLeading) {
                        if notes.isEmpty && !isNotesFocused {
                            Text("How'd this bit do?")
                                .appFont(.caption)
                                .foregroundStyle(TFTheme.text.opacity(0.35))
                                .padding(.top, 6)
                                .padding(.leading, 4)
                        }
                        
                        TextEditor(text: $notes)
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)
                            .appFont(.caption)
                            .foregroundStyle(TFTheme.text)
                            .focused($isNotesFocused)
                            .onChange(of: isNotesFocused) { oldValue, newValue in
                                if newValue {
                                    // Delay to allow keyboard animation to start
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        onTextFieldFocus?(textEditorID)
                                    }
                                }
                            }
                    }
                    .id(textEditorID)
                    .frame(height: 120) // Fixed height - text scrolls inside
                    .padding(6)
                    .background(Color.black.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .tfDynamicCard(cornerRadius: 14)
            
            // Flip button
            Button {
                isNotesFocused = false
                withAnimation { isFlipped = false }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "doc.text")
                        .appFont(.caption)
                }
                .foregroundStyle(TFTheme.yellow)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.4))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(TFTheme.yellow.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .padding(.trailing, 12)
            .padding(.bottom, 12)
        }
    }
    
    private func blockContentText(_ block: ScriptBlock, assignments: [SetlistAssignment]) -> String {
        switch block {
        case .freeform(_, let rtfData):
            return NSAttributedString.fromRTF(rtfData)?.string ?? ""
        case .bit(_, let assignmentId):
            guard let assignment = assignments.first(where: { $0.id == assignmentId }) else {
                return ""
            }
            return assignment.plainText
        }
    }
}

/// Container view for managing multiple flippable script blocks
struct FlippableScriptBlockList: View {
    let blocks: [ScriptBlock]
    let assignments: [SetlistAssignment]
    @Bindable var performance: Performance
    @Environment(\.modelContext) private var modelContext
    
    @State private var flippedBlockIds: Set<UUID> = []
    @State private var activeTextFieldID: UUID?
    @Namespace private var namespace
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(Array(blocks.enumerated()), id: \.element.id) { index, block in
                        let blockIdString = block.id.uuidString
                        let isFlipped = flippedBlockIds.contains(block.id)
                        
                        FlippableScriptBlockCard(
                            block: block,
                            assignments: assignments,
                            isFlipped: Binding(
                                get: { isFlipped },
                                set: { newValue in
                                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                        if newValue {
                                            flippedBlockIds.insert(block.id)
                                        } else {
                                            flippedBlockIds.remove(block.id)
                                        }
                                    }
                                    
                                    // Scroll to the flipped card after a brief delay
                                    if newValue {
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                            withAnimation(.easeInOut(duration: 0.4)) {
                                                proxy.scrollTo(block.id, anchor: .top)
                                            }
                                        }
                                    }
                                }
                            ),
                            rating: Binding(
                                get: { performance.bitRatings[blockIdString] ?? 0 },
                                set: { newValue in
                                    performance.bitRatings[blockIdString] = newValue
                                    try? modelContext.save()
                                }
                            ),
                            notes: Binding(
                                get: { performance.bitNotes[blockIdString] ?? "" },
                                set: { newValue in
                                    performance.bitNotes[blockIdString] = newValue
                                    try? modelContext.save()
                                }
                            ),
                            onTextFieldFocus: { textEditorID in
                                // Scroll to center the card when keyboard appears
                                activeTextFieldID = textEditorID
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                    withAnimation(.easeInOut(duration: 0.4)) {
                                        proxy.scrollTo(block.id, anchor: .center)
                                    }
                                }
                            }
                        )
                        .id(block.id)
                        .padding(.vertical, isFlipped ? 8 : 0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isFlipped)
                    }
                }
                .padding(16)
            }
            .dismissKeyboardOnDrag()
        }
        .dismissKeyboardOnTap()
    }
}
