import SwiftUI
import UIKit

struct RichTextEditor: UIViewRepresentable {
    @Binding var rtfData: Data

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        
        // CRITICAL FIX 1: Give the coordinator a reference to the text view
        context.coordinator.textView = textView
        textView.delegate = context.coordinator
        
        // VISUAL CONFIG
        textView.backgroundColor = .clear
        textView.textColor = .white
        textView.font = UIFont.systemFont(ofSize: 17)
        
        // BEHAVIOR CONFIG
        textView.isScrollEnabled = true
        textView.isEditable = true
        textView.isUserInteractionEnabled = true
        
        // KEYBOARD DISMISSAL: Use .interactive for built-in swipe-to-dismiss
        // This works in combination with the SwiftUI gesture handlers
        textView.keyboardDismissMode = .interactive
        
        // Set the initial RTF data
        // Uses the helper from RTFHelpers.swift if available, or standard init
        if let attributedString = try? NSAttributedString(
            data: rtfData,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        ) {
            textView.attributedText = attributedString
        }
        
        // CRITICAL FIX 2: Use your custom Floating Bar
        textView.inputAccessoryView = context.coordinator.makeFloatingAccessoryBar()
        
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        // Only update if the data has actually changed to prevent cursor jumping
        // Relies on RTFHelpers.swift for .rtfData() and .fromRTF()
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
        private let barHeight: CGFloat = 60           // Slightly more compact
        private let buttonW: CGFloat = 44             // universal size
        private let buttonH: CGFloat = 36             // universal size
        private let buttonCorner: UIButton.Configuration.CornerStyle = .capsule

        init(_ parent: RichTextEditor) {
            self.parent = parent
            super.init()
        }

