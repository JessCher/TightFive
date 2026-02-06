import SwiftUI

/// A reusable swipe view for bit cards that supports swipe-to-finish and swipe-to-delete actions.
/// Used by both LooseBitsView and FinishedBitsView.
struct BitSwipeView<Content: View>: View {
    let bit: Bit
    let onFinish: () -> Void
    let onDelete: () -> Void
    let onTap: () -> Void
    let content: Content

    @State private var offset: CGFloat = 0
    @State private var isSwiping = false

    // Threshold to trigger the action automatically
    private let actionThreshold: CGFloat = 100

    init(bit: Bit, onFinish: @escaping () -> Void, onDelete: @escaping () -> Void, onTap: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.bit = bit
        self.onFinish = onFinish
        self.onDelete = onDelete
        self.onTap = onTap
        self.content = content()
    }

    var body: some View {
        ZStack {
            // Background Layer (The Actions)
            GeometryReader { geo in
                HStack(spacing: 0) {
                    // LEFT SIDE (Swipe Right)
                    // - Loose bits: Finish action with checkmark
                    // - Finished bits: Share action with share icon
                    ZStack(alignment: .leading) {
                        TFTheme.yellow
                        Image(systemName: bit.status == .loose ? "checkmark.seal.fill" : "square.and.arrow.up")
                            .appFont(.title2)
                            .foregroundColor(.black)
                            .padding(.leading, 30)
                            .scaleEffect(offset > 0 ? 1.0 : 0.001)
                            .opacity(offset > 0 ? 1 : 0)
                    }
                    .frame(width: geo.size.width / 2)
                    .offset(x: offset > 0 ? 0 : -geo.size.width / 2)

                    // RIGHT SIDE (Swipe Left -> Delete)
                    ZStack(alignment: .trailing) {
                        Color.red
                        Image(systemName: "trash.fill")
                            .appFont(.title2)
                            .foregroundColor(.white)
                            .padding(.trailing, 30)
                            .scaleEffect(offset < 0 ? 1.0 : 0.001)
                            .opacity(offset < 0 ? 1 : 0)
                    }
                    .frame(width: geo.size.width / 2)
                    .offset(x: offset < 0 ? 0 : geo.size.width / 2)
                }
            }

            // Foreground Layer (The Card)
            content
                .offset(x: offset)
                .highPriorityGesture(
                    DragGesture(minimumDistance: 20)
                        .onChanged { value in
                            let translation = value.translation.width
                            let vertical = abs(value.translation.height)

                            // Only start swiping if it's mostly horizontal
                            // This allows vertical scrolling to work naturally
                            if abs(translation) > vertical * 1.5 {
                                isSwiping = true
                                withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.8)) {
                                    offset = translation
                                }
                            }
                        }
                        .onEnded { value in
                            guard isSwiping else { return }

                            let translation = value.translation.width
                            withAnimation(.snappy) {
                                if translation > actionThreshold {
                                    // Swipe Right
                                    // - Loose bits: Finish
                                    // - Finished bits: Share
                                    onFinish()
                                    offset = 0
                                } else if translation < -actionThreshold {
                                    // Swipe Left -> Delete
                                    onDelete()
                                    offset = -500
                                } else {
                                    // Snap back
                                    offset = 0
                                }
                            }
                            isSwiping = false
                        }
                )
                .onTapGesture {
                    if offset == 0 {
                        onTap()
                    }
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
