import UIKit

// MARK: - NSAttributedString ↔ RTF

/// Single source of truth for all RTF operations in TightFive.
/// All RTF conversion should go through these extensions.

extension NSAttributedString {
    
    /// Create an attributed string from RTF data.
    /// Returns empty string for empty/invalid data.
    static func fromRTF(_ data: Data) -> NSAttributedString? {
        guard !data.isEmpty else { return NSAttributedString(string: "") }
        return try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        )
    }
    
    /// Convert attributed string to RTF data.
    /// Returns nil if conversion fails.
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

// MARK: - String → Themed RTF

extension String {
    
    /// Convert plain text to RTF with TightFive theme.
    ///
    /// Use this when adding bits to setlists to ensure consistent styling.
    /// The default parameters match the app's standard text appearance.
    ///
    /// - Parameters:
    ///   - font: Text font (default: system 17pt)
    ///   - color: Text color (default: white)
    ///   - lineSpacing: Space between lines (default: 4pt)
    ///   - paragraphSpacing: Space between paragraphs (default: 12pt)
    ///   - lineHeightMultiple: Line height multiplier (default: 1.2)
    /// - Returns: RTF data with theme applied
    func toRTF(
        font: UIFont = .systemFont(ofSize: 17),
        color: UIColor = .white,
        lineSpacing: CGFloat = 4,
        paragraphSpacing: CGFloat = 12,
        lineHeightMultiple: CGFloat = 1.2
    ) -> Data {
        // Configure paragraph style
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = lineSpacing
        paragraphStyle.paragraphSpacing = paragraphSpacing
        paragraphStyle.lineHeightMultiple = lineHeightMultiple
        
        // Build attributes
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]
        
        // Create attributed string and convert
        let attributedString = NSAttributedString(string: self, attributes: attributes)
        return attributedString.rtfData() ?? Data()
    }
    
    /// Convert RTF data back to plain text.
    /// Convenience wrapper around NSAttributedString.fromRTF.
    static func fromRTF(_ data: Data) -> String? {
        NSAttributedString.fromRTF(data)?.string
    }
}

// MARK: - Theme Presets

/// Predefined RTF themes for different contexts in TightFive.
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
