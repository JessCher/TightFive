//
//  RichTextEditor.swift
//  TightFive
//
//  World-class SwiftUI Rich Text Editor (UIKit-backed)
//  - SwiftUI wrapper around UITextView
//  - SRP: Coordinator orchestrates; engines mutate; toolbar renders
//  - Cursor stability: internal-update guard + Data equality gate (no RTF byte compare loops)
//  - Performance: debounced RTF persistence (default 300ms), non-contiguous layout
//  - Undo: burst-grouped (captures state at burst start, registers undo on commit)
//  - Smart text: -- → — , ... → … (both include trailing space)
//  - Lists: bullets, numbered, checkbox; continuation + exit behavior
//  - Indent-safe list toggling (does not destroy leading tabs/spaces)
//
//  NOTE: If your project already defines NSAttributedString.fromRTF / rtfData in exactly one place,
//  remove the "RTF Helpers" section at the bottom to avoid duplicate symbol errors.
//

import SwiftUI
import UIKit

// MARK: - Public API

struct RichTextEditor: UIViewRepresentable {
    @Binding var rtfData: Data
    var undoManager: UndoManager?
    @Environment(\.undoManager) private var envUndo

    func makeCoordinator() -> EditorCoordinator {
        EditorCoordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        configure(textView: tv)
        context.coordinator.attach(to: tv, undoManager: undoManager ?? envUndo)
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        context.coordinator.externalUndoManager = undoManager ?? envUndo
        context.coordinator.updateFromSwiftUI(newRTFData: rtfData, in: uiView)
    }

    private func configure(textView: UITextView) {
        // Visual
        textView.backgroundColor = .clear
        textView.textColor = .white
        textView.font = UIFont.preferredFont(forTextStyle: .body)

        // Smart typing
        textView.autocapitalizationType = .sentences
        textView.autocorrectionType = .yes
        textView.spellCheckingType = .yes
        textView.smartQuotesType = .yes
        textView.smartDashesType = .yes
        textView.smartInsertDeleteType = .yes

        // Interaction + performance
        textView.isScrollEnabled = true
        textView.isEditable = true
        textView.isUserInteractionEnabled = true
        textView.layoutManager.allowsNonContiguousLayout = true

        textView.isSelectable = true
        textView.allowsEditingTextAttributes = true
        textView.delaysContentTouches = false
        textView.isMultipleTouchEnabled = true
        textView.panGestureRecognizer.cancelsTouchesInView = false
        // Ensure no tap-to-dismiss behavior; rely on interactive swipe-down
        textView.keyboardDismissMode = .interactive
    }
}

// MARK: - Coordinator

@MainActor
final class EditorCoordinator: NSObject, UITextViewDelegate {

    // Wiring
    private var parent: RichTextEditor
    weak var textView: UITextView?
    var externalUndoManager: UndoManager? { didSet { observeUndoManager(externalUndoManager) } }

    // Engines (SRP)
    private let attributesEngine = TextAttributesEngine()
    private let listEngine = ListFormattingEngine()
    private let smartTextEngine = SmartTextEngine()

    // Toolbar
    private lazy var toolbar = EditorToolbar(delegate: self)

    // Sync + persistence
    private var internalUpdateFlag = false
    private var lastObservedData: Data = Data()
    
    private var isPerformingUndoRedo = false
    private var undoObservationTokens: [NSObjectProtocol] = []

    private var commitTimer: Timer?
    private let commitDelay: TimeInterval = 0.30

    // Undo grouping
    private var undoBurstStartData: Data?

    init(parent: RichTextEditor) {
        self.parent = parent
        super.init()
    }

