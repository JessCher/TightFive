import SwiftUI

struct TeleprompterSettingsDrawer: View {
    @Binding var isPresented: Bool

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.white.opacity(0.9))
                .frame(width: 36, height: 36)
                .background(Color.white.opacity(0.1))
                .clipShape(Circle())
                .overlay(
                    Circle().strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Teleprompter Settings")
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        TeleprompterSettingsDrawer(isPresented: .constant(false))
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
    }
}
