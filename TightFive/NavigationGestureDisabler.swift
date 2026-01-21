import SwiftUI
import UIKit

/// A helper view that disables the interactive pop (swipe-to-go-back) gesture
/// while it is present in the view hierarchy.
public struct NavigationGestureDisabler: View {
    public init() {}

    public var body: some View {
        Representable()
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
    }

    private struct Representable: UIViewControllerRepresentable {
        func makeUIViewController(context: Context) -> Controller {
            Controller()
        }

        func updateUIViewController(_ uiViewController: Controller, context: Context) {}

        final class Controller: UIViewController {
            private var previousEnabled: Bool?

            override func viewWillAppear(_ animated: Bool) {
                super.viewWillAppear(animated)
                guard let nav = navigationController ?? parent?.navigationController else { return }
                let gesture = nav.interactivePopGestureRecognizer
                previousEnabled = gesture?.isEnabled
                gesture?.isEnabled = false
            }

            override func viewWillDisappear(_ animated: Bool) {
                super.viewWillDisappear(animated)
                guard let nav = navigationController ?? parent?.navigationController else { return }
                if let previousEnabled {
                    nav.interactivePopGestureRecognizer?.isEnabled = previousEnabled
                } else {
                    nav.interactivePopGestureRecognizer?.isEnabled = true
                }
            }

            deinit {
                // Best-effort restore if still around
                if let nav = navigationController ?? parent?.navigationController {
                    if let previousEnabled {
                        nav.interactivePopGestureRecognizer?.isEnabled = previousEnabled
                    } else {
                        nav.interactivePopGestureRecognizer?.isEnabled = true
                    }
                }
            }
        }
    }
}
