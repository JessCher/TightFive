import SwiftUI
import SwiftData

struct QuickBitEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var rtfData: Data = (NSAttributedString(string: "").rtfData() ?? Data())

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                RichTextEditor(rtfData: $rtfData)
                    .ignoresSafeArea(.keyboard, edges: .bottom)
                    .padding(.horizontal, 12)
                    .padding(.top, 12)

                Spacer(minLength: 0)
            }
            .navigationTitle("Quick Bit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let plain = NSAttributedString.fromRTF(rtfData)?.string
                            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                        guard !plain.isEmpty else { return }
                        modelContext.insert(Bit(text: plain, status: .loose))
                        dismiss()
                    }
                    .disabled({
                        let plain = NSAttributedString.fromRTF(rtfData)?.string
                            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                        return plain.isEmpty
                    }())
                }
            }
        }
    }
}
private extension NSAttributedString {
    static func fromRTF(_ data: Data) -> NSAttributedString? {
        guard !data.isEmpty else { return NSAttributedString(string: "") }
        return try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        )
    }

    func rtfData() -> Data? {
        try? data(
            from: NSRange(location: 0, length: length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )
    }
}

