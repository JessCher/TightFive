import UIKit

enum ExportHelpers {
    static func normalizeRTFColors(_ attributedString: NSAttributedString) -> Data? {
        let normalized = NSMutableAttributedString(attributedString: attributedString)
        normalized.enumerateAttribute(.foregroundColor, in: NSRange(location: 0, length: normalized.length)) { value, range, _ in
            if let color = value as? UIColor {
                var white: CGFloat = 0
                var alpha: CGFloat = 0

                if color.getWhite(&white, alpha: &alpha) {
                    if white > 0.7 {
                        normalized.addAttribute(.foregroundColor, value: UIColor.black, range: range)
                    }
                } else {
                    var red: CGFloat = 0
                    var green: CGFloat = 0
                    var blue: CGFloat = 0
                    if color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
                        let brightness = (red + green + blue) / 3.0
                        if brightness > 0.7 {
                            normalized.addAttribute(.foregroundColor, value: UIColor.black, range: range)
                        }
                    }
                }
            }
        }

        return try? normalized.data(from: NSRange(location: 0, length: normalized.length),
                                     documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
    }

    static func generatePDF(title: String, body: String) -> Data {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 50

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
        return renderer.pdfData { context in
            let titleFont = UIFont.boldSystemFont(ofSize: 22)
            let bodyFont = UIFont.systemFont(ofSize: 12)
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: UIColor.black
            ]

            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = 4
            let bodyAttributes: [NSAttributedString.Key: Any] = [
                .font: bodyFont,
                .foregroundColor: UIColor.black,
                .paragraphStyle: paragraphStyle
            ]

            let drawableWidth = pageWidth - (margin * 2)

            context.beginPage()
            var currentY = margin

            let titleHeight = title.boundingRect(
                with: CGSize(width: drawableWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: titleAttributes,
                context: nil
            ).height

            let titleRect = CGRect(x: margin, y: currentY, width: drawableWidth, height: titleHeight)
            title.draw(in: titleRect, withAttributes: titleAttributes)
            currentY += titleHeight + 20

            let attributedBody = NSAttributedString(string: body, attributes: bodyAttributes)
            var textIndex = 0
            let textLength = attributedBody.length

            while textIndex < textLength {
                let availableHeight = pageHeight - margin - currentY
                let rect = CGRect(x: margin, y: currentY, width: drawableWidth, height: availableHeight)
                let textRange = NSRange(location: textIndex, length: textLength - textIndex)
                let textStorage = NSTextStorage(attributedString: attributedBody.attributedSubstring(from: textRange))
                let textContainer = NSTextContainer(size: rect.size)
                let layoutManager = NSLayoutManager()
                layoutManager.addTextContainer(textContainer)
                textStorage.addLayoutManager(layoutManager)

                let glyphRange = layoutManager.glyphRange(for: textContainer)
                layoutManager.drawBackground(forGlyphRange: glyphRange, at: rect.origin)
                layoutManager.drawGlyphs(forGlyphRange: glyphRange, at: rect.origin)

                textIndex += layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil).length

                if textIndex < textLength {
                    context.beginPage()
                    currentY = margin
                }
            }
        }
    }
}
