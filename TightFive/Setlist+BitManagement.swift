import Foundation
import SwiftData
import SwiftUI

// MARK: - Script Block Management

extension Setlist {
    
    // MARK: - Add Content
    
    /// Add a freeform text block at the specified position
    func addFreeformBlock(rtfData: Data = TFRTFTheme.body(""), at index: Int? = nil) {
        let block = ScriptBlock.newFreeform(rtfData: rtfData)
        var blocks = scriptBlocks
        
        if let index = index, index < blocks.count {
            blocks.insert(block, at: index)
        } else {
            blocks.append(block)
        }
        
        scriptBlocks = blocks
        updatedAt = Date()
    }
    
    /// Insert a bit into the script at the specified position
    func insertBit(_ bit: Bit, at index: Int? = nil, context: ModelContext) {
        // Create assignment snapshot
        let assignment = SetlistAssignment(
            order: index ?? scriptBlocks.count,
            performedRTF: bit.text.toRTF(),
            bitId: bit.id,
            bitTitleSnapshot: bit.titleLine
        )
        // Store notes snapshot for reference
        assignment.bitNotesSnapshot = bit.notes
        assignment.setlist = self
        if assignments == nil {
            assignments = []
        }
        assignments?.append(assignment)
        context.insert(assignment)

        // Append bit notes to setlist notes tab if present
        if !bit.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            appendBitNotesToSetlistNotes(bit: bit)
        }

        // Create script block referencing the assignment
        let block = ScriptBlock.newBit(assignmentId: assignment.id)
        var blocks = scriptBlocks

        if let index = index, index < blocks.count {
            blocks.insert(block, at: index)
        } else {
            blocks.append(block)
        }

        scriptBlocks = blocks
        updatedAt = Date()
    }

    /// Appends bit notes to the setlist's notes tab with a header
    private func appendBitNotesToSetlistNotes(bit: Bit) {
        // Get existing notes as plain text
        let existingNotes = NSAttributedString.fromRTF(notesRTF)?.string ?? ""

        // Build the new notes section
        var newNotesText = existingNotes

        // Add separator if there's existing content
        if !existingNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            newNotesText += "\n\n"
        }

        // Add header with bit title and notes
        newNotesText += "--- \(bit.titleLine) ---\n"
        newNotesText += bit.notes

        // Convert back to RTF
        notesRTF = newNotesText.toRTF()
    }
    
    // MARK: - Update Content
    
    /// Update freeform block content
    func updateFreeformBlock(id: UUID, rtfData: Data) {
        var blocks = scriptBlocks
        if let index = blocks.firstIndex(where: { $0.id == id }) {
            blocks[index] = .freeform(id: id, rtfData: rtfData)
            scriptBlocks = blocks
            updatedAt = Date()
        }
    }
    
    // MARK: - Remove Content
    
    /// Remove a block from the script
    func removeBlock(at index: Int, context: ModelContext) {
        var blocks = scriptBlocks
        guard index < blocks.count else { return }
        
        let block = blocks[index]
        
        // If bit block, also remove the assignment
        if let assignmentId = block.assignmentId {
            if let assignment = assignments?.first(where: { $0.id == assignmentId }) {
                assignments?.removeAll { $0.id == assignmentId }
                context.delete(assignment)
            }
        }
        
        blocks.remove(at: index)
        scriptBlocks = blocks
        updatedAt = Date()
    }
    
    /// Remove a block by ID
    func removeBlock(id: UUID, context: ModelContext) {
        if let index = scriptBlocks.firstIndex(where: { $0.id == id }) {
            removeBlock(at: index, context: context)
        }
    }
    
    // MARK: - Reorder Content
    
    /// Move blocks using IndexSet (for SwiftUI List)
    func moveBlocks(from source: IndexSet, to destination: Int) {
        var blocks = scriptBlocks
        blocks.move(fromOffsets: source, toOffset: destination)
        scriptBlocks = blocks
        updatedAt = Date()
    }
    
    // MARK: - Clear Content
    
    /// Remove all blocks from the script
    func clearAllBlocks(context: ModelContext) {
        for assignment in assignments ?? [] {
            context.delete(assignment)
        }
        assignments = []
        scriptBlocks = []
        updatedAt = Date()
    }
}

// MARK: - Variation Support

extension Setlist {
    
    /// Update an assignment's content and optionally create a variation record.
    func commitVariation(
        for assignment: SetlistAssignment,
        newRTF: Data,
        note: String? = nil,
        context: ModelContext
    ) {
        let previousRTF = assignment.performedRTF
        assignment.performedRTF = newRTF
        
        guard let bitId = assignment.bitId else {
            updatedAt = Date()
            return
        }
        
        guard previousRTF != newRTF else {
            updatedAt = Date()
            return
        }
        
        let id = bitId
        let descriptor = FetchDescriptor<Bit>(predicate: #Predicate { $0.id == id })
        
        guard let bit = try? context.fetch(descriptor).first, !bit.isDeleted else {
            updatedAt = Date()
            return
        }
        
        let variation = BitVariation(
            setlistId: self.id,
            setlistTitle: self.title,
            rtfData: newRTF,
            assignmentId: assignment.id,
            note: note
        )
        
        variation.bit = bit
        if bit.variations == nil {
            bit.variations = []
        }
        bit.variations?.append(variation)
        context.insert(variation)
        
        assignment.variationId = variation.id
        bit.updatedAt = Date()
        updatedAt = Date()
    }
}

// MARK: - Query Helpers

extension Setlist {

    /// Get assignment for a specific block (O(n) lookup - use assignmentLookup for batch operations)
    func assignment(for block: ScriptBlock) -> SetlistAssignment? {
        guard let assignmentId = block.assignmentId else { return nil }
        return assignments?.first { $0.id == assignmentId }
    }

    /// Pre-computed dictionary for O(1) assignment lookups.
    /// Use this when rendering lists to avoid O(n²) performance.
    var assignmentLookup: [UUID: SetlistAssignment] {
        Dictionary(uniqueKeysWithValues: (assignments ?? []).map { ($0.id, $0) })
    }

    /// Check if setlist contains a specific bit (by ID)
    func containsBit(withId bitId: UUID) -> Bool {
        assignments?.contains { $0.bitId == bitId } ?? false
    }
}
