import Foundation
import SwiftData
import UIKit
import UniformTypeIdentifiers

// MARK: - Import Result Types

struct ImportedBit {
    var title: String
    var text: String
    var notes: String
    var tags: [String]
}

struct ImportedSetlist {
    var title: String
    var scriptText: String
    var isDraft: Bool
}

enum ImportError: LocalizedError {
    case unreadableFile(String)
    case emptyContent(String)
    case unsupportedFormat(String)

    var errorDescription: String? {
        switch self {
        case .unreadableFile(let name):
            return "Could not read \"\(name)\""
        case .emptyContent(let name):
            return "\"\(name)\" appears to be empty"
        case .unsupportedFormat(let ext):
            return ".\(ext) files are not supported"
        }
    }
}

// MARK: - Supported file types

extension UTType {
    /// All types we accept for import
    static let importableTypes: [UTType] = [
        .plainText,
        .rtf,
        .commaSeparatedText,
        .tabSeparatedText,
        .utf8PlainText,
        // Markdown (.md) doesn't have a built-in UTType pre-iOS 16 but is plain text
    ]
}

// MARK: - ImportManager

/// Stateless helpers for parsing raw file content into structured import models.
enum ImportManager {

    // MARK: - Parse a single file into one or more bits

    /// Parse a single document into importable bits.
    /// Supports: plain text, markdown, RTF, and CSV (one bit per row).
    static func parseBits(from url: URL) throws -> [ImportedBit] {
        let ext = url.pathExtension.lowercased()

        switch ext {
        case "csv", "tsv":
            return try parseDelimitedBits(url: url, separator: ext == "tsv" ? "\t" : ",")
        case "rtf":
            return try parseRTFBits(url: url)
        default:
            // .txt, .md, and anything else treated as plain text
            return try parsePlainTextBits(url: url)
        }
    }

    // MARK: - Parse a single file into one or more setlists

    static func parseSetlists(from url: URL) throws -> [ImportedSetlist] {
        let ext = url.pathExtension.lowercased()
        let filename = url.deletingPathExtension().lastPathComponent

        let rawText: String
        switch ext {
        case "rtf":
            guard let data = try? Data(contentsOf: url),
                  let attributed = NSAttributedString.fromRTF(data) else {
                throw ImportError.unreadableFile(url.lastPathComponent)
            }
            rawText = attributed.string
        default:
            guard let text = try? String(contentsOf: url, encoding: .utf8) ??
                                  String(contentsOf: url, encoding: .isoLatin1) else {
                throw ImportError.unreadableFile(url.lastPathComponent)
            }
            rawText = text
        }

        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ImportError.emptyContent(url.lastPathComponent)
        }