    func attach(to textView: UITextView, undoManager: UndoManager?) {
        self.textView = textView
        self.externalUndoManager = undoManager
        observeUndoManager(self.externalUndoManager)

        textView.delegate = self
        textView.inputAccessoryView = toolbar

        // Make sure selection gestures work well and avoid any tap-to-dismiss gestures fighting selection
        textView.gestureRecognizers?.forEach { gr in
            // Do not allow generic UITapGestureRecognizers on the text view to cancel touches
            if gr is UITapGestureRecognizer {
                gr.cancelsTouchesInView = false
            }
        }

        // Initial load
        if let attributed = NSAttributedString.fromRTF(parent.rtfData) {
            textView.attributedText = attributed
            lastObservedData = parent.rtfData
        } else {
            textView.attributedText = NSAttributedString(string: "")
            lastObservedData = Data()
        }

        attributesEngine.applyDefaults(to: textView)

        // Size the toolbar using a screen derived from context to avoid UIScreen.main deprecation
        // Clamp to a sensible minimum to avoid invalid (negative/zero/NaN) sizes when the view isn't in a window yet.
        let rawWidth: CGFloat = {
            if let w = textView.window, let scene = w.windowScene {
                return scene.screen.bounds.width
            }
            return textView.bounds.width
        }()
        let contextWidth = max(320, rawWidth.isFinite ? rawWidth : 320)
        toolbar.frame = CGRect(x: 0, y: 0, width: contextWidth, height: 60)

        textView.reloadInputViews()

        toolbar.updateState(for: textView, listMode: listEngine.currentListMode(in: textView))
    }

    // MARK: SwiftUI -> UIKit sync

    func updateFromSwiftUI(newRTFData: Data, in uiView: UITextView) {
        // If change originated from inside editor, ignore the next SwiftUI update to prevent loops.
        if consumeInternalUpdateFlag() { return }

        // Fast gate: if bytes are identical, don't touch the view.
        if newRTFData == lastObservedData { return }

        guard let incoming = NSAttributedString.fromRTF(newRTFData) else { return }

        let saved = uiView.selectedRange
        uiView.attributedText = incoming
        uiView.isSelectable = true
        uiView.selectedRange = clampedSelection(saved, toLength: incoming.length)

        lastObservedData = newRTFData
        attributesEngine.applyDefaults(to: uiView)
        toolbar.updateState(for: uiView, listMode: listEngine.currentListMode(in: uiView))
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
        toolbar.updateState(for: textView, listMode: listEngine.currentListMode(in: textView))
    }

    func textViewDidChangeSelection(_ textView: UITextView) {
        attributesEngine.syncTypingAttributes(to: textView)
        toolbar.updateState(for: textView, listMode: listEngine.currentListMode(in: textView))
    }

    func textView(_ textView: UITextView,
                  shouldChangeTextIn range: NSRange,
                  replacementText text: String) -> Bool {

        // Smart replacements (space-triggered)
        if smartTextEngine.handleSpaceTriggeredReplacements(in: textView, range: range, replacementText: text) {
            captureUndoBurstStartIfNeeded()
            scheduleCommit()
            toolbar.updateState(for: textView, listMode: listEngine.currentListMode(in: textView))
            return false
        }

        // Lists (return continuation / exit)
        if listEngine.handleReturnKeyIfNeeded(in: textView, range: range, replacementText: text) {
            captureUndoBurstStartIfNeeded()
            scheduleCommit()
            toolbar.updateState(for: textView, listMode: listEngine.currentListMode(in: textView))
            return false
        }

        return true
    }

    // MARK: Commit + Undo

    private func captureUndoBurstStartIfNeeded() {
        if undoBurstStartData == nil {
            undoBurstStartData = parent.rtfData
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
        // Ensure we execute on the main actor; Timer scheduled on main run loop already runs on main thread,
        // but we keep the annotation for clarity and future-proofing.
        Task { @MainActor in
            self.commitNow()
        }
    }

    private func commitNow() {
            guard let tv = textView else { return }

            // Capture the previous state for undo (from burst start or current)
            let previousData = undoBurstStartData ?? parent.rtfData

            // Serialize safely (never overwrite with empty due to failure)
            guard let newData = tv.attributedText.rtfData() else {
                #if DEBUG
                print("RichTextEditor: RTF serialization failed; preserving previous data.")
                #endif
                undoBurstStartData = nil
                return
            }

            // Skip if nothing changed
            guard newData != previousData else {
                undoBurstStartData = nil
                return
            }

            // Register undo action BEFORE updating the binding
            let um = externalUndoManager ?? textView?.undoManager
            if let um, !isPerformingUndoRedo {
                // Capture current values for the undo closure
                let capturedPrevious = previousData
                
                um.registerUndo(withTarget: self) { coordinator in
                    // Prevent redo registration during undo
                    coordinator.isPerformingUndoRedo = true
                    
                    // Update SwiftUI binding
                    coordinator.parent.rtfData = capturedPrevious
                    coordinator.lastObservedData = capturedPrevious
                    
                    // Update text view content
                    if let attributed = NSAttributedString.fromRTF(capturedPrevious),
                       let tv = coordinator.textView {
                        let savedSelection = tv.selectedRange
                        tv.attributedText = attributed
                        tv.selectedRange = coordinator.clampedSelection(savedSelection, toLength: attributed.length)
                    }
                    
                    // Small delay before allowing new commits to prevent rapid undo/redo confusion
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        coordinator.isPerformingUndoRedo = false
                    }
                }
                um.setActionName("Edit")
            }

            // Now update the current state
            markInternalUpdate()
            parent.rtfData = newData
            lastObservedData = newData

            // Reset burst tracker
            undoBurstStartData = nil
        }
}

