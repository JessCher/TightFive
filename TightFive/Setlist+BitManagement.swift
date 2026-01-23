import Foundation
import SwiftData

// MARK: - Bit Management

/// Extension providing DRY helpers for managing bits within setlists.
/// All operations maintain data integrity and update timestamps appropriately.

extension Setlist {
    
    // MARK: - Add Bit
    
    /// Add a bit to this setlist, creating a snapshot of its current content.
    ///
    /// **What happens:**
    /// 1. Bit's plain text is converted to themed RTF
    /// 2. A SetlistAssignment is created with the snapshot
    /// 3. Assignment is inserted at the specified position (or appended)
    /// 4. Setlist's updatedAt timestamp is refreshed
    ///
    /// - Parameters:
    ///   - bit: The source bit to add
    ///   - position: Optional index (0-based). If nil, appends to end.
    ///   - context: The ModelContext to insert the assignment into
    func addBit(_ bit: Bit, at position: Int? = nil, context: ModelContext) {
        // Convert plain text to themed RTF snapshot
        let rtfSnapshot = bit.text.toRTF()
        
        // Determine order
        let targetOrder = position ?? nextOrder
        
        // Shift existing assignments if inserting in middle
        if let position = position {
            for assignment in assignments where assignment.order >= position {
                assignment.order += 1
            }
        }
        
        // Create assignment with snapshot
        let assignment = SetlistAssignment(
            order: targetOrder,
            performedRTF: rtfSnapshot,
            bitId: bit.id,
            bitTitleSnapshot: bit.titleLine
        )
        
        // Establish relationship and insert
        assignment.setlist = self
        assignments.append(assignment)
        context.insert(assignment)
        
        // Update timestamp
        updatedAt = Date()
    }
    
    /// Add multiple bits at once, appending in order.
    ///
    /// - Parameters:
    ///   - bits: Array of bits to add (added in array order)
    ///   - context: The ModelContext to insert assignments into
    func addBits(_ bits: [Bit], context: ModelContext) {
        for bit in bits {
            addBit(bit, context: context)
        }
    }
    
    // MARK: - Remove Assignment
    
    /// Remove an assignment from the setlist.
    ///
    /// **What happens:**
    /// 1. Assignment is removed from the setlist's array
    /// 2. Assignment is deleted from the context
    /// 3. Subsequent assignments have their order decremented
    /// 4. Setlist's updatedAt timestamp is refreshed
    ///
    /// **Note:** This does NOT affect the source Bit or any variations.
    ///
    /// - Parameters:
    ///   - assignment: The assignment to remove
    ///   - context: The ModelContext to delete from
    func removeAssignment(_ assignment: SetlistAssignment, context: ModelContext) {
        let removedOrder = assignment.order
        
        // Remove from array
        if let index = assignments.firstIndex(where: { $0.id == assignment.id }) {
            assignments.remove(at: index)
        }
        
        // Delete from context
        context.delete(assignment)
        
        // Compact orders
        for remaining in assignments where remaining.order > removedOrder {
            remaining.order -= 1
        }
        
        // Update timestamp
        updatedAt = Date()
    }
    
    // MARK: - Reorder
    
    /// Move an assignment to a new position in the setlist.
    ///
    /// Handles both moving up (toward index 0) and moving down (toward higher indices).
    /// All affected assignments have their orders adjusted to maintain consistency.
    ///
    /// - Parameters:
    ///   - assignment: The assignment to move
    ///   - newOrder: The target 0-based position
    func moveAssignment(_ assignment: SetlistAssignment, to newOrder: Int) {
        let oldOrder = assignment.order
        
        guard oldOrder != newOrder else { return }
        
        if oldOrder < newOrder {
            // Moving down - shift intermediate items up
            for other in assignments where other.id != assignment.id &&
                                          other.order > oldOrder &&
                                          other.order <= newOrder {
                other.order -= 1
            }
        } else {
            // Moving up - shift intermediate items down
            for other in assignments where other.id != assignment.id &&
                                          other.order >= newOrder &&
                                          other.order < oldOrder {
                other.order += 1
            }
        }
        
        assignment.order = newOrder
        updatedAt = Date()
    }
    
    /// Swap positions of two assignments.
    ///
    /// - Parameters:
    ///   - first: First assignment
    ///   - second: Second assignment
    func swapAssignments(_ first: SetlistAssignment, _ second: SetlistAssignment) {
        let tempOrder = first.order
        first.order = second.order
        second.order = tempOrder
        updatedAt = Date()
    }
    
    // MARK: - Commit Variation
    
