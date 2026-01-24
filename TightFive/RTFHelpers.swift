import UIKit

// MARK: - NSAttributedString RTF Conversion

extension NSAttributedString {
    
    /// Create an attributed string from RTF data.
    static func fromRTF(_ data: Data) -> NSAttributedString? {
        guard !data.isEmpty else { return NSAttributedString(string: "") }
        return try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        )
    }
    
    /// Convert attributed string to RTF data.
    func rtfData() -> Data? {
        try? data(
            from: NSRange(location: 0, length: length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )
    }
    
    /// Check if content matches another attributed string (ignoring formatting)
    func contentMatches(_ other: NSAttributedString) -> Bool {
        string == other.string
    }
}

// MARK: - String to RTF Conversion

extension String {
    
    /// Convert plain text to RTF with TightFive theme.
    func toRTF(
        font: UIFont = .systemFont(ofSize: 17),
        color: UIColor = .white,
        lineSpacing: CGFloat = 4,
        paragraphSpacing: CGFloat = 12,
        lineHeightMultiple: CGFloat = 1.2
    ) -> Data {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = lineSpacing
        paragraphStyle.paragraphSpacing = paragraphSpacing
        paragraphStyle.lineHeightMultiple = lineHeightMultiple
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]
        
        let attributedString = NSAttributedString(string: self, attributes: attributes)
        return attributedString.rtfData() ?? Data()
    }
    
    /// Convert RTF data back to plain text.
    static func fromRTF(_ data: Data) -> String? {
        NSAttributedString.fromRTF(data)?.string
    }
}

// MARK: - Theme Presets

enum TFRTFTheme {
    
    /// Standard body text for setlist content
    static func body(_ text: String) -> Data {
        text.toRTF()
    }
    
    /// Heading style for section titles
    static func heading(_ text: String) -> Data {
        text.toRTF(
            font: .systemFont(ofSize: 20, weight: .semibold),
            color: .white,
            lineSpacing: 2,
            paragraphSpacing: 16
        )
    }
    
    /// Large heading for setlist titles
    static func title(_ text: String) -> Data {
        text.toRTF(
            font: .systemFont(ofSize: 24, weight: .bold),
            color: .white,
            lineSpacing: 0,
            paragraphSpacing: 20
        )
    }
    
    /// Notes/comments style (slightly dimmer)
    static func note(_ text: String) -> Data {
        text.toRTF(
            font: .systemFont(ofSize: 15),
            color: UIColor.white.withAlphaComponent(0.7),
            lineSpacing: 3,
            paragraphSpacing: 8
        )
    }
}
