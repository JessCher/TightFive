import SwiftUI
import SwiftData
import CloudKit

@main
struct TightFiveApp: App {
    // Use @State instead of @StateObject for @Observable classes
    @State private var appSettings = AppSettings.shared
    @State private var showQuickBit = false
    
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
                .globalKeyboardDismiss()
                .syncWithWidget(showQuickBit: $showQuickBit)
                .sheet(isPresented: $showQuickBit) {
                    QuickBitEditor()
                        .presentationDetents([.medium, .large])
                }
                .onAppear {
                    // Refresh global appearance when view appears
                    configureGlobalAppearance()
                }
                .onChange(of: appSettings.appFont) { oldValue, newValue in
                    // Update global appearance when font changes
                    configureGlobalAppearance()
                }
        }
        .modelContainer(sharedModelContainer)
    }
    
    // MARK: - Shared Model Container with iCloud Sync
    
    /// ModelContainer configured with iCloud sync enabled via CloudKit.
    /// All data is automatically backed up and synced across user's devices.
    private var sharedModelContainer: ModelContainer {
        let schema = Schema([
            Bit.self,
            Setlist.self,
            BitVariation.self,
            SetlistAssignment.self,
            Performance.self,
            UserProfile.self
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            cloudKitDatabase: .automatic  // ✨ Enables iCloud sync with CloudKit
        )
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // Print detailed error information
            print("❌ ModelContainer creation failed with error: \(error)")
            print("📋 Error details: \(error.localizedDescription)")
            
            // Try to provide more helpful error message
            if let swiftDataError = error as? any Error {
                print("🔍 Full error: \(String(describing: swiftDataError))")
            }
            
            // TEMPORARY DEBUG: Try creating without CloudKit to isolate the issue
            print("⚠️ Attempting to create ModelContainer without CloudKit...")
            let fallbackConfig = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true,
                cloudKitDatabase: .none
            )
            
            do {
                let container = try ModelContainer(for: schema, configurations: [fallbackConfig])
                print("✅ ModelContainer created successfully WITHOUT CloudKit")
                print("💡 This suggests the issue is with CloudKit configuration")
                return container
            } catch {
                print("❌ Even fallback creation failed: \(error)")
                fatalError("Could not create ModelContainer even without CloudKit: \(error)")
            }
        }
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

