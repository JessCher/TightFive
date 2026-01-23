import SwiftUI
import SwiftData

/// A card displaying a bit assignment within a setlist.
///
/// Shows:
/// - Order number (1-indexed for display)
/// - Title/first line of content
/// - Status badges (Modified, Original Deleted)
/// - Drag handle for reordering
struct SetlistBitCard: View {
    @Environment(\.modelContext) private var modelContext
    
    let assignment: SetlistAssignment
    let displayOrder: Int  // 1-indexed for user display
    let onTap: () -> Void
    let onDelete: () -> Void
    
    /// Whether the original bit was deleted
    private var isOrphaned: Bool {
        assignment.isOrphaned(in: modelContext)
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Order number badge
                Text("\(displayOrder)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.black)
                    .frame(width: 28, height: 28)
                    .background(TFTheme.yellow)
                    .clipShape(Circle())
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(assignment.titleLine)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    // Status indicators
                    HStack(spacing: 6) {
                        if assignment.isModified {
                            StatusBadge(text: "Modified", color: .blue)
                        }
                        
                        if isOrphaned {
                            StatusBadge(text: "Original Deleted", color: .orange)
                        }
                    }
                }
                
                Spacer()
                
                // Drag handle
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.3))
                    .frame(width: 32, height: 44)
            }
            .padding(.leading, 14)
            .padding(.trailing, 8)
            .padding(.vertical, 12)
            .background(Color("TFCard"))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color("TFCardStroke").opacity(0.7), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                onTap()
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Remove from Set", systemImage: "minus.circle")
            }
        }
    }
}

// MARK: - Status Badge

private struct StatusBadge: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }
}

// MARK: - Swipeable Wrapper

/// Wraps SetlistBitCard with swipe-to-delete gesture
struct SwipeableSetlistBitCard: View {
    @Environment(\.modelContext) private var modelContext
    
    let assignment: SetlistAssignment
    let displayOrder: Int
    let onTap: () -> Void
    let onDelete: () -> Void
    
    @State private var offset: CGFloat = 0
    @State private var isSwiping = false
    
    private let deleteThreshold: CGFloat = 80
    
    var body: some View {
        ZStack {
            // Delete background
            HStack {
                Spacer()
                
                ZStack {
                    Color.red
                    
                    Image(systemName: "trash.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .opacity(offset < -20 ? 1 : 0)
                }
                .frame(width: max(0, -offset))
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            
            // Card
            SetlistBitCard(
                assignment: assignment,
                displayOrder: displayOrder,
                onTap: onTap,
                onDelete: onDelete
            )
            .offset(x: offset)
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onChanged { value in
                        let horizontal = value.translation.width
                        let vertical = abs(value.translation.height)
                        
                        // Only swipe left, and only if horizontal movement dominates
                        if horizontal < 0 && abs(horizontal) > vertical * 1.5 {
                            isSwiping = true
                            withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.8)) {
                                // Limit to delete threshold with rubber-band effect
                                offset = max(horizontal, -deleteThreshold * 1.5)
                            }
                        }
                    }
                    .onEnded { value in
                        guard isSwiping else { return }
                        
                        withAnimation(.snappy) {
                            if offset < -deleteThreshold {
                                // Trigger delete
                                offset = -500
                                onDelete()
                            } else {
                                // Snap back
                                offset = 0
                            }
                        }
                        isSwiping = false
                    }
            )
        }
    }
}

// MARK: - Empty State

/// Shown when setlist has no assignments
struct SetlistEmptyState: View {
    let onAddBit: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "music.note.list")
                .font(.system(size: 56))
                .foregroundStyle(.white.opacity(0.25))
            
            Text("No bits in this set")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
            
            Text("Add your finished bits to build your setlist.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: onAddBit) {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                    Text("Add Bit")
                }
                .font(.headline.weight(.semibold))
                .foregroundStyle(.black)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(TFTheme.yellow)
                .clipShape(Capsule())
            }
            .padding(.top, 8)
            
            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    let assignment = SetlistAssignment(
        order: 0,
        performedRTF: "Test bit content here".toRTF(),
        bitTitleSnapshot: "Test Bit"
    )
    
    return VStack(spacing: 12) {
        SetlistBitCard(
            assignment: assignment,
            displayOrder: 1,
            onTap: {},
            onDelete: {}
        )
        
        SetlistBitCard(
            assignment: assignment,
            displayOrder: 2,
            onTap: {},
            onDelete: {}
        )
    }
    .padding()
    .tfBackground()
}