// MARK: - Toolbar Delegate

extension EditorCoordinator: EditorToolbarDelegate {
    func executeAction(_ action: EditorToolbarAction) {
        guard let tv = textView else { return }

        // Formatting actions start a burst if needed.
        captureUndoBurstStartIfNeeded()

        switch action {
        case .dismissKeyboard:
            tv.resignFirstResponder()

        case .adjustFontSize(let delta):
            attributesEngine.adjustFontSize(in: tv, by: delta)

        case .toggleTrait(let trait):
            attributesEngine.toggleTrait(trait, in: tv)

        case .toggleAttribute(let key):
            attributesEngine.toggleToggleAttribute(key, in: tv)

        case .setColor(let color):
            attributesEngine.setColor(color, in: tv)

        case .toggleList(let mode):
            listEngine.toggleListMode(mode, in: tv, using: attributesEngine)

        case .indent(let direction):
            if direction == .forward { listEngine.indent(in: tv) }
            else { listEngine.outdent(in: tv) }
        }

        scheduleCommit()
        toolbar.updateState(for: tv, listMode: listEngine.currentListMode(in: tv))
    }

    // Local helper to keep the action extension clean
    private func beginUndoBurstIfNeeded() {
        // Call through to coordinator’s method
        // (Swift doesn't allow direct access to the private method name from extension in some styles,
        // so we keep this tiny wrapper.)
        (self as EditorCoordinator).captureUndoBurstStartIfNeeded()
    }
}

// MARK: - Toolbar Types

protocol EditorToolbarDelegate: AnyObject {
    func executeAction(_ action: EditorToolbarAction)
}

enum EditorToolbarAction {
    case dismissKeyboard
    case adjustFontSize(CGFloat)
    case toggleTrait(UIFontDescriptor.SymbolicTraits)
    case toggleAttribute(NSAttributedString.Key)
    case setColor(UIColor)
    case toggleList(ListFormattingEngine.ListMode)
    case indent(IndentDirection)

    enum IndentDirection { case forward, backward }
}

// MARK: - Toolbar View (UIKit)

final class EditorToolbar: UIView {
    private var boldButton: UIButton?
    private var italicButton: UIButton?
    private var underlineButton: UIButton?
    private var strikeButton: UIButton?
    private var bulletButton: UIButton?
    private var numberButton: UIButton?
    private var checkButton: UIButton?
    private var colorButton: UIButton?

    private let scrollView = UIScrollView()
    private let stackView = UIStackView()

    // Buttons we need to update for active state

