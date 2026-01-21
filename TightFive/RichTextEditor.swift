import SwiftUI
import UIKit

struct RichTextEditor: UIViewRepresentable {
    @Binding var rtfData: Data

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.backgroundColor = .clear
        tv.keyboardDismissMode = .none
        tv.textContainerInset = UIEdgeInsets(top: 16, left: 14, bottom: 24, right: 14)
        tv.delegate = context.coordinator
        context.coordinator.textView = tv

        // Load existing RTF
        if let attributed = NSAttributedString.fromRTF(rtfData) {
            tv.attributedText = attributed
        } else {
            tv.attributedText = NSAttributedString(string: "")
        }

        context.coordinator.applyDefaultTypingAttributes()
        tv.inputAccessoryView = context.coordinator.makeFloatingAccessoryBar()

        // initial state
        context.coordinator.updateFormatButtonStates()

        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        let current = uiView.attributedText.rtfData() ?? Data()
        if current != rtfData, let attributed = NSAttributedString.fromRTF(rtfData) {
            uiView.attributedText = attributed
            context.coordinator.applyDefaultTypingAttributes()
            context.coordinator.updateFormatButtonStates()
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        let parent: RichTextEditor
        weak var textView: UITextView?

        // MARK: - Formatting state
        private var currentFontSize: CGFloat = 17
        private let minFontSize: CGFloat = 12
        private let maxFontSize: CGFloat = 32
        private var currentTextColor: UIColor = .white

        // MARK: - Button refs for highlight state
        private weak var boldButton: UIButton?
        private weak var italicButton: UIButton?
        private weak var underlineButton: UIButton?
        private weak var strikeButton: UIButton?

        // One color menu button
        private weak var colorMenuButton: UIButton?

        // MARK: - UI constants
        private let barHeight: CGFloat = 66            // taller than before
        private let buttonW: CGFloat = 44              // universal size
        private let buttonH: CGFloat = 36              // universal size
        private let buttonCorner: UIButton.Configuration.CornerStyle = .capsule

        init(_ parent: RichTextEditor) {
            self.parent = parent
            super.init()
        }

        // MARK: - UITextView delegate
        func textViewDidChange(_ textView: UITextView) {
            parent.rtfData = textView.attributedText.rtfData() ?? Data()
            updateFormatButtonStates()
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            normalizeTypingAttributes()
            updateFormatButtonStates()
        }

        // Notes-like list continuation on return
        func textView(_ textView: UITextView,
                      shouldChangeTextIn range: NSRange,
                      replacementText text: String) -> Bool {

            if text == "\n" {
                let ns = textView.text as NSString? ?? ""
                let lineRange = ns.lineRange(for: NSRange(location: range.location, length: 0))
                let line = ns.substring(with: lineRange)

                // Empty list item? Exit list by removing prefix
                if isEmptyListItem(line) {
                    removeAnyListPrefix(atLineStart: lineRange.location, lineText: line)
                    textView.insertText("\n")
                    return false
                }

                if let prefix = listPrefixToContinue(for: line) {
                    textView.insertText("\n")
                    insertListPrefix(prefix) // inserts prefix in WHITE
                    return false
                }
            }

            return true
        }

        // MARK: - Defaults
        func applyDefaultTypingAttributes() {
            guard let tv = textView else { return }
            currentFontSize = UIFont.preferredFont(forTextStyle: .body).pointSize
            currentTextColor = .white
            tv.typingAttributes = [
                .font: UIFont.systemFont(ofSize: currentFontSize),
                .foregroundColor: currentTextColor
            ]
            tv.textColor = currentTextColor
        }

        private func normalizeTypingAttributes() {
            guard let tv = textView else { return }

            // keep current color
            tv.typingAttributes[.foregroundColor] = currentTextColor

            // keep font size and traits if possible
            let f = (tv.typingAttributes[.font] as? UIFont) ?? UIFont.systemFont(ofSize: currentFontSize)
            currentFontSize = f.pointSize
            tv.typingAttributes[.font] = f
        }

        // MARK: - Floating accessory bar
        func makeFloatingAccessoryBar() -> UIView {
            let container = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: barHeight))
            container.backgroundColor = .clear