        // MARK: - UITextView delegate
        func textViewDidChange(_ textView: UITextView) {
            // Relies on RTFHelpers.swift
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

            // Brand-styled card background
            let cardBackground = UIView()
            cardBackground.translatesAutoresizingMaskIntoConstraints = false
            cardBackground.backgroundColor = UIColor(named: "TFCard") ?? UIColor(white: 0.15, alpha: 1.0)
            cardBackground.layer.cornerRadius = 20 // Match TFTheme corner radius
            cardBackground.clipsToBounds = false
            
            // Subtle stroke border (matching TFCardStroke)
            cardBackground.layer.borderWidth = 1
            cardBackground.layer.borderColor = (UIColor(named: "TFCardStroke") ?? UIColor.white.withAlphaComponent(0.2)).cgColor

            // Shadow host (matching brand shadow style)
            let shadowHost = UIView()
            shadowHost.translatesAutoresizingMaskIntoConstraints = false
            shadowHost.backgroundColor = .clear
            shadowHost.layer.shadowColor = UIColor.black.cgColor
            shadowHost.layer.shadowOpacity = 0.28 // Match TFTheme shadow
            shadowHost.layer.shadowRadius = 18
            shadowHost.layer.shadowOffset = CGSize(width: 0, height: 12) // Match brand y:12

            let scroll = UIScrollView()
            scroll.translatesAutoresizingMaskIntoConstraints = false
            scroll.showsHorizontalScrollIndicator = false

            let stack = UIStackView()
            stack.axis = .horizontal
            stack.spacing = 8
            stack.alignment = .center
            stack.translatesAutoresizingMaskIntoConstraints = false

            func makePillButton(_ title: String, action: Selector) -> UIButton {
                var config = UIButton.Configuration.filled()
                // Brand-styled button background (subtle white overlay on card)
                config.baseBackgroundColor = UIColor.white.withAlphaComponent(0.08)
                config.baseForegroundColor = UIColor.white
                config.cornerStyle = .capsule // Keep capsule for pill shape
                config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0)
                config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                    var out = incoming
                    out.font = UIFont.systemFont(ofSize: 15, weight: .semibold) // Slightly bolder for brand
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

            // --- TOOLBAR ITEMS ---
            
            // 1. Font Size
            stack.addArrangedSubview(makePillButton("A−", action: #selector(decreaseFontSize)))
            stack.addArrangedSubview(makePillButton("A+", action: #selector(increaseFontSize)))

            // 2. Formatting (BIUS)
            let bBold = makePillButton("B", action: #selector(boldTapped))
            let bItalic = makePillButton("I", action: #selector(italicTapped))
            let bUnderline = makePillButton("U", action: #selector(underlineTapped))
            let bStrike = makePillButton("S", action: #selector(strikeTapped))
            
            // Adjust fonts for icons
            bBold.titleLabel?.font = .systemFont(ofSize: 15, weight: .bold)
            bItalic.titleLabel?.font = .italicSystemFont(ofSize: 15)
            
            boldButton = bBold
            italicButton = bItalic
            underlineButton = bUnderline
            strikeButton = bStrike

            stack.addArrangedSubview(bBold)
            stack.addArrangedSubview(bItalic)
            stack.addArrangedSubview(bUnderline)
            stack.addArrangedSubview(bStrike)

            // 3. Lists
            stack.addArrangedSubview(makePillButton("•", action: #selector(toggleBullets)))
            stack.addArrangedSubview(makePillButton("1.", action: #selector(toggleNumbers)))
            stack.addArrangedSubview(makePillButton("☐", action: #selector(toggleCheckbox)))

            // 4. Indent
            stack.addArrangedSubview(makePillButton("→", action: #selector(indent)))
            stack.addArrangedSubview(makePillButton("←", action: #selector(outdent)))

            // 5. Headings
            stack.addArrangedSubview(makePillButton("H1", action: #selector(heading1)))
            stack.addArrangedSubview(makePillButton("H2", action: #selector(heading2)))

            // 6. Color
            let colorBtn = makePillButton("Color", action: #selector(openColorMenu))
            // Override width for "Color" text
            colorBtn.removeConstraints(colorBtn.constraints.filter { $0.firstAttribute == .width })
            colorBtn.widthAnchor.constraint(equalToConstant: 60).isActive = true
            
            colorMenuButton = colorBtn
            configureColorMenu(on: colorBtn)
            colorBtn.removeTarget(self, action: #selector(openColorMenu), for: .touchUpInside)
            colorBtn.showsMenuAsPrimaryAction = true
            stack.addArrangedSubview(colorBtn)

            // 7. Done Button (BRAND YELLOW - Primary action)
            let done = makePillButton("Done", action: #selector(doneTapped))
            // Use TFYellow from assets or fallback to brand yellow
            let tfYellow = UIColor(named: "TFYellow") ?? UIColor(red: 0.95, green: 0.76, blue: 0.09, alpha: 1.0)
            done.configuration?.baseBackgroundColor = tfYellow
            done.configuration?.baseForegroundColor = .black // Black text on yellow
            done.configuration?.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                var out = incoming
                out.font = UIFont.systemFont(ofSize: 15, weight: .bold) // Match button weight
                return out
            }
            // Override width for "Done"
            done.removeConstraints(done.constraints.filter { $0.firstAttribute == .width })
            done.widthAnchor.constraint(equalToConstant: 60).isActive = true
            
            stack.addArrangedSubview(done)

            // Layout
            container.addSubview(shadowHost)
            shadowHost.addSubview(cardBackground)
            cardBackground.addSubview(scroll)
            scroll.addSubview(stack)

            NSLayoutConstraint.activate([
                shadowHost.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
                shadowHost.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
                shadowHost.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                shadowHost.heightAnchor.constraint(equalToConstant: 50),

                cardBackground.leadingAnchor.constraint(equalTo: shadowHost.leadingAnchor),
                cardBackground.trailingAnchor.constraint(equalTo: shadowHost.trailingAnchor),
                cardBackground.topAnchor.constraint(equalTo: shadowHost.topAnchor),
                cardBackground.bottomAnchor.constraint(equalTo: shadowHost.bottomAnchor),

                scroll.leadingAnchor.constraint(equalTo: cardBackground.leadingAnchor, constant: 6),
                scroll.trailingAnchor.constraint(equalTo: cardBackground.trailingAnchor, constant: -6),
                scroll.topAnchor.constraint(equalTo: cardBackground.topAnchor),
                scroll.bottomAnchor.constraint(equalTo: cardBackground.bottomAnchor),

                stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
                stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
                stack.centerYAnchor.constraint(equalTo: scroll.centerYAnchor),
                stack.heightAnchor.constraint(equalTo: scroll.heightAnchor)
            ])

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
            // Subtle colored border showing current text color
            btn.layer.borderWidth = 2
            btn.layer.borderColor = currentTextColor.withAlphaComponent(0.75).cgColor
            btn.layer.cornerRadius = 18 // Match brand corner radius
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

            updateColorButtonAppearance()
        }

        private func setButton(_ button: UIButton?, active: Bool) {
            guard let b = button else { return }
            var config = b.configuration ?? UIButton.Configuration.filled()
            
            if active {
                // Active state: Use TFYellow from assets or fallback
                let tfYellow = UIColor(named: "TFYellow") ?? UIColor(red: 0.95, green: 0.75, blue: 0.10, alpha: 1.0)
                config.baseBackgroundColor = tfYellow.withAlphaComponent(0.5)
                config.baseForegroundColor = .white
            } else {
                // Inactive state: Subtle white overlay
                config.baseBackgroundColor = UIColor.white.withAlphaComponent(0.08)
                config.baseForegroundColor = .white
            }
            
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

        // MARK: - Font Formatting
        private func toggleTrait(_ trait: UIFontDescriptor.SymbolicTraits) {
            guard let tv = textView else { return }
            let range = tv.selectedRange
            let attr = NSMutableAttributedString(attributedString: tv.attributedText)
            
            if range.length > 0 {
                let target = clampedTargetRange(for: attr, selection: range)
                attr.enumerateAttribute(.font, in: target) { value, subrange, _ in
                    let currentFont = (value as? UIFont) ?? UIFont.systemFont(ofSize: currentFontSize)
                    let newFont = toggleFontTrait(currentFont, trait: trait)
                    attr.addAttribute(.font, value: newFont, range: subrange)
                }
                tv.attributedText = attr
                tv.selectedRange = range
            }
            
            // Update typing attributes
            let currentFont = (tv.typingAttributes[.font] as? UIFont) ?? UIFont.systemFont(ofSize: currentFontSize)
            let newFont = toggleFontTrait(currentFont, trait: trait)
            tv.typingAttributes[.font] = newFont
            
            parent.rtfData = tv.attributedText.rtfData() ?? Data()
            updateFormatButtonStates()
        }
        
        private func toggleFontTrait(_ font: UIFont, trait: UIFontDescriptor.SymbolicTraits) -> UIFont {
            let descriptor = font.fontDescriptor
            let currentTraits = descriptor.symbolicTraits
            let newTraits = currentTraits.contains(trait) 
                ? currentTraits.subtracting(trait)
                : currentTraits.union(trait)
            
            guard let newDescriptor = descriptor.withSymbolicTraits(newTraits) else {
                return font
            }
            return UIFont(descriptor: newDescriptor, size: font.pointSize)
        }
        
        private func toggleUnderline() {
            guard let tv = textView else { return }
            let range = tv.selectedRange
            let attr = NSMutableAttributedString(attributedString: tv.attributedText)
            
            if range.length > 0 {
                let target = clampedTargetRange(for: attr, selection: range)
                let existing = attr.attribute(.underlineStyle, at: target.location, effectiveRange: nil) as? Int ?? 0
                let newValue = existing == 0 ? NSUnderlineStyle.single.rawValue : 0
                
                if newValue == 0 {
                    attr.removeAttribute(.underlineStyle, range: target)
                } else {
                    attr.addAttribute(.underlineStyle, value: newValue, range: target)
                }
                tv.attributedText = attr
                tv.selectedRange = range
            }
            
            // Update typing attributes
            let existing = tv.typingAttributes[.underlineStyle] as? Int ?? 0
            let newValue = existing == 0 ? NSUnderlineStyle.single.rawValue : 0
            if newValue == 0 {
                tv.typingAttributes.removeValue(forKey: .underlineStyle)
            } else {
                tv.typingAttributes[.underlineStyle] = newValue
            }
            
            parent.rtfData = tv.attributedText.rtfData() ?? Data()
            updateFormatButtonStates()
        }
        
        private func toggleStrikethrough() {
            guard let tv = textView else { return }
            let range = tv.selectedRange
            let attr = NSMutableAttributedString(attributedString: tv.attributedText)
            
            if range.length > 0 {
                let target = clampedTargetRange(for: attr, selection: range)
                let existing = attr.attribute(.strikethroughStyle, at: target.location, effectiveRange: nil) as? Int ?? 0
                let newValue = existing == 0 ? NSUnderlineStyle.single.rawValue : 0
                
                if newValue == 0 {
                    attr.removeAttribute(.strikethroughStyle, range: target)
                } else {
                    attr.addAttribute(.strikethroughStyle, value: newValue, range: target)
                }
                tv.attributedText = attr
                tv.selectedRange = range
            }
            
            // Update typing attributes
            let existing = tv.typingAttributes[.strikethroughStyle] as? Int ?? 0
            let newValue = existing == 0 ? NSUnderlineStyle.single.rawValue : 0
            if newValue == 0 {
                tv.typingAttributes.removeValue(forKey: .strikethroughStyle)
            } else {
                tv.typingAttributes[.strikethroughStyle] = newValue
            }
            
            parent.rtfData = tv.attributedText.rtfData() ?? Data()
            updateFormatButtonStates()
        }
        
        private func applyFont(size: CGFloat, weight: UIFont.Weight, keepTraits: Bool = false) {
            guard let tv = textView else { return }
            currentFontSize = size
            let range = tv.selectedRange
            
            if range.length > 0 {
                let attr = NSMutableAttributedString(attributedString: tv.attributedText)
                let target = clampedTargetRange(for: attr, selection: range)
                
                attr.enumerateAttribute(.font, in: target) { value, subrange, _ in
                    let currentFont = (value as? UIFont) ?? UIFont.systemFont(ofSize: size)
                    let newFont: UIFont
                    
                    if keepTraits {
                        let descriptor = currentFont.fontDescriptor
                        let traits = descriptor.symbolicTraits
                        if let newDescriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body)
                            .withSymbolicTraits(traits) {
                            newFont = UIFont(descriptor: newDescriptor, size: size)
                        } else {
                            newFont = UIFont.systemFont(ofSize: size, weight: weight)
                        }
                    } else {
                        newFont = UIFont.systemFont(ofSize: size, weight: weight)
                    }
                    
                    attr.addAttribute(.font, value: newFont, range: subrange)
                }
                
                tv.attributedText = attr
                tv.selectedRange = range
            }
            
            // Update typing attributes
            let currentFont = (tv.typingAttributes[.font] as? UIFont) ?? UIFont.systemFont(ofSize: size)
            let newFont: UIFont
            
            if keepTraits {
                let descriptor = currentFont.fontDescriptor
                let traits = descriptor.symbolicTraits
                if let newDescriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body)
                    .withSymbolicTraits(traits) {
                    newFont = UIFont(descriptor: newDescriptor, size: size)
                } else {
                    newFont = UIFont.systemFont(ofSize: size, weight: weight)
                }
            } else {
                newFont = UIFont.systemFont(ofSize: size, weight: weight)
            }
            
            tv.typingAttributes[.font] = newFont
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

        // MARK: - Line analysis helpers
        private func isEmptyListItem(_ line: String) -> Bool {
            let trimmedLeading = line.drop { $0 == " " || $0 == "\t" }
            let prefixes = ["• ", "☐ ", "☑ "]
            for p in prefixes {
                if trimmedLeading.hasPrefix(p) {
                    let rest = trimmedLeading.dropFirst(p.count)
                    return rest.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                }
            }
            if let n = numberPrefix(String(trimmedLeading)), n >= 1 {
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
            let trimmedLeading = line.drop { $0 == " " || $0 == "\t" }
            if trimmedLeading.hasPrefix("• ") { return "• " }
            if trimmedLeading.hasPrefix("☐ ") { return "☐ " }
            if trimmedLeading.hasPrefix("☑ ") { return "☑ " }
            if let n = numberPrefix(String(trimmedLeading)) { return "\(n + 1). " }
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
