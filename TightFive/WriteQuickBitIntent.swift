import AppIntents
import SwiftData
import SwiftUI

/// App Intent that allows users to create a new bit via Siri
/// Example: "Siri, write a quick bit"
struct WriteQuickBitIntent: AppIntent {
    static var title: LocalizedStringResource = "Write a Quick Bit"
    
    static var description = IntentDescription("Create a new comedy bit with voice dictation")
    
    // The content the user dictates
    @Parameter(
        title: "Bit Content",
        description: "The text content for your bit",
        requestValueDialog: IntentDialog("What's the bit?")
    )
    var content: String
    
    // Optional title parameter
    @Parameter(
        title: "Title",
        description: "Optional title for the bit"
    )
    var title: String?
    
    static var parameterSummary: some ParameterSummary {
        Summary("Create a bit: \(\.$content)") {
            \.$title
        }
    }
    
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        // Get the SwiftData model container for the app's shared container
        // This uses the same configuration as the main app
        let container: ModelContainer
        do {
            container = try ModelContainer(for: Bit.self)
        } catch {
            // If we can't access the container, throw a helpful error
            throw WriteQuickBitError.databaseUnavailable
        }
        
        let context = ModelContext(container)
        
        // Trim the content
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Validate content isn't empty
        guard !trimmedContent.isEmpty else {
            throw WriteQuickBitError.emptyContent
        }
        
        // Create the new bit
        let newBit = Bit(text: trimmedContent, status: .loose)
        
        // Set the title if provided
        if let providedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines),
           !providedTitle.isEmpty {
            newBit.title = providedTitle
        }
        
        // Insert into the model context
        context.insert(newBit)
        
        // Save the context
        do {
            try context.save()
        } catch {
            throw WriteQuickBitError.saveFailed
        }
        
        // Create a response dialog
        let displayTitle = newBit.titleLine
        let wordCount = trimmedContent.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
        let dialogText = "I've created your bit: \"\(displayTitle)\" with \(wordCount) word\(wordCount == 1 ? "" : "s")."
        
        // Return result with dialog and snippet view
        return .result(
            dialog: IntentDialog(stringLiteral: dialogText),
            view: BitCreatedSnippetView(bitTitle: displayTitle, content: trimmedContent, wordCount: wordCount)
        )
    }
}

// MARK: - Error Handling

enum WriteQuickBitError: Error, CustomLocalizedStringResourceConvertible {
    case emptyContent
    case databaseUnavailable
    case saveFailed
    
    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .emptyContent:
            return "You need to provide some content for your bit."
        case .databaseUnavailable:
            return "Unable to access the app's database. Please try again."
        case .saveFailed:
            return "Failed to save your bit. Please try again."
        }
    }
}

// MARK: - Snippet View

/// A simple snippet view shown after creating a bit
struct BitCreatedSnippetView: View {
    let bitTitle: String
    let content: String
    let wordCount: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with checkmark
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
                
                Text("Bit Created")
                    .font(.headline)
            }
            
            // Title
            Text(bitTitle)
                .font(.subheadline.bold())
                .lineLimit(2)
            
            // Content preview with word count
            VStack(alignment: .leading, spacing: 4) {
                Text(content)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                
                Text("\(wordCount) word\(wordCount == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
    }
}