            // Floating blur pill
            let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
            blur.translatesAutoresizingMaskIntoConstraints = false
            blur.layer.cornerRadius = 20
            blur.clipsToBounds = true

            // Shadow host
            let shadowHost = UIView()
            shadowHost.translatesAutoresizingMaskIntoConstraints = false
            shadowHost.backgroundColor = .clear
            shadowHost.layer.shadowColor = UIColor.black.cgColor
            shadowHost.layer.shadowOpacity = 0.35
            shadowHost.layer.shadowRadius = 18
            shadowHost.layer.shadowOffset = CGSize(width: 0, height: 10)

            let scroll = UIScrollView()
            scroll.translatesAutoresizingMaskIntoConstraints = false
            scroll.showsHorizontalScrollIndicator = false

            let stack = UIStackView()
            stack.axis = .horizontal
            stack.spacing = 10
            stack.alignment = .center
            stack.translatesAutoresizingMaskIntoConstraints = false
            stack.setContentHuggingPriority(.required, for: .vertical)
            stack.setContentCompressionResistancePriority(.required, for: .vertical)

            func makePillButton(_ title: String, action: Selector) -> UIButton {
                var config = UIButton.Configuration.filled()
                config.baseBackgroundColor = UIColor.white.withAlphaComponent(0.10)
                config.baseForegroundColor = UIColor.white
                config.cornerStyle = buttonCorner
                config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 0, bottom: 10, trailing: 0)
                config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                    var out = incoming
                    out.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
                    return out
                }

                let b = UIButton(configuration: config)
                b.setTitle(title, for: .normal)
                b.addTarget(self, action: action, for: .touchUpInside)

                b.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    b.widthAnchor.constraint(equalToConstant: buttonW),
                    b.heightAnchor.constraint(equalToConstant: buttonH)
                ])
                return b
            }

            // Font size (moved to front)
            stack.addArrangedSubview(makePillButton("A−", action: #selector(decreaseFontSize)))
            stack.addArrangedSubview(makePillButton("A+", action: #selector(increaseFontSize)))

            // Formatting buttons (store refs so we can highlight them)
            let bBold = makePillButton("B", action: #selector(boldTapped))
            let bItalic = makePillButton("I", action: #selector(italicTapped))
            let bUnderline = makePillButton("U", action: #selector(underlineTapped))
            let bStrike = makePillButton("S", action: #selector(strikeTapped))
            boldButton = bBold
            italicButton = bItalic
            underlineButton = bUnderline
            strikeButton = bStrike

            stack.addArrangedSubview(bBold)
            stack.addArrangedSubview(bItalic)
            stack.addArrangedSubview(bUnderline)
            stack.addArrangedSubview(bStrike)

            // Lists
            stack.addArrangedSubview(makePillButton("•", action: #selector(toggleBullets)))
            stack.addArrangedSubview(makePillButton("1.", action: #selector(toggleNumbers)))
            stack.addArrangedSubview(makePillButton("☐", action: #selector(toggleCheckbox)))

            // Indent
            stack.addArrangedSubview(makePillButton("⇥", action: #selector(indent)))
            stack.addArrangedSubview(makePillButton("⇤", action: #selector(outdent)))

            // Headings (keep short)
            stack.addArrangedSubview(makePillButton("H1", action: #selector(heading1)))
            stack.addArrangedSubview(makePillButton("H2", action: #selector(heading2)))

            // Color menu button (single)
            let colorBtn = makePillButton("🎨", action: #selector(openColorMenu))
            colorMenuButton = colorBtn
            configureColorMenu(on: colorBtn)
            // Important: show menu on tap instead of calling action
            colorBtn.removeTarget(self, action: #selector(openColorMenu), for: .touchUpInside)
            colorBtn.showsMenuAsPrimaryAction = true

            stack.addArrangedSubview(colorBtn)

            // Clear + Done (still universal size)
            stack.addArrangedSubview(makePillButton("Clr", action: #selector(clearFormatting)))

            let done = makePillButton("Done", action: #selector(doneTapped))
            done.configuration?.baseBackgroundColor = UIColor.systemBlue.withAlphaComponent(0.85)
            done.configuration?.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                var out = incoming
                out.font = UIFont.systemFont(ofSize: 13, weight: .bold)
                return out
            }
            stack.addArrangedSubview(done)

            container.addSubview(shadowHost)
            shadowHost.addSubview(blur)
            blur.contentView.addSubview(scroll)
            scroll.addSubview(stack)

            NSLayoutConstraint.activate([
                shadowHost.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
                shadowHost.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
                shadowHost.topAnchor.constraint(equalTo: container.topAnchor, constant: 6),
                shadowHost.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10),

                blur.leadingAnchor.constraint(equalTo: shadowHost.leadingAnchor),
                blur.trailingAnchor.constraint(equalTo: shadowHost.trailingAnchor),
                blur.topAnchor.constraint(equalTo: shadowHost.topAnchor),
                blur.bottomAnchor.constraint(equalTo: shadowHost.bottomAnchor),

                scroll.leadingAnchor.constraint(equalTo: blur.contentView.leadingAnchor, constant: 10),
                scroll.trailingAnchor.constraint(equalTo: blur.contentView.trailingAnchor, constant: -10),
                scroll.topAnchor.constraint(equalTo: blur.contentView.topAnchor, constant: 8),
                scroll.bottomAnchor.constraint(equalTo: blur.contentView.bottomAnchor, constant: -8),

                stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
                stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
                stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
                stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor)
                // Removed: stack.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor)
            ])

            // Defensive: remove any accidental equal-height constraints on the stack
            for c in stack.constraints {
                if (c.firstAttribute == .height && c.relation == .equal && c.secondItem != nil) {
                    c.isActive = false
                }
            }

            // set initial highlight states
            updateFormatButtonStates()

            return container
        }

        // MARK: - Color menu
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
                    self?.setColor(color)
                    self?.updateColorButtonAppearance()
                }
            }

            button.menu = UIMenu(title: "Text Color", children: actions)
            updateColorButtonAppearance()
        }

        private func updateColorButtonAppearance() {
            guard let btn = colorMenuButton else { return }
            // Subtle border color to indicate current selection
            btn.layer.borderWidth = 1
            btn.layer.borderColor = currentTextColor.withAlphaComponent(0.65).cgColor
            btn.layer.cornerRadius = 18
        }

        // MARK: - Toggle highlight states
        func updateFormatButtonStates() {
            guard let tv = textView else { return }
            let attrs = currentAttributesAtCursor(tv)

            let isBold = (attrs.font?.fontDescriptor.symbolicTraits.contains(.traitBold) ?? false)
            let isItalic = (attrs.font?.fontDescriptor.symbolicTraits.contains(.traitItalic) ?? false)
            let isUnderline = (attrs.underlineStyle ?? 0) != 0
            let isStrike = (attrs.strikeStyle ?? 0) != 0

            setButton(boldButton, active: isBold)
            setButton(italicButton, active: isItalic)
            setButton(underlineButton, active: isUnderline)
            setButton(strikeButton, active: isStrike)

            // keep color menu border updated too
            updateColorButtonAppearance()
        }

        private func setButton(_ button: UIButton?, active: Bool) {
            guard let b = button else { return }
            var config = b.configuration ?? UIButton.Configuration.filled()
            config.baseBackgroundColor = active
                ? UIColor.systemYellow.withAlphaComponent(0.40)
                : UIColor.white.withAlphaComponent(0.10)
            config.baseForegroundColor = .white
            b.configuration = config
        }

        private struct CursorAttributes {
            var font: UIFont?
            var underlineStyle: Int?
            var strikeStyle: Int?
        }

        private func currentAttributesAtCursor(_ tv: UITextView) -> CursorAttributes {
            let loc = max(min(tv.selectedRange.location, tv.attributedText.length - 1), 0)
            if tv.attributedText.length == 0 {
                let f = (tv.typingAttributes[.font] as? UIFont) ?? UIFont.systemFont(ofSize: currentFontSize)
                return CursorAttributes(font: f, underlineStyle: 0, strikeStyle: 0)
            }

            let f = tv.attributedText.attribute(.font, at: loc, effectiveRange: nil) as? UIFont
            let u = tv.attributedText.attribute(.underlineStyle, at: loc, effectiveRange: nil) as? Int
            let s = tv.attributedText.attribute(.strikethroughStyle, at: loc, effectiveRange: nil) as? Int
            return CursorAttributes(font: f, underlineStyle: u, strikeStyle: s)
        }

        // Safely clamp a selection to a valid target range within the given attributed string
        private func clampedTargetRange(for attr: NSAttributedString, selection: NSRange) -> NSRange {
            let length = attr.length
            if length == 0 { return NSRange(location: 0, length: 0) }
            let start = max(0, min(selection.location, length - 1))
            let requested = max(selection.length, 1)
            let available = max(0, length - start)
            let finalLen = min(requested, available)
            return NSRange(location: start, length: finalLen)
        }

        // MARK: - Actions

        @objc func doneTapped() { textView?.resignFirstResponder() }
        // Removed focusTextView per instructions

        @objc private func boldTapped() { toggleTrait(.traitBold) }
        @objc private func italicTapped() { toggleTrait(.traitItalic) }
        @objc private func underlineTapped() { toggleUnderline() }
        @objc private func strikeTapped() { toggleStrikethrough() }

        @objc func heading1() { applyFont(size: 24, weight: .bold) }
        @objc func heading2() { applyFont(size: 20, weight: .semibold) }

        @objc func decreaseFontSize() {
            currentFontSize = max(minFontSize, currentFontSize - 1)
            applyFont(size: currentFontSize, weight: .regular, keepTraits: true)
        }

        @objc func increaseFontSize() {
            currentFontSize = min(maxFontSize, currentFontSize + 1)
            applyFont(size: currentFontSize, weight: .regular, keepTraits: true)
        }

        @objc func openColorMenu() { /* menu handled automatically */ }

        @objc func clearFormatting() {
            guard let tv = textView else { return }
            let range = tv.selectedRange
            let attr = NSMutableAttributedString(attributedString: tv.attributedText)
            let target = clampedTargetRange(for: attr, selection: range)

            attr.setAttributes([
                .font: UIFont.systemFont(ofSize: currentFontSize),
                .foregroundColor: currentTextColor
            ], range: target)

            tv.attributedText = attr
            tv.selectedRange = range
            tv.typingAttributes[.font] = UIFont.systemFont(ofSize: currentFontSize)
            tv.typingAttributes[.foregroundColor] = currentTextColor

            parent.rtfData = tv.attributedText.rtfData() ?? Data()
            updateFormatButtonStates()
        }

        // MARK: - Color
        private func setColor(_ color: UIColor) {
            guard let tv = textView else { return }
            currentTextColor = color

            let range = tv.selectedRange
            if range.length > 0 {
                let attr = NSMutableAttributedString(attributedString: tv.attributedText)
                attr.addAttribute(.foregroundColor, value: color, range: range)
                tv.attributedText = attr
                tv.selectedRange = range
                parent.rtfData = tv.attributedText.rtfData() ?? Data()
            }

            tv.typingAttributes[.foregroundColor] = color
        }

        // MARK: - Lists (toggle + prefix always white)
        @objc func toggleBullets() { toggleListPrefix("• ") }
        @objc func toggleCheckbox() { toggleListPrefix("☐ ") }

        @objc func toggleNumbers() {
            guard let tv = textView else { return }
            let cursor = tv.selectedRange.location
            let ns = tv.text as NSString? ?? ""
            let lineRange = ns.lineRange(for: NSRange(location: cursor, length: 0))
            let line = ns.substring(with: lineRange)

            if numberPrefix(line) != nil {
                removeNumberPrefix(atLineStart: lineRange.location, lineText: line)
            } else {
                insertListPrefix("1. ", at: lineRange.location)
            }
        }

        @objc func indent() { prefixLine("    ") }
        @objc func outdent() { removeLeadingSpaces(count: 4) }

        private func toggleListPrefix(_ prefix: String) {
            guard let tv = textView else { return }
            let cursor = tv.selectedRange.location
            let ns = tv.text as NSString? ?? ""
            let lineRange = ns.lineRange(for: NSRange(location: cursor, length: 0))
            let line = ns.substring(with: lineRange)

            if line.hasPrefix(prefix) {
                removePrefix(exact: prefix, atLineStart: lineRange.location, lineText: line)
            } else {
                removeAnyListPrefix(atLineStart: lineRange.location, lineText: line)
                removeNumberPrefix(atLineStart: lineRange.location, lineText: line)
                insertListPrefix(prefix, at: lineRange.location)
            }
        }

        private func insertListPrefix(_ prefix: String, at location: Int? = nil) {
            guard let tv = textView else { return }
            let loc = location ?? tv.selectedRange.location
            let attr = NSMutableAttributedString(attributedString: tv.attributedText)

            let safeLoc = max(0, min(loc, attr.length))

            // Prefix is always WHITE so it never disappears
            let font = (tv.typingAttributes[.font] as? UIFont) ?? UIFont.systemFont(ofSize: currentFontSize)
            let prefixAttr = NSAttributedString(string: prefix, attributes: [
                .font: font,
                .foregroundColor: UIColor.white
            ])

            attr.insert(prefixAttr, at: safeLoc)
            tv.attributedText = attr
            tv.selectedRange = NSRange(location: safeLoc + prefix.count, length: 0)
            parent.rtfData = tv.attributedText.rtfData() ?? Data()
        }

        private func removeAnyListPrefix(atLineStart lineStart: Int, lineText: String) {
            removePrefix(exact: "• ", atLineStart: lineStart, lineText: lineText)
            removePrefix(exact: "☐ ", atLineStart: lineStart, lineText: lineText)
            removePrefix(exact: "☑ ", atLineStart: lineStart, lineText: lineText)
        }

        private func removePrefix(exact prefix: String, atLineStart lineStart: Int, lineText: String) {
            guard let tv = textView else { return }
            guard lineText.hasPrefix(prefix) else { return }

            let attr = NSMutableAttributedString(attributedString: tv.attributedText)
            attr.deleteCharacters(in: NSRange(location: lineStart, length: prefix.count))
            tv.attributedText = attr
            parent.rtfData = tv.attributedText.rtfData() ?? Data()
        }

        private func removeNumberPrefix(atLineStart lineStart: Int, lineText: String) {
            guard let tv = textView else { return }
            guard let re = try? NSRegularExpression(pattern: #"^\d+\.\s"#),
                  let match = re.firstMatch(in: lineText, range: NSRange(location: 0, length: lineText.utf16.count))
            else { return }

            let attr = NSMutableAttributedString(attributedString: tv.attributedText)
            attr.deleteCharacters(in: NSRange(location: lineStart, length: match.range.length))
            tv.attributedText = attr
            parent.rtfData = tv.attributedText.rtfData() ?? Data()
        }

        private func prefixLine(_ prefix: String) {
            guard let tv = textView else { return }
            let cursor = tv.selectedRange.location
            let ns = tv.text as NSString? ?? ""
            let lineRange = ns.lineRange(for: NSRange(location: cursor, length: 0))

            let attr = NSMutableAttributedString(attributedString: tv.attributedText)
            let insertion = NSAttributedString(string: prefix, attributes: [
                .font: UIFont.systemFont(ofSize: currentFontSize),
                .foregroundColor: currentTextColor
            ])
            attr.insert(insertion, at: lineRange.location)
            tv.attributedText = attr
            tv.selectedRange = NSRange(location: lineRange.location + prefix.count, length: 0)
            parent.rtfData = tv.attributedText.rtfData() ?? Data()
        }

        private func removeLeadingSpaces(count: Int) {
            guard let tv = textView else { return }
            let cursor = tv.selectedRange.location
            let ns = tv.text as NSString? ?? ""
            let lineRange = ns.lineRange(for: NSRange(location: cursor, length: 0))
            let line = ns.substring(with: lineRange)

            let spaces = String(repeating: " ", count: count)
            guard line.hasPrefix(spaces) else { return }

            let attr = NSMutableAttributedString(attributedString: tv.attributedText)
            attr.deleteCharacters(in: NSRange(location: lineRange.location, length: count))
            tv.attributedText = attr
            parent.rtfData = tv.attributedText.rtfData() ?? Data()
        }

        // MARK: - Traits / underline / strike / fonts

        private func toggleTrait(_ trait: UIFontDescriptor.SymbolicTraits) {
            guard let tv = textView else { return }
            let range = tv.selectedRange
            let attr = NSMutableAttributedString(attributedString: tv.attributedText)
            let target = clampedTargetRange(for: attr, selection: range)

            attr.enumerateAttribute(.font, in: target) { value, subrange, _ in
                let current = (value as? UIFont) ?? UIFont.systemFont(ofSize: currentFontSize)
                var traits = current.fontDescriptor.symbolicTraits
                if traits.contains(trait) { traits.remove(trait) } else { traits.insert(trait) }

                let desc = current.fontDescriptor.withSymbolicTraits(traits) ?? current.fontDescriptor
                let updated = UIFont(descriptor: desc, size: current.pointSize)
                attr.addAttribute(.font, value: updated, range: subrange)
                attr.addAttribute(.foregroundColor, value: currentTextColor, range: subrange)
            }

            tv.attributedText = attr
            tv.selectedRange = range
            parent.rtfData = tv.attributedText.rtfData() ?? Data()
            updateFormatButtonStates()
        }

        private func toggleUnderline() {
            guard let tv = textView else { return }
            let range = tv.selectedRange
            let attr = NSMutableAttributedString(attributedString: tv.attributedText)
            let target = clampedTargetRange(for: attr, selection: range)
            let current = attr.attribute(.underlineStyle, at: target.location, effectiveRange: nil) as? Int ?? 0
            let newValue = (current == 0) ? NSUnderlineStyle.single.rawValue : 0
            attr.addAttribute(.underlineStyle, value: newValue, range: target)
            attr.addAttribute(.foregroundColor, value: currentTextColor, range: target)
            tv.attributedText = attr
            tv.selectedRange = range
            parent.rtfData = tv.attributedText.rtfData() ?? Data()
            updateFormatButtonStates()
        }

        private func toggleStrikethrough() {
            guard let tv = textView else { return }
            let range = tv.selectedRange
            let attr = NSMutableAttributedString(attributedString: tv.attributedText)
            let target = clampedTargetRange(for: attr, selection: range)
            let current = attr.attribute(.strikethroughStyle, at: target.location, effectiveRange: nil) as? Int ?? 0
            let newValue = (current == 0) ? NSUnderlineStyle.single.rawValue : 0
            attr.addAttribute(.strikethroughStyle, value: newValue, range: target)
            attr.addAttribute(.foregroundColor, value: currentTextColor, range: target)
            tv.attributedText = attr
            tv.selectedRange = range
            parent.rtfData = tv.attributedText.rtfData() ?? Data()
            updateFormatButtonStates()
        }

        private func applyFont(size: CGFloat, weight: UIFont.Weight, keepTraits: Bool = false) {
            guard let tv = textView else { return }
            let range = tv.selectedRange
            let attr = NSMutableAttributedString(attributedString: tv.attributedText)
            let target = clampedTargetRange(for: attr, selection: range)

            if keepTraits {
                attr.enumerateAttribute(.font, in: target) { value, subrange, _ in
                    let current = (value as? UIFont) ?? UIFont.systemFont(ofSize: currentFontSize)
                    let traits = current.fontDescriptor.symbolicTraits

                    let base = UIFont.systemFont(ofSize: size, weight: weight)
                    let desc = base.fontDescriptor.withSymbolicTraits(traits) ?? base.fontDescriptor
                    let updated = UIFont(descriptor: desc, size: size)

                    attr.addAttribute(.font, value: updated, range: subrange)
                    attr.addAttribute(.foregroundColor, value: currentTextColor, range: subrange)
                }
            } else {
                let font = UIFont.systemFont(ofSize: size, weight: weight)
                attr.addAttribute(.font, value: font, range: target)
                attr.addAttribute(.foregroundColor, value: currentTextColor, range: target)
            }

            tv.attributedText = attr
            tv.selectedRange = range
            tv.typingAttributes[.font] = UIFont.systemFont(ofSize: size, weight: weight)
            tv.typingAttributes[.foregroundColor] = currentTextColor
            parent.rtfData = tv.attributedText.rtfData() ?? Data()
            updateFormatButtonStates()
        }

        // MARK: - Line analysis helpers
        private func isEmptyListItem(_ line: String) -> Bool {
            // Treat a line as an empty list item if it is exactly a list prefix (with optional leading spaces)
            // and contains no additional non-whitespace characters after the prefix.
            let trimmedLeading = line.drop { $0 == " " || $0 == "\t" }
            let prefixes = ["• ", "☐ ", "☑ "]
            for p in prefixes {
                if trimmedLeading.hasPrefix(p) {
                    let rest = trimmedLeading.dropFirst(p.count)
                    return rest.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                }
            }
            // Numbered list like "1. "
            if let n = numberPrefix(String(trimmedLeading)), n >= 1 {
                // remove the matched number prefix from the start
                // pattern is one or more digits + ". "
                if let re = try? NSRegularExpression(pattern: "^\\d+\\.\\s"),
                   let match = re.firstMatch(in: String(trimmedLeading), range: NSRange(location: 0, length: String(trimmedLeading).utf16.count)) {
                    let ns = String(trimmedLeading) as NSString
                    let rest = ns.substring(from: match.range.length)
                    return rest.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                }
            }
            return false
        }

        private func listPrefixToContinue(for line: String) -> String? {
            // Decide which list prefix to continue on a new line based on the current line
            let trimmedLeading = line.drop { $0 == " " || $0 == "\t" }

            if trimmedLeading.hasPrefix("• ") { return "• " }
            if trimmedLeading.hasPrefix("☐ ") { return "☐ " }
            if trimmedLeading.hasPrefix("☑ ") { return "☑ " }

            // Numbered list: increment the detected number
            if let n = numberPrefix(String(trimmedLeading)) {
                return "\(n + 1). "
            }

            return nil
        }

        private func numberPrefix(_ line: String) -> Int? {
            let pattern = #"^(\d+)\.\s"#
            guard let re = try? NSRegularExpression(pattern: pattern),
                  let match = re.firstMatch(in: line, range: NSRange(location: 0, length: line.utf16.count)),
                  match.numberOfRanges >= 2 else { return nil }

            let ns = line as NSString
            let nStr = ns.substring(with: match.range(at: 1))
            return Int(nStr)
        }
    }
}

// MARK: - RTF helpers
private extension NSAttributedString {
    static func fromRTF(_ data: Data) -> NSAttributedString? {
        guard !data.isEmpty else { return NSAttributedString(string: "") }
        return try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        )
    }

    func rtfData() -> Data? {
        try? data(
            from: NSRange(location: 0, length: length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )
    }
}

