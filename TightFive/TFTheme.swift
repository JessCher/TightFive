import SwiftUI
import UIKit
import Combine

enum TFTheme {
    // MARK: - Colors (from Assets)
    static let yellow = Color("TFYellow")
    static let background = Color("TFBackground")
    static let card = Color("TFCard")
    static let cardStroke = Color("TFCardStroke")
    
    // MARK: - Dynamic Colors (from AppSettings)
    /// The user's custom text color (defaults to white)
    static var text: Color {
        AppSettings.shared.fontColor
    }

    // MARK: - Layout
    static let corner: CGFloat = 18
    static let tileCorner: CGFloat = 18
    static let tilePadding: CGFloat = 16
}

// MARK: - Reusable styles
extension View {
    /// App background (fills screen)
    func tfBackground() -> some View {
        self
            // Critical: ensure even empty states expand to the full screen
            // so the background never "crops" on short content.
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                DynamicChalkboardBackground()
                    .ignoresSafeArea()
            )
            .preferredColorScheme(.dark)
    }

    /// Card / tile container
    func tfCard() -> some View {
        self
            .background(TFTheme.card)
            .overlay(
                RoundedRectangle(cornerRadius: TFTheme.tileCorner, style: .continuous)
                    .stroke(TFTheme.cardStroke.opacity(0.9), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: TFTheme.tileCorner, style: .continuous))
    }

    /// Yellow pill button like the mock
    func tfPrimaryPill() -> some View {
        self
            .appFont(.title3, weight: .semibold)
            .foregroundStyle(.black)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(TFTheme.yellow)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.35), radius: 12, x: 0, y: 10)
    }
}

// MARK: - UIKit appearance (Nav + Tab bars)
extension TFTheme {
    static func applySystemAppearance() {
        // Navigation bar
        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = UIColor(TFTheme.background)
        nav.shadowColor = UIColor.clear
        nav.titleTextAttributes = [
            .foregroundColor: UIColor.white
        ]
        nav.largeTitleTextAttributes = [
            .foregroundColor: UIColor.white
        ]

        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
        UINavigationBar.appearance().tintColor = UIColor(TFTheme.yellow)

        // Tab bar
        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = UIColor(TFTheme.background)

        // Subtle top separator line
        tab.shadowColor = UIColor(TFTheme.cardStroke)

        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
        UITabBar.appearance().tintColor = UIColor(TFTheme.yellow)
        UITabBar.appearance().unselectedItemTintColor = UIColor.white.withAlphaComponent(0.55)
    }
}


// MARK: - Undo / Redo + Keyboard visibility

/// Lightweight keyboard visibility observer (shared).
@MainActor
final class TFKeyboardState: ObservableObject {
    static let shared = TFKeyboardState()

    @Published private(set) var isVisible: Bool = false

    private var tokens: [NSObjectProtocol] = []

    private init() {
        let nc = NotificationCenter.default
        tokens.append(nc.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.keyboardWillShow()
            }
        })

        tokens.append(nc.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.keyboardWillHide()
            }
        })
    }

    deinit {
        tokens.forEach { NotificationCenter.default.removeObserver($0) }
    }

    @objc private func keyboardWillShow() {
        // We are already @MainActor, so direct mutation is safe.
        isVisible = true
    }

    @objc private func keyboardWillHide() {
        isVisible = false
    }
}

struct TFUndoRedoControls: View {
    @Environment(\.undoManager) private var undoManager
    @State private var canUndo = false
    @State private var canRedo = false
    @State private var tokens: [NSObjectProtocol] = []

    var body: some View {
        HStack(spacing: 10) {
            Button {
                undoManager?.undo()  // ✅ Only call undo, let observers handle refresh
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 34, height: 34)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Circle())
            }
            .disabled(!canUndo)
            .opacity(canUndo ? 1.0 : 0.35)

            Button {
                undoManager?.redo()
                refresh()
            } label: {
                Image(systemName: "arrow.uturn.forward")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 34, height: 34)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Circle())
            }
            .disabled(!canRedo)
            .opacity(canRedo ? 1.0 : 0.35)
        }
        .foregroundStyle(TFTheme.yellow)
        .onAppear {
            observeUndoManager()
            refresh()
        }
        .onDisappear {
            tokens.forEach { NotificationCenter.default.removeObserver($0) }
            tokens.removeAll()
        }
    }

    private func refresh() {
        DispatchQueue.main.async {
            self.canUndo = self.undoManager?.canUndo ?? false  // ✅ Next run loop
            self.canRedo = self.undoManager?.canRedo ?? false
        }
    }

    private func observeUndoManager() {
        guard let um = undoManager else { return }
        let nc = NotificationCenter.default

        // Any of these should prompt a refresh of canUndo/canRedo.
        let names: [Notification.Name] = [
            .NSUndoManagerDidUndoChange,
            .NSUndoManagerDidRedoChange,
            .NSUndoManagerDidOpenUndoGroup,
            .NSUndoManagerDidCloseUndoGroup,
            .NSUndoManagerWillCloseUndoGroup,
            .NSUndoManagerCheckpoint
        ]

        tokens = names.map { name in
            nc.addObserver(forName: name, object: um, queue: .main) { _ in
                refresh()
            }
        }
    }
}

extension View {
    /// Adds compact undo/redo controls in the top trailing toolbar, meant for text editing screens.
    func tfUndoRedoToolbar(isVisible: Bool) -> some View {
        self.toolbar {
            if isVisible {
                ToolbarItem(placement: .topBarTrailing) {
                    TFUndoRedoControls()
                }
            }
        }
    }
}


// MARK: - Hex Color fallback helper (optional)
extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

