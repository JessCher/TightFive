import SwiftUI

struct TeleprompterSettingsDrawerHandle: View {
    @Binding var isPresented: Bool
    @State private var isOpen: Bool = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if isOpen {
                HStack(spacing: 8) {
                    Button {
                        isPresented = true
                    } label: {
                        Label("Teleprompter Settings", systemImage: "slider.horizontal.3")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(TFTheme.yellow)
                            .clipShape(Capsule())
                    }
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .padding(.trailing, 46)
                .padding(.bottom, 6)
            }

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isOpen.toggle()
                }
            } label: {
                Image(systemName: isOpen ? "chevron.right" : "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 44, height: 44)
                    .background(TFTheme.yellow)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 3)
            }
        }
    }
}

#Preview {
    TeleprompterSettingsDrawerHandle(isPresented: .constant(false))
        .padding()
        .background(Color.black)
}
