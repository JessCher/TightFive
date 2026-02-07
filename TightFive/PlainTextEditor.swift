//
//  PlainTextEditor.swift
//  TightFive
//
//  Plain text editor
//  - SwiftUI wrapper around UITextView
//  - Uses UITextView's built-in undo/redo
//  - No rich text formatting
//  - Optimized for performance with plain text
//

import SwiftUI
import UIKit

/// A plain text editor using UITextView's built-in undo/redo
struct PlainTextEditor: UIViewRepresentable {
    @Binding var text: String
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        configure(textView: textView)
        context.coordinator.attach(to: textView)
        return textView
    }
    
    func updateUIView(_ textView: UITextView, context: Context) {
        context.coordinator.updateFromSwiftUI(newText: text, in: textView)
    }
    
    private func configure(textView: UITextView) {
        // Visual
        textView.backgroundColor = .clear
        textView.textColor = .white
        textView.font = UIFont.systemFont(ofSize: 17)
        
        // Smart typing
        textView.autocapitalizationType = .sentences
        textView.autocorrectionType = .yes
        textView.spellCheckingType = .yes
        textView.smartQuotesType = .yes
        textView.smartDashesType = .yes
        textView.smartInsertDeleteType = .yes
        
        // Plain text only
        textView.allowsEditingTextAttributes = false
        
        // Interaction + Performance
        textView.isScrollEnabled = true
        textView.isEditable = true
        textView.isUserInteractionEnabled = true
        textView.isSelectable = true
        textView.keyboardDismissMode = .interactive
        
        // PERFORMANCE: Enable non-contiguous layout for better scrolling with large text
        textView.layoutManager.allowsNonContiguousLayout = true
        
        // PERFORMANCE FIX: Disable expensive text checking during typing
        textView.layoutManager.showsInvisibleCharacters = false
        textView.layoutManager.showsControlCharacters = false
        textView.layoutManager.usesDefaultHyphenation = false
    }
}

// MARK: - Coordinator

@MainActor
final class PlainTextEditorCoordinator: NSObject, UITextViewDelegate {
    
    // Wiring
    private var parent: PlainTextEditor
    weak var textView: UITextView?
    
    // Sync
    private var internalUpdateFlag = false
    private var lastObservedText: String = ""
    
    init(parent: PlainTextEditor) {
        self.parent = parent
        super.init()
    }

    func attach(to textView: UITextView) {
        self.textView = textView
        textView.delegate = self
        
        // Initial load
        textView.text = parent.text
        lastObservedText = parent.text
    }
    
    // MARK: SwiftUI -> UIKit sync
    
    func updateFromSwiftUI(newText: String, in uiView: UITextView) {
        // If change originated from inside editor, ignore the next SwiftUI update to prevent loops
        if consumeInternalUpdateFlag() { return }
        
        // Fast gate: if text is identical, don't touch the view
        if newText == lastObservedText { return }
        
        let saved = uiView.selectedRange
        uiView.text = newText
        uiView.selectedRange = clampedSelection(saved, toLength: newText.count)
        
        lastObservedText = newText
    }
    
    private func markInternalUpdate() { internalUpdateFlag = true }
    
    private func consumeInternalUpdateFlag() -> Bool {
        if internalUpdateFlag {
            internalUpdateFlag = false
            return true
        }
        return false
    }
    
    private func clampedSelection(_ selection: NSRange, toLength length: Int) -> NSRange {
        guard length > 0 else { return NSRange(location: 0, length: 0) }
        let loc = min(max(selection.location, 0), length)
        let maxLen = max(0, length - loc)
        let len = min(max(selection.length, 0), maxLen)
        return NSRange(location: loc, length: len)
    }
    
    // MARK: UITextViewDelegate
    
    func textViewDidChange(_ textView: UITextView) {
        let newText = textView.text ?? ""
        if newText != lastObservedText {
            markInternalUpdate()
            parent.text = newText
            lastObservedText = newText
        }
    }
}

extension PlainTextEditor {
    // Coordinator type for UIViewRepresentable conformance
    typealias Coordinator = PlainTextEditorCoordinator
}
