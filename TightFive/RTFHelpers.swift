import Foundation
import UIKit
typealias TFColor = UIColor
typealias TFFont = UIFont


// MARK: - NSAttributedString RTF Conversion (Safe)

extension NSAttributedString {

    /// Create an attributed string from RTF data, safely.
    ///
    /// Important:
    /// - Some malformed/non-RTF data can crash Apple's RTF importer in rare cases.
    /// - We defensively validate the header and fall back to UTF-8 text.
    /// - We also ensure parsing occurs on the main thread.
    static func fromRTF(_ data: Data) -> NSAttributedString? {
        guard !data.isEmpty else { return NSAttributedString(string: "") }

        // Quick “is this even RTF?” check.
        // Valid RTF generally starts with "{\rtf"
        let header = data.prefix(5)
        if let headerString = String(data: header, encoding: .ascii), headerString != "{\\rtf" {
            // Not RTF — treat as plain text if possible
            if let s = String(data: data, encoding: .utf8) {
                return NSAttributedString(string: s)
            } else {
                return NSAttributedString(string: "")
            }
        }

        // UIKit/AppKit text parsing is safest on the main thread.
        if !Thread.isMainThread {
            return DispatchQueue.main.sync {
                NSAttributedString.fromRTF(data)
            }
        }

        // Try to parse RTF. If anything goes wrong, fall back safely.
        return autoreleasepool {
            do {
                return try NSAttributedString(
                    data: data,
                    options: [.documentType: NSAttributedString.DocumentType.rtf],
                    documentAttributes: nil
                )
            } catch {
                // Fallback: try plain text so we never crash the app
                if let s = String(data: data, encoding: .utf8) {
                    return NSAttributedString(string: s)
                } else {
                    return NSAttributedString(string: "")
                }
            }
        }
    }

    /// Convert attributed string to RTF data.
    func rtfData() -> Data? {
        do {
            return try data(
                from: NSRange(location: 0, length: length),
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
            )
        } catch {
            return nil
        }
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
        font: TFFont = .systemFont(ofSize: 17),
        color: TFColor = .white,
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

    static func body(_ text: String) -> Data {
        text.toRTF()
    }

    static func heading(_ text: String) -> Data {
        text.toRTF(
            font: .systemFont(ofSize: 20, weight: .semibold),
            color: .white,
            lineSpacing: 2,
            paragraphSpacing: 16
        )
    }

    static func title(_ text: String) -> Data {
        text.toRTF(
            font: .systemFont(ofSize: 24, weight: .bold),
            color: .white,
            lineSpacing: 0,
            paragraphSpacing: 20
        )
    }

    static func note(_ text: String) -> Data {
        #if canImport(UIKit)
        let dim = UIColor.white.withAlphaComponent(0.7)
        #else
        let dim = NSColor.white.withAlphaComponent(0.7)
        #endif

        return text.toRTF(
            font: .systemFont(ofSize: 15),
            color: dim,
            lineSpacing: 3,
            paragraphSpacing: 8
        )
    }
}
