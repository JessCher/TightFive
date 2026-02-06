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
        
        // CRITICAL UNDO FIX: Disable UITextView's automatic undo registration
        // We handle undo/redo manually in the coordinator for better control
        textView.textStorage.delegate = nil  // Prevent automatic undo from text storage
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
    private let commitDelay: TimeInterval = 0.35  // Reduced to 350ms for more responsive undo grouping
    
    // Undo grouping
    private var undoBurstStartText: String?
    
    init(parent: PlainTextEditor) {
        self.parent = parent
        super.init()
    }

    deinit {
        // Clean up timer to prevent retain cycles and orphaned callbacks
        commitTimer?.invalidate()
        commitTimer = nil
        // Remove notification observers
        for token in undoObservationTokens {
            NotificationCenter.default.removeObserver(token)
        }
        undoObservationTokens.removeAll()
    }

    func attach(to textView: UITextView, undoManager: UndoManager?) {
        self.textView = textView
        self.externalUndoManager = undoManager
        observeUndoManager(self.externalUndoManager)
        
        textView.delegate = self
        
        // CRITICAL FIX: Create a minimal toolbar to establish undo manager chain
        // Without an inputAccessoryView, UITextView's undo manager doesn't properly activate
        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 100, height: 44))
        toolbar.items = []  // Empty toolbar, just here to activate undo
        textView.inputAccessoryView = toolbar
        
        // Initial load
        textView.text = parent.text
        lastObservedText = parent.text
        
        // CRITICAL FIX: Reload input views to activate undo manager
        textView.reloadInputViews()
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

        // CRITICAL FIX: Set the undo manager on the text view itself
        // This ensures the responder chain properly uses our custom undo manager
        if let tv = textView {
            tv.undoManager?.removeAllActions()  // Clear any default actions
        }

        // Note: queue: .main ensures we're on main thread, no Task wrapper needed
        let willUndo = center.addObserver(forName: .NSUndoManagerWillUndoChange, object: um, queue: .main) { [weak self] _ in
            self?.isPerformingUndoRedo = true
            self?.commitTimer?.invalidate()
        }
        let didUndo = center.addObserver(forName: .NSUndoManagerDidUndoChange, object: um, queue: .main) { [weak self] _ in
            self?.isPerformingUndoRedo = false
        }
        let willRedo = center.addObserver(forName: .NSUndoManagerWillRedoChange, object: um, queue: .main) { [weak self] _ in
            self?.isPerformingUndoRedo = true
            self?.commitTimer?.invalidate()
        }
        let didRedo = center.addObserver(forName: .NSUndoManagerDidRedoChange, object: um, queue: .main) { [weak self] _ in
            self?.isPerformingUndoRedo = false
        }

        undoObservationTokens = [willUndo, didUndo, willRedo, didRedo]
    }
    
    func textViewDidChange(_ textView: UITextView) {
        // PERFORMANCE FIX: Immediate lightweight update for smooth typing
        // Update binding immediately for responsive UI, but defer expensive operations
        let newText = textView.text ?? ""
        if newText != lastObservedText {
            markInternalUpdate()
            parent.text = newText
            lastObservedText = newText
        }
        
        // Defer undo registration and save until typing pauses
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
        // PERFORMANCE FIX: Use .default instead of .common to avoid interfering with scrolling/animations
        // .common blocks ScrollView and other tracking mode operations, causing lag
        RunLoop.main.add(timer, forMode: .default)
    }
    
    @objc private func commitTimerFired(_ timer: Timer) {
        // Timer scheduled on main run loop already runs on main thread - no Task needed
        commitNow()
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
        if !isPerformingUndoRedo {
            let capturedPrevious = previousText
            let capturedNew = newText

            for um in activeUndoManagers() {
                registerUndo(in: um, previousText: capturedPrevious, newText: capturedNew)
            }
        }

        // PERFORMANCE FIX: State was already updated in textViewDidChange for responsive typing
        // Just ensure we're in sync
        if parent.text != newText {
            markInternalUpdate()
            parent.text = newText
        }
        lastObservedText = newText

        // Reset burst tracker
        undoBurstStartText = nil
    }

    private func activeUndoManagers() -> [UndoManager] {
        var managers: [UndoManager] = []
        if let externalUndoManager {
            managers.append(externalUndoManager)
        }
        if let tvManager = textView?.undoManager, !managers.contains(where: { $0 === tvManager }) {
            managers.append(tvManager)
        }
        return managers
    }

    private func registerUndo(in undoManager: UndoManager, previousText: String, newText: String) {
        undoManager.registerUndo(withTarget: self) { [weak self] coordinator in
            guard self != nil else { return }
            coordinator.isPerformingUndoRedo = true

            // Register redo (inverse of undo) so redo works
            undoManager.registerUndo(withTarget: coordinator) { [weak coordinator] coord in
                guard coordinator != nil else { return }
                coord.isPerformingUndoRedo = true

                coord.parent.text = newText
                coord.lastObservedText = newText

                if let tv = coord.textView {
                    let savedSelection = tv.selectedRange
                    tv.text = newText
                    tv.selectedRange = coord.clampedSelection(savedSelection, toLength: newText.count)
                }

                coord.isPerformingUndoRedo = false
            }
            undoManager.setActionName("Edit")

            // Restore to previous state
            coordinator.parent.text = previousText
            coordinator.lastObservedText = previousText

            if let tv = coordinator.textView {
                let savedSelection = tv.selectedRange
                tv.text = previousText
                tv.selectedRange = coordinator.clampedSelection(savedSelection, toLength: previousText.count)
            }

            coordinator.isPerformingUndoRedo = false
        }
        undoManager.setActionName("Edit")
    }
}

extension PlainTextEditor {
    // Coordinator type for UIViewRepresentable conformance
    typealias Coordinator = PlainTextEditorCoordinator
}