    init(delegate: EditorToolbarDelegate) {
        self.delegate = delegate
        super.init(frame: CGRect(x: 0, y: 0, width: 0, height: 60))
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private weak var delegate: EditorToolbarDelegate?

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

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsHorizontalScrollIndicator = false
        container.addSubview(scrollView)

        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.alignment = .center
        scrollView.addSubview(stackView)

        NSLayoutConstraint.activate([
            shadowHost.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            shadowHost.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            shadowHost.centerYAnchor.constraint(equalTo: centerYAnchor),
            shadowHost.heightAnchor.constraint(equalToConstant: 50),

            container.leadingAnchor.constraint(equalTo: shadowHost.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: shadowHost.trailingAnchor),
            container.topAnchor.constraint(equalTo: shadowHost.topAnchor),
            container.bottomAnchor.constraint(equalTo: shadowHost.bottomAnchor),

            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 6),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -6),
            scrollView.topAnchor.constraint(equalTo: container.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stackView.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor),
            stackView.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ])

        populate()
    }

    private func populate() {
        // Typography
        stackView.addArrangedSubview(pill("A−", a11y: "Decrease font size") { [weak self] in
            self?.delegate?.executeAction(.adjustFontSize(-1))
        })
        stackView.addArrangedSubview(pill("A+", a11y: "Increase font size") { [weak self] in
            self?.delegate?.executeAction(.adjustFontSize(1))
        })

        // Styles
        boldButton = pill("B", a11y: "Bold") { [weak self] in
            self?.delegate?.executeAction(.toggleTrait(.traitBold))
        }
        boldButton?.isAccessibilityElement = true
        italicButton = pill("I", a11y: "Italic") { [weak self] in
            self?.delegate?.executeAction(.toggleTrait(.traitItalic))
        }
        italicButton?.isAccessibilityElement = true
        underlineButton = pill("U", a11y: "Underline") { [weak self] in
            self?.delegate?.executeAction(.toggleAttribute(.underlineStyle))
        }
        underlineButton?.isAccessibilityElement = true
        strikeButton = pill("S", a11y: "Strikethrough") { [weak self] in
            self?.delegate?.executeAction(.toggleAttribute(.strikethroughStyle))
        }
        strikeButton?.isAccessibilityElement = true

        if let b = boldButton { stackView.addArrangedSubview(b) }
        if let i = italicButton { stackView.addArrangedSubview(i) }
        if let u = underlineButton { stackView.addArrangedSubview(u) }
        if let s = strikeButton { stackView.addArrangedSubview(s) }

        // Lists
        bulletButton = pill("•", a11y: "Bulleted list") { [weak self] in
            self?.delegate?.executeAction(.toggleList(.bullets))
        }
        numberButton = pill("1.", a11y: "Numbered list") { [weak self] in
            self?.delegate?.executeAction(.toggleList(.numbers))
        }
        checkButton = pill("☐", a11y: "Checklist") { [weak self] in
            self?.delegate?.executeAction(.toggleList(.checkbox))
        }

        if let b = bulletButton { stackView.addArrangedSubview(b) }
        if let n = numberButton { stackView.addArrangedSubview(n) }
        if let c = checkButton { stackView.addArrangedSubview(c) }

        // Indent
        stackView.addArrangedSubview(pill("→", a11y: "Indent") { [weak self] in
            self?.delegate?.executeAction(.indent(.forward))
        })
        stackView.addArrangedSubview(pill("←", a11y: "Outdent") { [weak self] in
            self?.delegate?.executeAction(.indent(.backward))
        })

        // Color menu
        let colorBtn = menuPill("Color", a11y: "Text color")
        colorBtn.widthAnchor.constraint(equalToConstant: 60).isActive = true
        colorButton = colorBtn
        configureColorMenu(on: colorBtn)
        stackView.addArrangedSubview(colorBtn)

        // Done
        let done = pill("Done", a11y: "Done editing") { [weak self] in
            self?.delegate?.executeAction(.dismissKeyboard)
        }
        done.widthAnchor.constraint(equalToConstant: 60).isActive = true
        var cfg = done.configuration ?? UIButton.Configuration.filled()
        let tfYellow = UIColor(named: "TFYellow") ?? UIColor(red: 0.95, green: 0.76, blue: 0.09, alpha: 1.0)
        cfg.baseBackgroundColor = tfYellow
        cfg.baseForegroundColor = .black
        cfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming
            out.font = UIFont.systemFont(ofSize: 15, weight: .bold)
            return out
        }
        done.configuration = cfg
        stackView.addArrangedSubview(done)
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

    private func menuPill(_ title: String, a11y: String) -> UIButton {
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

        let btn = UIButton(configuration: config)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.accessibilityLabel = a11y
        btn.showsMenuAsPrimaryAction = true
        NSLayoutConstraint.activate([
            btn.heightAnchor.constraint(equalToConstant: 36)
        ])
        return btn
    }

    private func configureColorMenu(on button: UIButton) {
        let colors: [(String, UIColor)] = [
            ("White", .white),
            ("Yellow", UIColor(red: 0.95, green: 0.75, blue: 0.10, alpha: 1.0)),
            ("Blue", .systemBlue),
            ("Red", .systemRed),
            ("Green", .systemGreen),
            ("Gray", .lightGray)
        ]

        let actions = colors.map { name, color in
            UIAction(title: name) { [weak self] _ in
                self?.delegate?.executeAction(.setColor(color))
            }
        }

        button.menu = UIMenu(title: "Text Color", children: actions)
    }

    // State updates
    func updateState(for textView: UITextView, listMode: ListFormattingEngine.ListMode?) {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.updateState(for: textView, listMode: listMode)
            }
            return
        }

        let font = (textView.typingAttributes[.font] as? UIFont) ?? UIFont.systemFont(ofSize: 17)
        let traits = font.fontDescriptor.symbolicTraits

        setActive(boldButton, traits.contains(.traitBold))
        setActive(italicButton, traits.contains(.traitItalic))

        let underlineOn = ((textView.typingAttributes[.underlineStyle] as? Int) ?? 0) != 0
        let strikeOn = ((textView.typingAttributes[.strikethroughStyle] as? Int) ?? 0) != 0
        setActive(underlineButton, underlineOn)
        setActive(strikeButton, strikeOn)

        setActive(bulletButton, listMode == .bullets)
        setActive(numberButton, listMode == .numbers)
        setActive(checkButton, listMode == .checkbox)

        if let cb = colorButton,
           let c = (textView.typingAttributes[.foregroundColor] as? UIColor) {
            cb.layer.borderWidth = 2
            cb.layer.borderColor = c.withAlphaComponent(0.75).cgColor
            cb.layer.cornerRadius = 18
            cb.layer.masksToBounds = true
        }
    }

    private func setActive(_ button: UIButton?, _ active: Bool) {
        guard let btn = button else { return }
        var cfg = btn.configuration ?? UIButton.Configuration.filled()

        if active {
            let tfYellow = UIColor(named: "TFYellow") ?? UIColor(red: 0.95, green: 0.75, blue: 0.10, alpha: 1.0)
            cfg.baseBackgroundColor = tfYellow.withAlphaComponent(0.5)
            cfg.baseForegroundColor = .white
        } else {
            cfg.baseBackgroundColor = UIColor.white.withAlphaComponent(0.08)
            cfg.baseForegroundColor = .white
        }

        btn.configuration = cfg
        btn.accessibilityValue = active ? "On" : "Off"
    }
}