    /// Update an assignment's content and optionally create a variation record.
    ///
    /// **What happens:**
    /// 1. Assignment's performedRTF is updated with new content
    /// 2. If linked to a live bit AND content changed, a BitVariation is created
    /// 3. Assignment's variationId is set to the new variation
    /// 4. Both bit and setlist timestamps are updated
    ///
    /// **When NO variation is created:**
    /// - Assignment has no bitId (ad-hoc content)
    /// - Content hasn't actually changed
    /// - Source bit is deleted
    ///
    /// - Parameters:
    ///   - assignment: The assignment being edited
    ///   - newRTF: The updated RTF content
    ///   - note: Optional note explaining the change
    ///   - context: The ModelContext for fetching/inserting
    func commitVariation(
        for assignment: SetlistAssignment,
        newRTF: Data,
        note: String? = nil,
        context: ModelContext
    ) {
        let previousRTF = assignment.performedRTF
        
        // Always update the performed content (this is the source of truth)
        assignment.performedRTF = newRTF
        
        // Check if we should create a variation record
        guard let bitId = assignment.bitId else {
            // No bit link - just update content
            updatedAt = Date()
            return
        }
        
        guard previousRTF != newRTF else {
            // No actual change - skip variation
            updatedAt = Date()
            return
        }
        
        // Find the source bit (if still alive)
        let id = bitId
        let descriptor = FetchDescriptor<Bit>(
            predicate: #Predicate { $0.id == id }
        )
        
        guard let bit = try? context.fetch(descriptor).first,
              !bit.isDeleted else {
            // Bit deleted or not found - just update content
            updatedAt = Date()
            return
        }
        
        // Create variation record
        let variation = BitVariation(
            setlistId: self.id,
            setlistTitle: self.title,
            rtfData: newRTF,
            assignmentId: assignment.id,
            note: note
        )
        
        // Establish relationships
        variation.bit = bit
        bit.variations.append(variation)
        context.insert(variation)
        
        // Link assignment to variation
        assignment.variationId = variation.id
        
        // Update timestamps
        bit.updatedAt = Date()
        updatedAt = Date()
    }
    
    // MARK: - Bulk Operations
    
    /// Remove all assignments from the setlist.
    ///
    /// Useful for rebuilding a setlist from scratch.
    /// Does NOT affect source bits or their variations.
    ///
    /// - Parameter context: The ModelContext to delete from
    func clearAllAssignments(context: ModelContext) {
        for assignment in assignments {
            context.delete(assignment)
        }
        assignments.removeAll()
        updatedAt = Date()
    }
    
    /// Duplicate an assignment within the same setlist.
    ///
    /// Creates a copy at the next position after the original.
    /// The copy has no variationId (it's a fresh snapshot).
    ///
    /// - Parameters:
    ///   - assignment: The assignment to duplicate
    ///   - context: The ModelContext to insert into
    /// - Returns: The newly created duplicate assignment
    @discardableResult
    func duplicateAssignment(_ assignment: SetlistAssignment, context: ModelContext) -> SetlistAssignment {
        // Insert after the original
        let targetOrder = assignment.order + 1
        
        // Shift subsequent assignments
        for other in assignments where other.order >= targetOrder {
            other.order += 1
        }
        
        // Create duplicate
        let duplicate = SetlistAssignment(
            order: targetOrder,
            performedRTF: assignment.performedRTF,
            bitId: assignment.bitId,
            bitTitleSnapshot: assignment.bitTitleSnapshot
        )
        
        // Note: variationId is intentionally NOT copied
        // The duplicate starts fresh
        
        duplicate.setlist = self
        assignments.append(duplicate)
        context.insert(duplicate)
        
        updatedAt = Date()
        return duplicate
    }
}

// MARK: - Query Helpers

extension Setlist {
    
    /// Get all assignments that reference deleted bits.
    /// Useful for showing "original deleted" indicators in UI.
    func orphanedAssignments(in context: ModelContext) -> [SetlistAssignment] {
        orderedAssignments.filter { $0.isOrphaned(in: context) }
    }
    
    /// Get all assignments that have been modified from original.
    /// Useful for showing "modified" badges in UI.
    var modifiedAssignments: [SetlistAssignment] {
        orderedAssignments.filter { $0.isModified }
    }
    
    /// Check if setlist contains a specific bit (by ID).
    func containsBit(withId bitId: UUID) -> Bool {
        assignments.contains { $0.bitId == bitId }
    }
    
    /// Get all assignments for a specific bit.
    /// A bit can appear multiple times in the same setlist.
    func assignments(forBitId bitId: UUID) -> [SetlistAssignment] {
        orderedAssignments.filter { $0.bitId == bitId }
    }
}
