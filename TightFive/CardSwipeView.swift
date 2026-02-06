import SwiftUI

/// Shared swipe container for card rows across the app.
/// Matches the Setlist swipe gesture style (graded color + spring response).
struct CardSwipeView<Content: View>: View {
    var swipeRightEnabled: Bool = false
    var swipeRightIcon: String = "checkmark"
    var swipeRightColor: Color = .green
    var swipeRightLabel: String = "Action"
    var swipeLeftEnabled: Bool = true
    var swipeLeftIcon: String = "trash.fill"
    var swipeLeftColor: Color = .red
    var swipeLeftLabel: String = "Delete"
    var cornerRadius: CGFloat = 18
    var onSwipeRight: () -> Void = {}
    var onSwipeLeft: () -> Void = {}
    var onTap: () -> Void = {}
    @ViewBuilder var content: () -> Content

    @State private var offset: CGFloat = 0
    @State private var isSwiping = false
    private let actionThreshold: CGFloat = 100

    var body: some View {
        ZStack {
            backgroundLayer
            content()
                .offset(x: offset)
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onChanged { gesture in
                            isSwiping = true
                            let translation = gesture.translation.width
                            if !swipeRightEnabled && translation > 0 {
                                offset = translation * 0.2
                            } else if !swipeLeftEnabled && translation < 0 {
                                offset = translation * 0.2
                            } else {
                                offset = translation
                            }
                        }
                        .onEnded { gesture in
                            let translation = gesture.translation.width

                            if swipeRightEnabled && translation > actionThreshold {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    offset = 0
                                }
                                onSwipeRight()
                            } else if swipeLeftEnabled && translation < -actionThreshold {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    offset = 0
                                }
                                onSwipeLeft()
                            } else {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    offset = 0
                                }
                            }

                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                isSwiping = false
                            }
                        }
                )
                .onTapGesture {
                    if !isSwiping { onTap() }
                }
        }
        .accessibilityAction(named: swipeRightLabel, swipeRightEnabled ? onSwipeRight : nil)
        .accessibilityAction(named: swipeLeftLabel, swipeLeftEnabled ? onSwipeLeft : nil)
    }

    private var backgroundLayer: some View {
        HStack {
            if swipeRightEnabled {
                HStack(spacing: 6) {
                    Image(systemName: swipeRightIcon)
                        .font(.system(size: 18, weight: .bold))
                    Text(swipeRightLabel)
                        .appFont(.caption, weight: .bold)
                }
                .foregroundStyle(.white)
                .padding(.leading, 20)
                .scaleEffect(min(offset / actionThreshold, 1.0))
                .opacity(max(0, min(Double(offset) / Double(actionThreshold), 1.0)))
            }

            Spacer()

            if swipeLeftEnabled {
                HStack(spacing: 6) {
                    Text(swipeLeftLabel)
                        .appFont(.caption, weight: .bold)
                    Image(systemName: swipeLeftIcon)
                        .font(.system(size: 18, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.trailing, 20)
                .scaleEffect(min(-offset / actionThreshold, 1.0))
                .opacity(max(0, min(Double(-offset) / Double(actionThreshold), 1.0)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    private var backgroundColor: Color {
        if offset > 0 {
            return swipeRightColor.opacity(min(Double(offset) / Double(actionThreshold), 1.0) * 0.3)
        }
        if offset < 0 {
            return swipeLeftColor.opacity(min(Double(-offset) / Double(actionThreshold), 1.0) * 0.3)
        }
        return .clear
    }
}

private extension View {
    @ViewBuilder
    func accessibilityAction(named name: String, _ action: (() -> Void)?) -> some View {
        if let action {
            accessibilityAction(named: Text(name), action)
        } else {
            self
        }
    }
}