// MARK: - Engine: Attributes

final class TextAttributesEngine {
    private let defaultFontSize: CGFloat = 17
    private let minFontSize: CGFloat = 12
    private let maxFontSize: CGFloat = 32
    private let defaultColor: UIColor = .white

    func applyDefaults(to textView: UITextView) {
        textView.allowsEditingTextAttributes = true
        textView.dataDetectorTypes = []

        var ta = textView.typingAttributes

        if ta[.font] == nil {
            ta[.font] = UIFont.systemFont(ofSize: defaultFontSize)
        }
        if ta[.foregroundColor] == nil {
            ta[.foregroundColor] = defaultColor
        }
        if ta[.paragraphStyle] == nil {
            ta[.paragraphStyle] = NSParagraphStyle.defaultTightFive
        }

        textView.typingAttributes = ta
        textView.textColor = (ta[.foregroundColor] as? UIColor) ?? defaultColor
    }

    func syncTypingAttributes(to textView: UITextView) {
        if textView.typingAttributes[.paragraphStyle] == nil {
            textView.typingAttributes[.paragraphStyle] = NSParagraphStyle.defaultTightFive
        }
        if textView.typingAttributes[.foregroundColor] == nil {
            textView.typingAttributes[.foregroundColor] = defaultColor
        }
        if textView.typingAttributes[.font] == nil {
            textView.typingAttributes[.font] = UIFont.systemFont(ofSize: defaultFontSize)
        }
    }

