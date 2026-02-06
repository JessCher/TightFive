import SwiftUI

/// A reusable swipe view for bit cards that supports swipe-to-finish and swipe-to-delete actions.
/// Used by both LooseBitsView and FinishedBitsView.
struct BitSwipeView<Content: View>: View {
    let bit: Bit
    let onFinish: () -> Void
    let onDelete: () -> Void
    let onTap: () -> Void
    let content: Content

    init(bit: Bit, onFinish: @escaping () -> Void, onDelete: @escaping () -> Void, onTap: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.bit = bit
        self.onFinish = onFinish
        self.onDelete = onDelete
        self.onTap = onTap
        self.content = content()
    }

    var body: some View {
        CardSwipeView(
            swipeRightEnabled: true,
            swipeRightIcon: bit.status == .loose ? "checkmark.seal.fill" : "square.and.arrow.up",
            swipeRightColor: TFTheme.yellow,
            swipeRightLabel: bit.status == .loose ? "Finish" : "Share",
            swipeLeftIcon: "trash.fill",
            swipeLeftColor: .red,
            swipeLeftLabel: "Delete",
            onSwipeRight: onFinish,
            onSwipeLeft: onDelete,
            onTap: onTap
        ) {
            content
        }
    }
}
