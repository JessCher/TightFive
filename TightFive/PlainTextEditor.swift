//
//  PlainTextEditor.swift
//  TightFive
//
//  Plain text editor with undo/redo support
//  - SwiftUI wrapper around UITextView
//  - Full undo/redo functionality via UndoManager
//  - No rich text formatting
//  - Optimized for performance with plain text
//

import SwiftUI
import UIKit

/// A plain text editor with built-in undo/redo support
struct PlainTextEditor: UIViewRepresentable {
    @Binding var text: String
    var undoManager: UndoManager?
    @Environment(\.undoManager) private var envUndo
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        configure(textView: textView)
        context.coordinator.attach(to: textView, undoManager: undoManager ?? envUndo)
        return textView
    }
    
    func updateUIView(_ textView: UITextView, context: Context) {
        context.coordinator.externalUndoManager = undoManager ?? envUndo
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
        
        // Interaction
        textView.isScrollEnabled = true
        textView.isEditable = true
        textView.isUserInteractionEnabled = true
        textView.isSelectable = true
        textView.keyboardDismissMode = .interactive
    }
}

// MARK: - Coordinator

@MainActor
final class PlainTextEditorCoordinator: NSObject, UITextViewDelegate {
    
    // Wiring
    private var parent: PlainTextEditor
    weak var textView: UITextView?
    var externalUndoManager: UndoManager? { didSet { observeUndoManager(externalUndoManager) } }
    
    // Sync
    private var internalUpdateFlag = false
    private var lastObservedText: String = ""
    
    private var isPerformingUndoRedo = false
    private var undoObservationTokens: [NSObjectProtocol] = []
    
    private var commitTimer: Timer?
    private let commitDelay: TimeInterval = 0.30
    
    // Undo grouping
    private var undoBurstStartText: String?
    
    init(parent: PlainTextEditor) {
        self.parent = parent
        super.init()
    }
    
    func attach(to textView: UITextView, undoManager: UndoManager?) {
        self.textView = textView
        self.externalUndoManager = undoManager
        observeUndoManager(self.externalUndoManager)
        
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
    
    private func observeUndoManager(_ undoManager: UndoManager?) {
        // Remove previous observers
        for token in undoObservationTokens { NotificationCenter.default.removeObserver(token) }
        undoObservationTokens.removeAll()
        
        guard let um = undoManager else { return }
        let center = NotificationCenter.default
        weak let weakSelf = self
        
        let willUndo = center.addObserver(forName: .NSUndoManagerWillUndoChange, object: um, queue: .main) { _ in
            Task { @MainActor in
                guard let strongSelf = weakSelf else { return }
                strongSelf.isPerformingUndoRedo = true
                strongSelf.commitTimer?.invalidate()
            }
        }
        let didUndo = center.addObserver(forName: .NSUndoManagerDidUndoChange, object: um, queue: .main) { _ in
            Task { @MainActor in
                weakSelf?.isPerformingUndoRedo = false
            }
        }
        let willRedo = center.addObserver(forName: .NSUndoManagerWillRedoChange, object: um, queue: .main) { _ in
            Task { @MainActor in
                guard let strongSelf = weakSelf else { return }
                strongSelf.isPerformingUndoRedo = true
                strongSelf.commitTimer?.invalidate()
            }
        }
        let didRedo = center.addObserver(forName: .NSUndoManagerDidRedoChange, object: um, queue: .main) { _ in
            Task { @MainActor in
                weakSelf?.isPerformingUndoRedo = false
            }
        }
        
        undoObservationTokens = [willUndo, didUndo, willRedo, didRedo]
    }
    
    func textViewDidChange(_ textView: UITextView) {
        captureUndoBurstStartIfNeeded()
        scheduleCommit()
    }
    
    // MARK: Commit + Undo
    
    private func captureUndoBurstStartIfNeeded() {
        if undoBurstStartText == nil {
            undoBurstStartText = parent.text
        }
    }
    
    private func scheduleCommit() {
        // Don't schedule commits during undo/redo operations
        guard !isPerformingUndoRedo else { return }
        
        commitTimer?.invalidate()
        let timer = Timer(timeInterval: commitDelay, target: self, selector: #selector(commitTimerFired(_:)), userInfo: nil, repeats: false)
        commitTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }
    
    @objc private func commitTimerFired(_ timer: Timer) {
        Task { @MainActor in
            self.commitNow()
        }
    }
    
    private func commitNow() {
        guard let tv = textView else { return }
        
        // Capture the previous state for undo (from burst start or current)
        let previousText = undoBurstStartText ?? parent.text
        let newText = tv.text ?? ""
        
        // Skip if nothing changed
        guard newText != previousText else {
            undoBurstStartText = nil
            return
        }
        
        // Register undo action BEFORE updating the binding
        let um = externalUndoManager ?? textView?.undoManager
        if let um, !isPerformingUndoRedo {
            // Capture current values for the undo closure
            let capturedPrevious = previousText
            
            um.registerUndo(withTarget: self) { coordinator in
                // Prevent redo registration during undo
                coordinator.isPerformingUndoRedo = true
                
                // Update SwiftUI binding
                coordinator.parent.text = capturedPrevious
                coordinator.lastObservedText = capturedPrevious
                
                // Update text view content
                if let tv = coordinator.textView {
                    let savedSelection = tv.selectedRange
                    tv.text = capturedPrevious
                    tv.selectedRange = coordinator.clampedSelection(savedSelection, toLength: capturedPrevious.count)
                }
                
                // Small delay before allowing new commits
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    coordinator.isPerformingUndoRedo = false
                }
            }
            um.setActionName("Edit")
        }
        
        // Now update the current state
        markInternalUpdate()
        parent.text = newText
        lastObservedText = newText
        
        // Reset burst tracker
        undoBurstStartText = nil
    }
}

// Fix the typealias to match
typealias Coordinator = PlainTextEditorCoordinator

extension PlainTextEditor {
    // Helper to make the Coordinator accessible
    typealias Coordinator = PlainTextEditorCoordinator
}