    func toggleTrait(_ trait: UIFontDescriptor.SymbolicTraits, in textView: UITextView) {
        transformFonts(in: textView) { font in
            let current = font.fontDescriptor.symbolicTraits
            let next = current.contains(trait) ? current.subtracting(trait) : current.union(trait)
            let desc = font.fontDescriptor.withSymbolicTraits(next) ?? font.fontDescriptor
            return UIFont(descriptor: desc, size: font.pointSize)
        }
    }

    func adjustFontSize(in textView: UITextView, by delta: CGFloat) {
        transformFonts(in: textView) { font in
            let newSize = min(max(font.pointSize + delta, minFontSize), maxFontSize)
            return font.withSize(newSize)
        }
    }

    func setColor(_ color: UIColor, in textView: UITextView) {
        let range = textView.selectedRange
        if range.length > 0 {
            textView.textStorage.addAttribute(.foregroundColor, value: color, range: range)
        }
        textView.typingAttributes[.foregroundColor] = color
    }

    func toggleToggleAttribute(_ key: NSAttributedString.Key, in textView: UITextView) {
        let range = textView.selectedRange

        // No selection: toggle typing attribute
        if range.length == 0 {
            let current = (textView.typingAttributes[key] as? Int) ?? 0
            if current == 0 {
                // Underline + strikethrough styles both use NSUnderlineStyle raw values.
                textView.typingAttributes[key] = NSUnderlineStyle.single.rawValue
            } else {
                textView.typingAttributes.removeValue(forKey: key)
            }
            return
        }

        // Selection: toggle based on first char
        let existing = (textView.attributedText.attribute(key, at: range.location, effectiveRange: nil) as? Int) ?? 0
        let newValue = (existing == 0) ? NSUnderlineStyle.single.rawValue : 0

        if newValue == 0 {
            textView.textStorage.removeAttribute(key, range: range)
        } else {
            textView.textStorage.addAttribute(key, value: newValue, range: range)
        }

        // Keep typing attributes in sync with last applied value
        if range.length > 0 {
            let applied = (textView.attributedText.attribute(key, at: max(range.location - 1, 0), effectiveRange: nil) as? Int) ?? 0
            if applied == 0 {
                textView.typingAttributes.removeValue(forKey: key)
            } else {
                textView.typingAttributes[key] = applied
            }
        }
    }

    // DRY: safe font transformation across selection + typing attributes
    private func transformFonts(in textView: UITextView, transform: (UIFont) -> UIFont) {
        let range = textView.selectedRange

        if range.length > 0 {
            let storage = textView.textStorage
            storage.beginEditing()
            storage.enumerateAttribute(.font, in: range, options: []) { value, subRange, _ in
                let oldFont = (value as? UIFont) ?? UIFont.systemFont(ofSize: defaultFontSize)
                let newFont = transform(oldFont)
                storage.addAttribute(.font, value: newFont, range: subRange)

                if storage.attribute(.paragraphStyle, at: subRange.location, effectiveRange: nil) == nil {
                    storage.addAttribute(.paragraphStyle, value: NSParagraphStyle.defaultTightFive, range: subRange)
                }
            }
            storage.endEditing()
        }

        let typingFont = (textView.typingAttributes[.font] as? UIFont) ?? UIFont.systemFont(ofSize: defaultFontSize)
        textView.typingAttributes[.font] = transform(typingFont)

        if textView.typingAttributes[.paragraphStyle] == nil {
            textView.typingAttributes[.paragraphStyle] = NSParagraphStyle.defaultTightFive
        }
    }
}

// MARK: - Engine: Smart Text

final class SmartTextEngine {
    func handleSpaceTriggeredReplacements(in textView: UITextView, range: NSRange, replacementText text: String) -> Bool {
        guard text == " " else { return false }
        let nsText = textView.text as NSString? ?? ""

        // "--" => "— "
        if range.location >= 2 {
            let lastTwoRange = NSRange(location: range.location - 2, length: 2)
            if lastTwoRange.location >= 0, lastTwoRange.location + lastTwoRange.length <= nsText.length {
                if nsText.substring(with: lastTwoRange) == "--" {
                    replace(in: textView, range: lastTwoRange, with: "— ")
                    return true
                }
            }
        }

        // "..." => "… "
        if range.location >= 3 {
            let lastThreeRange = NSRange(location: range.location - 3, length: 3)
            if lastThreeRange.location >= 0, lastThreeRange.location + lastThreeRange.length <= nsText.length {
                if nsText.substring(with: lastThreeRange) == "..." {
                    replace(in: textView, range: lastThreeRange, with: "… ")
                    return true
                }
            }
        }

        return false
    }

