import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - Import Mode

enum ImportMode {
    case bits
    case setlists
}

// MARK: - ImportContentView

/// Sheet that walks users through importing bits or setlists from external notes apps.
struct ImportContentView: View {
    let mode: ImportMode
    var defaultStatus: BitStatus = .loose

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // File picker
    @State private var showFilePicker = false

    // Preview state
    @State private var parsedBits: [ImportedBit] = []
    @State private var parsedSetlists: [ImportedSetlist] = []
    @State private var parseErrors: [String] = []
    @State private var isImporting = false
    @State private var importComplete = false
    @State private var importedCount = 0

    // Selection
    @State private var selectedBitIndices: Set<Int> = []
    @State private var selectedSetlistIndices: Set<Int> = []

    private var modeTitle: String { mode == .bits ? "Import Bits" : "Import Setlists" }
    private var modeIcon: String { mode == .bits ? "pencil.and.list.clipboard" : "list.bullet.rectangle" }
    private var modeDescription: String {
        switch mode {
        case .bits:
            let statusLabel = defaultStatus == .finished ? "Finished" : "Ideas"
            return "Import your jokes and bits from Apple Notes, Bear, Notion, Obsidian, or any other notes app. They'll land in \(statusLabel)."
        case .setlists:
            return "Import setlists from Apple Notes, Bear, Google Docs, or any text editor."
        }
    }
    private var supportedFormatsNote: String {
        "Supported: .txt, .md, .rtf — or a .csv with columns: title, text, notes, tags"
    }

