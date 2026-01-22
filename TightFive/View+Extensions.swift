import SwiftUI

extension View {
    /// Adds a gesture to dismiss the keyboard when tapping outside active input areas.
    /// This uses a high-priority simultaneous tap gesture and a window-based
    /// endEditing call so it works reliably inside nested SwiftUI hierarchies.
    func hideKeyboardOnTap() -> some View {
        self.simultaneousGesture(
            TapGesture().onEnded { _ in
                KeyboardDismissal.endEditing()
            }
        )
    }
}

private enum KeyboardDismissal {
    static func endEditing() {
        // Traverse connected scenes to find the key window and end editing.
        if let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first,
           let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
            window.endEditing(true)
        } else {
            // Fallback for older situations
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
}

extension View {
    /// Dismiss the keyboard when the user drags downward anywhere on the view.
    /// This uses a simultaneous gesture so it doesn't block scrolling.
    func hideKeyboardOnDragDown(threshold: CGFloat = 30) -> some View {
        self.simultaneousGesture(
            DragGesture(minimumDistance: 20, coordinateSpace: .local)
                .onChanged { value in
                    let vertical = value.translation.height
                    let horizontal = abs(value.translation.width)
                    
                    // Only dismiss if it's a clear downward swipe (not diagonal or horizontal)
                    if vertical > threshold && vertical > (horizontal * 1.5) {
                        KeyboardDismissal.endEditing()
                    }
                }
        )
    }
    
    /// Combines tap and drag-down gestures for maximum keyboard dismissal coverage
    func hideKeyboardInteractively() -> some View {
        self
            .hideKeyboardOnTap()
            .hideKeyboardOnDragDown()
    }
}

