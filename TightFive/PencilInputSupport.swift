import UIKit

enum PencilInputSupport {
    /// Scribble is enabled by default for editable UITextInput views.
    /// This helper keeps that behavior explicit and advertises Pencil preference where supported.
    static func configure(_ textView: UITextView) {
        textView.isEditable = true
        textView.isSelectable = true

        if #available(iOS 16.4, *), UIDevice.current.userInterfaceIdiom == .pad {
            UITextInputContext.current().isPencilInputExpected = true
        }
    }

    static func configureGlobalSupport() {
        if #available(iOS 16.4, *), UIDevice.current.userInterfaceIdiom == .pad {
            UITextInputContext.current().isPencilInputExpected = true
        }
    }
}