    var body: some View {
        NavigationStack {
            Group {
                if importComplete {
                    importSuccessView
                } else if !parsedBits.isEmpty || !parsedSetlists.isEmpty {
                    previewView
                } else {
                    welcomeView
                }
            }
            .navigationTitle(modeTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    TFWordmarkTitle(title: modeTitle, size: 20)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(TFTheme.yellow)
                }
            }
            .tfBackground()
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.plainText, .rtf, .commaSeparatedText, .tabSeparatedText, .text],
            allowsMultipleSelection: true
        ) { result in
            handleFileSelection(result)
        }
    }

    // MARK: - Welcome / Instructions

    private var welcomeView: some View {
        ScrollView {
            VStack(spacing: 28) {
                // Icon
                ZStack {
                    Circle()
                        .fill(TFTheme.yellow.opacity(0.15))
                        .frame(width: 96, height: 96)
                    Image(systemName: modeIcon)
                        .font(.system(size: 40))
                        .foregroundStyle(TFTheme.yellow)
                }
                .padding(.top, 32)

                // Title + description
                VStack(spacing: 10) {
                    Text(modeTitle)
                        .appFont(.title2, weight: .bold)
                        .foregroundStyle(TFTheme.text)

                    Text(modeDescription)
                        .appFont(.subheadline)
                        .foregroundStyle(TFTheme.text.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                // Steps card
                VStack(alignment: .leading, spacing: 0) {
                    stepRow(number: "1", title: "Export from your notes app",
                            detail: "Most apps let you export as plain text (.txt), Markdown (.md), or RTF.")
                    Divider().opacity(0.15)
                    stepRow(number: "2", title: "Pick your files",
                            detail: "Tap the button below and select one or more exported files.")
                    Divider().opacity(0.15)
                    stepRow(number: "3", title: "Review & import",
                            detail: "Preview what will be created, then confirm.")
                }
                .tfDynamicCard(cornerRadius: 16)
                .padding(.horizontal, 20)

                // Format hints
                VStack(alignment: .leading, spacing: 8) {
                    Text("TIPS FOR BEST RESULTS")
                        .appFont(.caption, weight: .semibold)
                        .foregroundStyle(TFTheme.text.opacity(0.5))
                        .padding(.horizontal, 4)

                    VStack(alignment: .leading, spacing: 6) {
                        hintRow("Separate multiple \(mode == .bits ? "bits" : "setlists") with two blank lines in one file")
                        hintRow("Use the first line as the title — markdown headings (# Title) work too")
                        hintRow("Add tags with #hashtags or a \"Tags: comedy, dark\" line")
                        if mode == .bits {
                            hintRow("Add a \"Notes:\" section after your bit text for personal notes")
                        }
                        hintRow(supportedFormatsNote)
                    }
                    .tfDynamicCard(cornerRadius: 14)
                    .padding(.horizontal, 20)
                }

                // CTA
                Button {
                    showFilePicker = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "doc.badge.plus")
                        Text("Choose Files…")
                    }
                    .appFont(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(TFTheme.yellow)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Preview / Confirm

    private var previewView: some View {
        VStack(spacing: 0) {
            // Summary bar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    let itemCount = mode == .bits ? parsedBits.count : parsedSetlists.count
                    let selectedCount = mode == .bits ? selectedBitIndices.count : selectedSetlistIndices.count
                    Text("\(itemCount) \(mode == .bits ? "bit" : "setlist")\(itemCount == 1 ? "" : "s") found")
                        .appFont(.headline)
                        .foregroundStyle(TFTheme.text)
                    Text("\(selectedCount) selected")
                        .appFont(.caption)
                        .foregroundStyle(TFTheme.text.opacity(0.6))
                }

                Spacer()

                Button {
                    if mode == .bits {
                        if selectedBitIndices.count == parsedBits.count {
                            selectedBitIndices.removeAll()
                        } else {
                            selectedBitIndices = Set(parsedBits.indices)
                        }
                    } else {
                        if selectedSetlistIndices.count == parsedSetlists.count {
                            selectedSetlistIndices.removeAll()
                        } else {
                            selectedSetlistIndices = Set(parsedSetlists.indices)
                        }
                    }
                } label: {
                    let allSelected = mode == .bits
                        ? selectedBitIndices.count == parsedBits.count
                        : selectedSetlistIndices.count == parsedSetlists.count
                    Text(allSelected ? "Deselect All" : "Select All")
                        .appFont(.subheadline, weight: .semibold)
                        .foregroundStyle(TFTheme.yellow)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.04))

            Divider().opacity(0.15)

            // Error banner
            if !parseErrors.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(parseErrors, id: \.self) { msg in
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .font(.caption)
                            Text(msg)
                                .appFont(.caption)
                                .foregroundStyle(TFTheme.text.opacity(0.8))
                        }
                    }
                }
                .padding(12)
                .background(Color.orange.opacity(0.1))
            }

            // List
            ScrollView {
                LazyVStack(spacing: 10) {
                    if mode == .bits {
                        ForEach(parsedBits.indices, id: \.self) { i in
                            bitPreviewRow(index: i)
                        }
                    } else {
                        ForEach(parsedSetlists.indices, id: \.self) { i in
                            setlistPreviewRow(index: i)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }

            Divider().opacity(0.15)

            // Action buttons
            HStack(spacing: 12) {
                Button {
                    // Reset to pick more files
                    parsedBits = []
                    parsedSetlists = []
                    parseErrors = []
                    showFilePicker = true
                } label: {
                    Text("Pick Different Files")
                        .appFont(.subheadline, weight: .semibold)
                        .foregroundStyle(TFTheme.text)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color("TFCardStroke").opacity(0.6), lineWidth: 1)
                        )
                }

                Button {
                    performImport()
                } label: {
                    HStack(spacing: 6) {
                        if isImporting {
                            ProgressView().tint(.black).scaleEffect(0.8)
                        }
                        let selCount = mode == .bits ? selectedBitIndices.count : selectedSetlistIndices.count
                        Text("Import \(selCount > 0 ? "\(selCount)" : "")")
                            .appFont(.headline)
                            .foregroundStyle(.black)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(TFTheme.yellow)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isImporting || (mode == .bits ? selectedBitIndices.isEmpty : selectedSetlistIndices.isEmpty))
                .opacity((mode == .bits ? selectedBitIndices.isEmpty : selectedSetlistIndices.isEmpty) ? 0.5 : 1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    @ViewBuilder
    private func bitPreviewRow(index: Int) -> some View {
        let bit = parsedBits[index]
        let isSelected = selectedBitIndices.contains(index)

        Button {
            if isSelected {
                selectedBitIndices.remove(index)
            } else {
                selectedBitIndices.insert(index)
            }
        } label: {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? TFTheme.yellow : TFTheme.text.opacity(0.3))
                    .font(.title3)

                VStack(alignment: .leading, spacing: 6) {
                    Text(bit.title)
                        .appFont(.headline)
                        .foregroundStyle(TFTheme.text)
                        .lineLimit(1)

                    if !bit.text.isEmpty {
                        Text(bit.text)
                            .appFont(.caption)
                            .foregroundStyle(TFTheme.text.opacity(0.6))
                            .lineLimit(3)
                    }

                    if !bit.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(bit.tags.prefix(5), id: \.self) { tag in
                                    Text("#\(tag)")
                                        .appFont(.caption2, weight: .semibold)
                                        .foregroundStyle(TFTheme.yellow)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(TFTheme.yellow.opacity(0.1))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .tfDynamicCard(cornerRadius: 14)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func setlistPreviewRow(index: Int) -> some View {
        let setlist = parsedSetlists[index]
        let isSelected = selectedSetlistIndices.contains(index)

        Button {
            if isSelected {
                selectedSetlistIndices.remove(index)
            } else {
                selectedSetlistIndices.insert(index)
            }
        } label: {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? TFTheme.yellow : TFTheme.text.opacity(0.3))
                    .font(.title3)

                VStack(alignment: .leading, spacing: 6) {
                    Text(setlist.title)
                        .appFont(.headline)
                        .foregroundStyle(TFTheme.text)
                        .lineLimit(1)

                    if !setlist.scriptText.isEmpty {
                        Text(setlist.scriptText)
                            .appFont(.caption)
                            .foregroundStyle(TFTheme.text.opacity(0.6))
                            .lineLimit(3)
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "hammer")
                            .font(.caption2)
                        Text("Will import as draft")
                    }
                    .appFont(.caption2)
                    .foregroundStyle(TFTheme.text.opacity(0.4))
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .tfDynamicCard(cornerRadius: 14)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Success

    private var importSuccessView: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 96, height: 96)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.green)
            }

            VStack(spacing: 10) {
                Text("Import Complete!")
                    .appFont(.title2, weight: .bold)
                    .foregroundStyle(TFTheme.text)

                Text("\(importedCount) \(mode == .bits ? "bit" : "setlist")\(importedCount == 1 ? "" : "s") imported successfully.")
                    .appFont(.subheadline)
                    .foregroundStyle(TFTheme.text.opacity(0.7))
                    .multilineTextAlignment(.center)
            }

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .appFont(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(TFTheme.yellow)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 40)

            Spacer()
        }
    }

    // MARK: - File Selection Handler

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            parseErrors = [error.localizedDescription]
        case .success(let urls):
            var newBits: [ImportedBit] = []
            var newSetlists: [ImportedSetlist] = []
            var errors: [String] = []

            for url in urls {
                guard url.startAccessingSecurityScopedResource() else { continue }
                defer { url.stopAccessingSecurityScopedResource() }

                do {
                    if mode == .bits {
                        let bits = try ImportManager.parseBits(from: url)
                        newBits.append(contentsOf: bits)
                    } else {
                        let setlists = try ImportManager.parseSetlists(from: url)
                        newSetlists.append(contentsOf: setlists)
                    }
                } catch let err as ImportError {
                    errors.append(err.localizedDescription ?? "Unknown error")
                } catch {
                    errors.append(error.localizedDescription)
                }
            }

            parsedBits = newBits
            parsedSetlists = newSetlists
            parseErrors = errors

            // Auto-select all
            selectedBitIndices = Set(newBits.indices)
            selectedSetlistIndices = Set(newSetlists.indices)
        }
    }

    // MARK: - Perform Import

    private func performImport() {
        isImporting = true
        var count = 0

        if mode == .bits {
            for i in selectedBitIndices.sorted() {
                guard parsedBits.indices.contains(i) else { continue }
                let imported = parsedBits[i]
                // Build the text: prepend the title as the first line if it differs from the body's first line
                let bodyFirstLine = imported.text.components(separatedBy: "\n").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let fullText: String
                if bodyFirstLine.localizedCaseInsensitiveCompare(imported.title) == .orderedSame || imported.text.isEmpty {
                    fullText = imported.text.isEmpty ? imported.title : imported.text
                } else {
                    fullText = imported.title + "\n\n" + imported.text
                }
                let bit = Bit(text: fullText, status: defaultStatus)
                bit.tags = imported.tags
                if !imported.notes.isEmpty {
                    bit.notes = imported.notes
                }
                modelContext.insert(bit)
                count += 1
            }
        } else {
            for i in selectedSetlistIndices.sorted() {
                guard parsedSetlists.indices.contains(i) else { continue }
                let imported = parsedSetlists[i]
                // Build an RTF body from the plain text script
                let attributed = NSAttributedString(
                    string: imported.scriptText,
                    attributes: [.font: UIFont.systemFont(ofSize: 17)]
                )
                let rtfData = (try? attributed.data(
                    from: NSRange(location: 0, length: attributed.length),
                    documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
                )) ?? Data()

                let setlist = Setlist(title: imported.title, notesRTF: rtfData, isDraft: imported.isDraft)
                modelContext.insert(setlist)
                count += 1
            }
        }

        do {
            try modelContext.save()
            importedCount = count
            importComplete = true
        } catch {
            parseErrors = ["Save failed: \(error.localizedDescription)"]
        }

        isImporting = false
    }

    // MARK: - Helper Views

    private func stepRow(number: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(TFTheme.yellow)
                    .frame(width: 28, height: 28)
                Text(number)
                    .appFont(.subheadline, weight: .bold)
                    .foregroundStyle(.black)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .appFont(.subheadline, weight: .semibold)
                    .foregroundStyle(TFTheme.text)
                Text(detail)
                    .appFont(.caption)
                    .foregroundStyle(TFTheme.text.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(14)
    }

    private func hintRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("•")
                .appFont(.subheadline)
                .foregroundStyle(TFTheme.yellow)
                .padding(.top, 1)
            Text(text)
                .appFont(.caption)
                .foregroundStyle(TFTheme.text.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }
}

#Preview {
    ImportContentView(mode: .bits)
}