        // Derive title: first non-empty line or filename
        let lines = trimmed.components(separatedBy: "\n")
        let firstLine = lines.first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) ?? filename
        let title = sanitizeTitle(firstLine).isEmpty ? filename : sanitizeTitle(firstLine)

        // Use all content as the script (the setlist builder can arrange bits later)
        return [ImportedSetlist(title: title, scriptText: trimmed, isDraft: true)]
    }

    // MARK: - Plain text bit parsing

    /// Splits on blank-line-separated blocks so a multi-entry notes export
    /// (e.g. from Apple Notes or Bear) can produce multiple bits at once.
    private static func parsePlainTextBits(url: URL) throws -> [ImportedBit] {
        guard let raw = try? String(contentsOf: url, encoding: .utf8) ??
                              String(contentsOf: url, encoding: .isoLatin1) else {
            throw ImportError.unreadableFile(url.lastPathComponent)
        }

        let content = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else {
            throw ImportError.emptyContent(url.lastPathComponent)
        }

        // Split on 2+ consecutive newlines = separate entries
        let blocks = content.components(separatedBy: "\n\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if blocks.count > 1 {
            // Multi-entry file: each block becomes a bit
            return blocks.map { block in
                parseSingleBitBlock(block, fallbackTitle: url.deletingPathExtension().lastPathComponent)
            }
        } else {
            // Single entry
            return [parseSingleBitBlock(content, fallbackTitle: url.deletingPathExtension().lastPathComponent)]
        }
    }

    private static func parseSingleBitBlock(_ text: String, fallbackTitle: String) -> ImportedBit {
        var lines = text.components(separatedBy: "\n")

        // Title: first non-empty line (strip leading #/- for markdown headings)
        let rawTitle = lines.first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) ?? fallbackTitle
        let title = sanitizeTitle(rawTitle)

        // Remove the title line from body
        if let idx = lines.firstIndex(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) {
            lines.remove(at: idx)
        }

        // Look for a "Tags:" or "#tag" line
        var tags: [String] = []
        var notesLines: [String] = []
        var bodyLines: [String] = []
        var inNotesSection = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.lowercased().hasPrefix("tags:") {
                let tagPart = trimmed.dropFirst("tags:".count)
                tags = tagPart.components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "#")) }
                    .filter { !$0.isEmpty }
            } else if trimmed.lowercased() == "---notes---" || trimmed.lowercased() == "notes:" {
                inNotesSection = true
            } else if inNotesSection {
                notesLines.append(line)
            } else {
                bodyLines.append(line)
            }
        }

        // Also parse inline #hashtags from the body as tags
        let bodyText = bodyLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        let hashTags = extractHashtags(from: bodyText)
        let allTags = Array(Set(tags + hashTags))

        return ImportedBit(
            title: title.isEmpty ? fallbackTitle : title,
            text: bodyText,
            notes: notesLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines),
            tags: allTags
        )
    }

    // MARK: - RTF bit parsing

    private static func parseRTFBits(url: URL) throws -> [ImportedBit] {
        guard let data = try? Data(contentsOf: url),
              let attributed = NSAttributedString.fromRTF(data) else {
            throw ImportError.unreadableFile(url.lastPathComponent)
        }
        let plain = attributed.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !plain.isEmpty else { throw ImportError.emptyContent(url.lastPathComponent) }

        let fallback = url.deletingPathExtension().lastPathComponent
        return [parseSingleBitBlock(plain, fallbackTitle: fallback)]
    }

    // MARK: - CSV/TSV bit parsing

    /// Expected columns (flexible): title, text/body/content, notes, tags
    /// If only one column, treat each row as a title with no body.
    private static func parseDelimitedBits(url: URL, separator: String) throws -> [ImportedBit] {
        guard let raw = try? String(contentsOf: url, encoding: .utf8) else {
            throw ImportError.unreadableFile(url.lastPathComponent)
        }

        var rows = raw.components(separatedBy: "\n").filter { !$0.isEmpty }
        guard !rows.isEmpty else { throw ImportError.emptyContent(url.lastPathComponent) }

        // Parse header
        let header = rows.removeFirst().components(separatedBy: separator)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

        func colIndex(_ candidates: [String]) -> Int? {
            for c in candidates { if let i = header.firstIndex(of: c) { return i } }
            return nil
        }

        let titleIdx   = colIndex(["title", "name", "bit"]) ?? 0
        let textIdx    = colIndex(["text", "body", "content", "script"])
        let notesIdx   = colIndex(["notes", "note"])
        let tagsIdx    = colIndex(["tags", "tag"])

        return rows.compactMap { row in
            let cols = row.components(separatedBy: separator)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            guard cols.indices.contains(titleIdx) else { return nil }

            let title = cols[titleIdx]
            guard !title.isEmpty else { return nil }

            let text  = textIdx.flatMap { cols.indices.contains($0) ? cols[$0] : nil } ?? ""
            let notes = notesIdx.flatMap { cols.indices.contains($0) ? cols[$0] : nil } ?? ""
            let tags  = tagsIdx
                .flatMap { cols.indices.contains($0) ? cols[$0] : nil }
                .map { $0.components(separatedBy: ";").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty } }
                ?? []

            return ImportedBit(title: title, text: text, notes: notes, tags: tags)
        }
    }

    // MARK: - Helpers

    private static func sanitizeTitle(_ raw: String) -> String {
        var s = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // Strip leading markdown heading markers: ##, #, -, *
        let prefixes = ["### ", "## ", "# ", "- ", "* "]
        for p in prefixes {
            if s.hasPrefix(p) { s = String(s.dropFirst(p.count)); break }
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func extractHashtags(from text: String) -> [String] {
        // Match #word patterns
        let pattern = "#([A-Za-z][A-Za-z0-9_-]*)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        return matches.compactMap { match -> String? in
            guard let range = Range(match.range(at: 1), in: text) else { return nil }
            return String(text[range])
        }
    }
}
