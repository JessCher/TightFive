import SwiftUI
import SwiftData

@main
struct TightFiveApp: App {
    // Use @State instead of @StateObject for @Observable classes
    @State private var appSettings = AppSettings.shared
    
    init() {
        TFTheme.applySystemAppearance()
        
        // Apply global font to UIKit components
        configureGlobalAppearance()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(TFTheme.yellow)
                .environment(appSettings)
                .onAppear {
                    // Refresh global appearance when view appears
                    configureGlobalAppearance()
                }
                .onChange(of: appSettings.appFont) { oldValue, newValue in
                    // Update global appearance when font changes
                    configureGlobalAppearance()
                }
        }
        .modelContainer(for: [
            Bit.self,
            Setlist.self,
            BitVariation.self,
            SetlistAssignment.self,
            Performance.self,
            UserProfile.self
        ])
    }
    
    private func configureGlobalAppearance() {
        let selectedFont = AppSettings.shared.appFont
        
        // Configure UIKit text appearances with the selected font
        if selectedFont == .systemDefault {
            // Use system font - set to nil to use system defaults
            UILabel.appearance().font = nil
            UITextField.appearance().font = nil
            UITextView.appearance().font = nil
            UINavigationBar.appearance().titleTextAttributes = nil
            UINavigationBar.appearance().largeTitleTextAttributes = nil
        } else {
            // Use custom font
            if let customFont = UIFont(name: selectedFont.rawValue, size: 17) {
                UILabel.appearance().font = customFont
                UITextField.appearance().font = customFont
                UITextView.appearance().font = customFont
            }
            
            if let navFont = UIFont(name: selectedFont.rawValue, size: 17) {
                UINavigationBar.appearance().titleTextAttributes = [
                    .font: navFont.withWeight(.semibold)
                ]
            }
            
            if let largeTitleFont = UIFont(name: selectedFont.rawValue, size: 34) {
                UINavigationBar.appearance().largeTitleTextAttributes = [
                    .font: largeTitleFont.withWeight(.bold)
                ]
            }
        }
        
        // Force refresh of all windows
        DispatchQueue.main.async {
            for scene in UIApplication.shared.connectedScenes {
                if let windowScene = scene as? UIWindowScene {
                    for window in windowScene.windows {
                        window.subviews.forEach { view in
                            view.setNeedsLayout()
                            view.setNeedsDisplay()
                        }
                    }
                }
            }
        }
    }
}

// MARK: - UIFont Extension for Weight
extension UIFont {
    func withWeight(_ weight: UIFont.Weight) -> UIFont {
        let descriptor = self.fontDescriptor.addingAttributes([
            .traits: [UIFontDescriptor.TraitKey.weight: weight]
        ])
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}

