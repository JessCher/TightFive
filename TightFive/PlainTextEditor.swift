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
        
        // Keyboard accessory with undo/redo buttons
        textView.inputAccessoryView = PlainTextToolbar(textView: textView)

        PencilInputSupport.configure(textView)
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
// MARK: - Plain Text Toolbar

final class PlainTextToolbar: UIView {
    private weak var textView: UITextView?
    private var undoButton: UIButton?
    private var redoButton: UIButton?
    
    init(textView: UITextView) {
        self.textView = textView
        super.init(frame: CGRect(x: 0, y: 0, width: 0, height: 60))
        setup()
        
        // Observe undo manager changes to update button states
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateButtonStates),
            name: .NSUndoManagerDidUndoChange,
            object: textView.undoManager
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateButtonStates),
            name: .NSUndoManagerDidRedoChange,
            object: textView.undoManager
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateButtonStates),
            name: .NSUndoManagerDidCloseUndoGroup,
            object: textView.undoManager
        )
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setup() {
        backgroundColor = .clear
        
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = UIColor(named: "TFCard") ?? UIColor(white: 0.15, alpha: 1.0)
        container.layer.cornerRadius = 20
        container.layer.borderWidth = 1
        container.layer.borderColor = (UIColor(named: "TFCardStroke") ?? UIColor.white.withAlphaComponent(0.2)).cgColor
        
        let shadowHost = UIView()
        shadowHost.translatesAutoresizingMaskIntoConstraints = false
        shadowHost.backgroundColor = .clear
        shadowHost.layer.shadowColor = UIColor.black.cgColor
        shadowHost.layer.shadowOpacity = 0.28
        shadowHost.layer.shadowRadius = 18
        shadowHost.layer.shadowOffset = CGSize(width: 0, height: 12)
        
        addSubview(shadowHost)
        shadowHost.addSubview(container)
        
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.alignment = .center
        stackView.distribution = .equalSpacing
        container.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            shadowHost.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            shadowHost.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            shadowHost.centerYAnchor.constraint(equalTo: centerYAnchor),
            shadowHost.heightAnchor.constraint(equalToConstant: 50),
            
            container.leadingAnchor.constraint(equalTo: shadowHost.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: shadowHost.trailingAnchor),
            container.topAnchor.constraint(equalTo: shadowHost.topAnchor),
            container.bottomAnchor.constraint(equalTo: shadowHost.bottomAnchor),
            
            stackView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            stackView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            stackView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            stackView.heightAnchor.constraint(equalTo: container.heightAnchor)
        ])
        
        // Undo button
        undoButton = iconPill(systemName: "arrow.uturn.backward", a11y: "Undo") { [weak self] in
            self?.textView?.undoManager?.undo()
        }
        
        // Redo button
        redoButton = iconPill(systemName: "arrow.uturn.forward", a11y: "Redo") { [weak self] in
            self?.textView?.undoManager?.redo()
        }
        
        // Done button
        let doneButton = pill("Done", a11y: "Done editing") { [weak self] in
            self?.textView?.resignFirstResponder()
        }
        // Override the default 44pt width set by pill() for the wider "Done" label.
        // Remove the existing width constraint first to avoid conflicts.
        doneButton.constraints.first(where: { $0.firstAttribute == .width })?.isActive = false
        doneButton.widthAnchor.constraint(equalToConstant: 60).isActive = true
        var cfg = doneButton.configuration ?? UIButton.Configuration.filled()
        let tfYellow = UIColor(named: "TFYellow") ?? UIColor(red: 0.95, green: 0.76, blue: 0.09, alpha: 1.0)
        cfg.baseBackgroundColor = tfYellow
        cfg.baseForegroundColor = .black
        cfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming
            out.font = UIFont.systemFont(ofSize: 15, weight: .bold)
            return out
        }
        doneButton.configuration = cfg
        
        if let undo = undoButton { stackView.addArrangedSubview(undo) }
        if let redo = redoButton { stackView.addArrangedSubview(redo) }
        
        // Spacer
        let spacer = UIView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        stackView.addArrangedSubview(spacer)
        
        stackView.addArrangedSubview(doneButton)
        
        updateButtonStates()
    }
    
    private func pill(_ title: String, a11y: String, action: @escaping () -> Void) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.title = title
        config.baseBackgroundColor = UIColor.white.withAlphaComponent(0.08)
        config.baseForegroundColor = .white
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming
            out.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
            return out
        }
        
        let btn = UIButton(configuration: config, primaryAction: UIAction { _ in action() })
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.accessibilityLabel = a11y
        NSLayoutConstraint.activate([
            btn.widthAnchor.constraint(equalToConstant: 44),
            btn.heightAnchor.constraint(equalToConstant: 36)
        ])
        return btn
    }
    
    private func iconPill(systemName: String, a11y: String, action: @escaping () -> Void) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.image = UIImage(systemName: systemName)
        config.baseBackgroundColor = UIColor.white.withAlphaComponent(0.08)
        config.baseForegroundColor = .white
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0)
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)

        let btn = UIButton(configuration: config, primaryAction: UIAction { _ in action() })
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.accessibilityLabel = a11y
        NSLayoutConstraint.activate([
            btn.widthAnchor.constraint(equalToConstant: 44),
            btn.heightAnchor.constraint(equalToConstant: 36)
        ])
        return btn
    }
    
    @objc private func updateButtonStates() {
        guard let undoManager = textView?.undoManager else { return }
        
        undoButton?.isEnabled = undoManager.canUndo
        undoButton?.alpha = undoManager.canUndo ? 1.0 : 0.3
        
        redoButton?.isEnabled = undoManager.canRedo
        redoButton?.alpha = undoManager.canRedo ? 1.0 : 0.3
    }
}