    private func replace(in textView: UITextView, range: NSRange, with replacement: String) {
        let storage = textView.textStorage
        storage.beginEditing()

        // Preserve current typing attrs for inserted text
        let attrs = textView.typingAttributes
        let rep = NSAttributedString(string: replacement, attributes: attrs)
        storage.replaceCharacters(in: range, with: rep)

        storage.endEditing()

        let newLoc = range.location + (replacement as NSString).length
        textView.selectedRange = NSRange(location: newLoc, length: 0)
    }
}

// MARK: - Engine: Lists

final class ListFormattingEngine {

    enum ListMode: Equatable {
        case bullets
        case numbers
        case checkbox
    }

    private static let numberPrefixRegex: NSRegularExpression = {
        try! NSRegularExpression(pattern: #"^(\d+)\.\s"#)
    }()

    private let bullet = "• "
    private let checkbox = "☐ "
    private let checkboxChecked = "☑ "

    func currentListMode(in textView: UITextView) -> ListMode? {
        let (line, _) = currentLine(in: textView)
        guard let prefix = detectPrefix(in: line) else { return nil }
        if prefix == bullet { return .bullets }
        if prefix == checkbox || prefix == checkboxChecked { return .checkbox }
        if isNumberPrefix(prefix) { return .numbers }
        return nil
    }

    func handleReturnKeyIfNeeded(in textView: UITextView, range: NSRange, replacementText text: String) -> Bool {
        guard text == "\n" else { return false }

        let (line, lineRange) = currentLine(in: textView)

        // Exit list if empty item
        if let prefix = detectPrefix(in: line), isEmptyListItem(line: line, prefix: prefix) {
            // Replace line with an attributed newline for consistency
            let attrs = textView.typingAttributes
            let newline = NSAttributedString(string: "\n", attributes: attrs)
            textView.textStorage.replaceCharacters(in: lineRange, with: newline)
            textView.selectedRange = NSRange(location: lineRange.location + 1, length: 0)
            return true
        }

        // Continue list
        if let prefix = detectPrefix(in: line) {
            let next = nextPrefix(from: prefix)
            let insertion = "\n" + next

            let attrs = textView.typingAttributes
            let insertionAttr = NSMutableAttributedString(string: insertion, attributes: attrs)

            // Ensure list prefix stays visible in white
            let prefixRange = NSRange(location: 1, length: (next as NSString).length)
            insertionAttr.addAttribute(.foregroundColor, value: UIColor.white, range: prefixRange)

            textView.textStorage.replaceCharacters(in: range, with: insertionAttr)
            textView.selectedRange = NSRange(location: range.location + 1 + (next as NSString).length, length: 0)
            return true
        }

        return false
    }

    // Indent-safe toggle
    func toggleListMode(_ mode: ListMode, in textView: UITextView, using attributesEngine: TextAttributesEngine) {
        let (line, lineRange) = currentLine(in: textView)
        let indentOffset = firstNonIndentIndex(in: line)
        let prefixIndex = lineRange.location + indentOffset

        let desiredPrefix: String
        switch mode {
        case .bullets: desiredPrefix = bullet
        case .numbers: desiredPrefix = "1. "
        case .checkbox: desiredPrefix = checkbox
        }

        if let existing = detectPrefix(in: line) {
            let removeLen = (existing as NSString).length
            textView.textStorage.deleteCharacters(in: NSRange(location: prefixIndex, length: removeLen))

            if existing != desiredPrefix {
                insertPrefix(desiredPrefix, at: prefixIndex, in: textView)
            } else {
                // If we removed the active prefix, keep cursor sensible.
                let loc = textView.selectedRange.location
                textView.selectedRange = NSRange(location: max(prefixIndex, loc - removeLen), length: 0)
            }
        } else {
            insertPrefix(desiredPrefix, at: prefixIndex, in: textView)
        }

        attributesEngine.syncTypingAttributes(to: textView)
    }

    func indent(in textView: UITextView) {
        let loc = textView.selectedRange.location
        let lineRange = (textView.text as NSString? ?? "").lineRange(for: NSRange(location: loc, length: 0))
        textView.textStorage.insert(NSAttributedString(string: "\t", attributes: textView.typingAttributes), at: lineRange.location)
        textView.selectedRange = NSRange(location: loc + 1, length: 0)
    }

    func outdent(in textView: UITextView) {
        let loc = textView.selectedRange.location
        let ns = textView.text as NSString? ?? ""
        let lineRange = ns.lineRange(for: NSRange(location: loc, length: 0))
        let line = ns.substring(with: lineRange)

        if line.hasPrefix("\t") {
            textView.textStorage.deleteCharacters(in: NSRange(location: lineRange.location, length: 1))
            textView.selectedRange = NSRange(location: max(loc - 1, lineRange.location), length: 0)
            return
        }

        let fourSpaces = "    "
        if line.hasPrefix(fourSpaces) {
            textView.textStorage.deleteCharacters(in: NSRange(location: lineRange.location, length: 4))
            textView.selectedRange = NSRange(location: max(loc - 4, lineRange.location), length: 0)
            return
        }
    }

    // MARK: Helpers

    private func currentLine(in textView: UITextView) -> (line: String, range: NSRange) {
        let ns = textView.text as NSString? ?? ""
        let cursor = textView.selectedRange.location
        let lineRange = ns.lineRange(for: NSRange(location: cursor, length: 0))
        let line = ns.substring(with: lineRange)
        return (line, lineRange)
    }

    private func firstNonIndentIndex(in line: String) -> Int {
        let leading = line.prefix { $0 == " " || $0 == "\t" }
        return (String(leading) as NSString).length
    }

    private func insertPrefix(_ prefix: String, at location: Int, in textView: UITextView) {
        var attrs = textView.typingAttributes
        attrs[.foregroundColor] = UIColor.white // prefix always visible
        let attr = NSAttributedString(string: prefix, attributes: attrs)

        textView.textStorage.insert(attr, at: location)
        textView.selectedRange = NSRange(location: location + (prefix as NSString).length, length: 0)
    }

    private func detectPrefix(in line: String) -> String? {
        let trimmedLeading = line.drop { $0 == " " || $0 == "\t" }
        let s = String(trimmedLeading)

        if s.hasPrefix(bullet) { return bullet }
        if s.hasPrefix(checkbox) { return checkbox }
        if s.hasPrefix(checkboxChecked) { return checkboxChecked }

        let range = NSRange(location: 0, length: s.utf16.count)
        if let match = Self.numberPrefixRegex.firstMatch(in: s, range: range) {
            return (s as NSString).substring(with: match.range)
        }

        return nil
    }

    private func isNumberPrefix(_ prefix: String) -> Bool {
        let range = NSRange(location: 0, length: prefix.utf16.count)
        return Self.numberPrefixRegex.firstMatch(in: prefix, range: range) != nil
    }

    private func nextPrefix(from prefix: String) -> String {
        if isNumberPrefix(prefix) {
            let range = NSRange(location: 0, length: prefix.utf16.count)
            guard let match = Self.numberPrefixRegex.firstMatch(in: prefix, range: range),
                  match.numberOfRanges >= 2 else { return prefix }

            let ns = prefix as NSString
            let nStr = ns.substring(with: match.range(at: 1))
            let n = Int(nStr) ?? 1
            return "\(n + 1). "
        }

        // Bullets/checkboxes repeat
        return prefix == checkboxChecked ? checkbox : prefix
    }

    private func isEmptyListItem(line: String, prefix: String) -> Bool {
        let trimmedLeading = line.drop { $0 == " " || $0 == "\t" }
        let s = String(trimmedLeading)

        guard s.hasPrefix(prefix) else { return false }
        let remainder = String(s.dropFirst(prefix.count))
        return remainder.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - TightFive Paragraph Defaults

extension NSParagraphStyle {
    static var defaultTightFive: NSParagraphStyle {
        let ps = NSMutableParagraphStyle()
        ps.lineSpacing = 4
        ps.paragraphSpacing = 12
        ps.lineHeightMultiple = 1.2
        return ps
    }
}



