import SwiftUI
import Combine

private struct TeleprompterFontColorKey: EnvironmentKey {
    static let defaultValue: Color = Color.white.opacity(0.92)
}

extension EnvironmentValues {
    var _teleprompterFontColor: Color {
        get { self[TeleprompterFontColorKey.self] }
        set { self[TeleprompterFontColorKey.self] = newValue }
    }
}

/// Cross-platform SwiftUI teleprompter view (iOS / macOS / visionOS).
/// - Smooth auto-scroll while playing.
/// - Manual drag scroll (scrub) at any time.
/// - No snapping on pause/resume.
struct TeleprompterTextView: View {
    let text: String
    let fontSize: CGFloat
    let lineSpacing: CGFloat

    /// Points per second (screen points).
    let speedPointsPerSecond: CGFloat

    /// Whether the teleprompter is actively scrolling.
    let isPlaying: Bool

    let startInsetTop: CGFloat
    let resetSignal: Int

    @Environment(\._teleprompterFontColor) private var teleprompterFontColor: Color

    @State private var contentHeight: CGFloat = 0
    @State private var viewportHeight: CGFloat = 0

    /// Current scroll offset in points (0 = top).
    @State private var offset: CGFloat = 0

    /// Manual drag state
    @State private var isUserDragging: Bool = false
    @State private var dragStartOffset: CGFloat = 0

    // ~30fps is smooth enough and easy on battery.
    private let tick = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                Text(text)
                    .font(.system(size: fontSize, weight: .regular))
                    .foregroundStyle(teleprompterFontColor)
                    .multilineTextAlignment(.center)
                    .lineSpacing(lineSpacing)
                    // These three are the “intrinsic height / no compression” trio you already found
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 28)
                    .padding(.top, 40 + max(0, startInsetTop))
                    .padding(.bottom, 140)
                    .background(HeightReader())
                    .offset(y: -offset)
            }
            .clipped()
            .contentShape(Rectangle()) // so dragging works anywhere
            .gesture(dragGesture)
            .onAppear {
                viewportHeight = geo.size.height
                clampOffsetIfNeeded()
            }
            .onChange(of: geo.size.height) { _, newH in
                viewportHeight = newH
                // Don’t “snap” unless we are actually out of bounds.
                clampOffsetIfNeeded()
            }
            .onChange(of: contentHeight) { _, _ in
                // Don’t “snap” unless we are actually out of bounds.
                clampOffsetIfNeeded()
            }
            .onChange(of: fontSize) { _, _ in
                // Height will change; keep position if still valid.
                clampOffsetIfNeeded()
            }
            .onChange(of: text) { _, _ in
                // If content changes fundamentally, go to top (predictable).
                offset = 0
                clampOffsetIfNeeded()
            }
            .onChange(of: resetSignal) { _, _ in
                // External reset: jump back to start and pause position
                offset = 0
                clampOffsetIfNeeded()
            }
            .onReceive(tick) { _ in
                guard isPlaying else { return }
                guard !isUserDragging else { return }   // don’t fight the user
                guard maxOffset > 0 else { return }

                let delta = max(0, speedPointsPerSecond) * (1.0 / 30.0)
                offset = min(offset + delta, maxOffset)
            }
            .onPreferenceChange(HeightPreferenceKey.self) { newHeight in
                contentHeight = newHeight
            }
        }
    }

    // MARK: - Manual Drag Gesture

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .local)
            .onChanged { value in
                if !isUserDragging {
                    isUserDragging = true
                    dragStartOffset = offset
                }
                // Drag down = move text down = smaller offset
                // Drag up   = move text up   = larger offset
                let proposed = dragStartOffset - value.translation.height
                offset = clamp(proposed, 0, maxOffset)
            }
            .onEnded { _ in
                isUserDragging = false
                dragStartOffset = offset
                // No snapping. Just stay where the user left it.
            }
    }

    // MARK: - Bounds / Math

    /// Max scrollable distance.
    private var maxOffset: CGFloat {
        max(0, contentHeight - viewportHeight)
    }

    private func clamp(_ x: CGFloat, _ minVal: CGFloat, _ maxVal: CGFloat) -> CGFloat {
        min(max(x, minVal), maxVal)
    }

    /// Only clamps if we’re out of bounds (prevents “pause snap” feel).
    private func clampOffsetIfNeeded() {
        if offset < 0 {
            offset = 0
        } else if offset > maxOffset {
            offset = maxOffset
        }
    }
}

// MARK: - Height Measurement Helpers

private struct HeightReader: View {
    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .preference(key: HeightPreferenceKey.self, value: proxy.size.height)
        }
    }
}

private struct HeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
