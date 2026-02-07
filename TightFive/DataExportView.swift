import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Full data export view - creates a downloadable .zip with all user data
struct DataExportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var isExporting = false
    @State private var exportProgress: String = ""
    @State private var exportURL: URL?
    @State private var exportError: String?
    @State private var showShareSheet = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "arrow.down.doc.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(TFTheme.yellow)

                    Text("Export All Data")
                        .appFont(.title2, weight: .bold)
                        .foregroundStyle(.white)

                    Text("Download a .zip file containing all your comedy material.")
                        .appFont(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(.top, 20)

                // What's included
                VStack(alignment: .leading, spacing: 12) {
                    Text("What's Included")
                        .appFont(.title3, weight: .semibold)
                        .foregroundStyle(TFTheme.yellow)
                        .padding(.horizontal, 4)

                    VStack(spacing: 0) {
                        exportItemRow(icon: "pencil.circle.fill", title: "Bits", description: "All your bits with titles, text, tags, and notes")
                        Divider().opacity(0.2)
                        exportItemRow(icon: "doc.text.fill", title: "Bit Variations", description: "Evolution of your bits across setlists")
                        Divider().opacity(0.2)
                        exportItemRow(icon: "list.bullet.rectangle.fill", title: "Setlists", description: "All setlists with script content and notes")
                        Divider().opacity(0.2)
                        exportItemRow(icon: "book.closed.fill", title: "Notebook", description: "All notebook pages with titles, and content")
                        Divider().opacity(0.2)
                        exportItemRow(icon: "star.fill", title: "Show Notes", description: "Performance notes, ratings, and insights")
                        Divider().opacity(0.2)
                        exportItemRow(icon: "waveform.circle.fill", title: "Recordings", description: "All audio recordings from Stage Mode")
                    }
                    .tfDynamicCard(cornerRadius: 16)
                }
                .padding(.horizontal, 18)

                // Export button
                VStack(spacing: 12) {
                    if isExporting {
                        VStack(spacing: 10) {
                            ProgressView()
                                .tint(TFTheme.yellow)
                            Text(exportProgress)
                                .appFont(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .padding(.vertical, 20)
                    } else if let error = exportError {
                        VStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                                .font(.title2)
                            Text(error)
                                .appFont(.caption)
                                .foregroundStyle(.red.opacity(0.9))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 12)
                    }

                    Button {
                        Task { await performExport() }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "square.and.arrow.up")
                            Text(exportURL != nil ? "Export Again" : "Export Data")
                        }
                        .appFont(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(TFTheme.yellow)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(isExporting)
                    .opacity(isExporting ? 0.5 : 1.0)
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)

                // Footer
                Text("Your exported data is saved as plain text files inside a .zip archive. Recordings are included as M4A audio files.")
                    .appFont(.footnote)
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 28)
            }
        }
        .tfBackground()
        .navigationTitle("Export Data")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                TFWordmarkTitle(title: "Export Data", size: 20)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = exportURL {
                ShareSheet(items: [url]) { _ in }
            }
        }
    }

    private func exportItemRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .foregroundStyle(TFTheme.yellow)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .appFont(.headline)
                    .foregroundStyle(.white)
                Text(description)
                    .appFont(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()
        }
        .padding(14)
    }

    // MARK: - Export Logic

    private func performExport() async {
        isExporting = true
        exportError = nil
        exportURL = nil

        do {
            let url = try await buildExportArchive()
            exportURL = url
            showShareSheet = true
        } catch {
            exportError = "Export failed: \(error.localizedDescription)"
        }

        isExporting = false
    }

    private func buildExportArchive() async throws -> URL {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent("TightFive_Export_\(Int(Date().timeIntervalSince1970))")
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // 1. Export Bits
        exportProgress = "Exporting bits..."
        let bitsDir = tempDir.appendingPathComponent("Bits")
        try fm.createDirectory(at: bitsDir, withIntermediateDirectories: true)

        let bits = try modelContext.fetch(FetchDescriptor<Bit>(predicate: #Predicate { !$0.isDeleted }))
        for bit in bits {
            let safeName = sanitizeFilename(bit.titleLine)
            var content = "Title: \(bit.titleLine)\n"
            content += "Status: \(bit.status.rawValue)\n"
            content += "Created: \(bit.createdAt)\n"
            content += "Updated: \(bit.updatedAt)\n"
            if !bit.tags.isEmpty { content += "Tags: \(bit.tags.joined(separator: ", "))\n" }
            content += "\n--- Content ---\n\(bit.text)\n"
            if !bit.notes.isEmpty { content += "\n--- Notes ---\n\(bit.notes)\n" }

            let file = bitsDir.appendingPathComponent("\(safeName).txt")
            try content.data(using: .utf8)?.write(to: file, options: .atomic)
        }

        // 2. Export Bit Variations
        exportProgress = "Exporting variations..."
        let variationsDir = tempDir.appendingPathComponent("Variations")
        try fm.createDirectory(at: variationsDir, withIntermediateDirectories: true)

        let variations = try modelContext.fetch(FetchDescriptor<BitVariation>())
        for variation in variations {
            let safeName = sanitizeFilename(variation.titleLine)
            var content = "Bit: \(variation.bit?.titleLine ?? "Unknown")\n"
            content += "Setlist: \(variation.setlistTitle)\n"
            content += "Created: \(variation.createdAt)\n"
            if let note = variation.note { content += "Note: \(note)\n" }
            content += "\n--- Content ---\n\(variation.plainText)\n"

            let file = variationsDir.appendingPathComponent("\(safeName)_\(variation.id.uuidString.prefix(8)).txt")
            try content.data(using: .utf8)?.write(to: file, options: .atomic)
        }

        // 3. Export Setlists
        exportProgress = "Exporting setlists..."
        let setlistsDir = tempDir.appendingPathComponent("Setlists")
        try fm.createDirectory(at: setlistsDir, withIntermediateDirectories: true)

        let setlists = try modelContext.fetch(FetchDescriptor<Setlist>())
        for setlist in setlists {
            let safeName = sanitizeFilename(setlist.title.isEmpty ? "Untitled" : setlist.title)
            var content = "Title: \(setlist.title)\n"
            content += "Status: \(setlist.isDraft ? "In Progress" : "Finished")\n"
            content += "Created: \(setlist.createdAt)\n"
            content += "Updated: \(setlist.updatedAt)\n"
            content += "\n--- Script ---\n\(setlist.exportPlainText())\n"

            let notesText = NSAttributedString.fromRTF(setlist.notesRTF)?.string ?? ""
            if !notesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                content += "\n--- Notes ---\n\(notesText)\n"
            }

            let file = setlistsDir.appendingPathComponent("\(safeName).txt")
            try content.data(using: .utf8)?.write(to: file, options: .atomic)
        }

        // 4. Export Notebook
        exportProgress = "Exporting notebook..."
        let notebookDir = tempDir.appendingPathComponent("Notebook")
        try fm.createDirectory(at: notebookDir, withIntermediateDirectories: true)

        let notes = try modelContext.fetch(FetchDescriptor<Note>(predicate: #Predicate { !$0.isDeleted }))
        for note in notes {
            let safeName = sanitizeFilename(note.displayTitle)
            var content = "Title: \(note.displayTitle)\n"
            content += "Created: \(note.createdAt)\n"
            content += "Updated: \(note.updatedAt)\n"
            let noteText = NSAttributedString.fromRTF(note.contentRTF)?.string ?? ""
            if !noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                content += "\n--- Content ---\n\(noteText)\n"
            }

            let file = notebookDir.appendingPathComponent("\(safeName).txt")
            try content.data(using: .utf8)?.write(to: file, options: .atomic)
        }

        // 5. Export Show Notes (Performances)
        exportProgress = "Exporting show notes..."
        let showNotesDir = tempDir.appendingPathComponent("ShowNotes")
        try fm.createDirectory(at: showNotesDir, withIntermediateDirectories: true)

        let performances = try modelContext.fetch(FetchDescriptor<Performance>(predicate: #Predicate { !$0.isDeleted }))
        for perf in performances {
            let safeName = sanitizeFilename(perf.displayTitle)
            var content = "Title: \(perf.displayTitle)\n"
            content += "Date: \(perf.formattedDate)\n"
            content += "Venue: \(perf.venue)\n"
            content += "Duration: \(perf.formattedDuration)\n"
            content += "Rating (felt): \(perf.rating)/5\n"
            content += "Rating (calculated): \(perf.calculatedRating)/5\n"
            if !perf.notes.isEmpty { content += "\n--- Notes ---\n\(perf.notes)\n" }

            if let insights = perf.insights, !insights.isEmpty {
                content += "\n--- Insights ---\n"
                for insight in insights {
                    content += "- \(insight.title)\n"
                }
            }

            let file = showNotesDir.appendingPathComponent("\(safeName)_\(perf.id.uuidString.prefix(8)).txt")
            try content.data(using: .utf8)?.write(to: file, options: .atomic)
        }

        // 6. Copy Recordings
        exportProgress = "Copying recordings..."
        let recordingsDir = tempDir.appendingPathComponent("Recordings")
        try fm.createDirectory(at: recordingsDir, withIntermediateDirectories: true)

        for perf in performances {
            if let audioURL = perf.audioURL, perf.audioFileExists {
                let dest = recordingsDir.appendingPathComponent(audioURL.lastPathComponent)
                try? fm.copyItem(at: audioURL, to: dest)
            }
        }

        // 7. Create zip using NSFileCoordinator
        exportProgress = "Creating archive..."
        let zipURL = fm.temporaryDirectory.appendingPathComponent("TightFive_Export.zip")
        try? fm.removeItem(at: zipURL) // Remove old if exists

        var coordinatorError: NSError?
        var archiveError: Error?

        let coordinator = NSFileCoordinator()
        coordinator.coordinate(readingItemAt: tempDir, options: [.forUploading], error: &coordinatorError) { compressedURL in
            do {
                try fm.copyItem(at: compressedURL, to: zipURL)
            } catch {
                archiveError = error
            }
        }

        if let error = coordinatorError { throw error }
        if let error = archiveError { throw error }

        // Cleanup temp directory
        try? fm.removeItem(at: tempDir)

        return zipURL
    }

    private func sanitizeFilename(_ name: String) -> String {
        let safe = name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(safe.prefix(80))
    }
}

#Preview {
    NavigationStack {
        DataExportView()
    }
}
