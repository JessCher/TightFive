import SwiftUI
import SwiftData
import CloudKit

@main
struct TightFiveApp: App {
    // Use @State instead of @StateObject for @Observable classes
    @State private var appSettings = AppSettings.shared
    @State private var showQuickBit = false
    
    // CloudKit background task monitoring
    @Environment(\.scenePhase) private var scenePhase
    
    // CLOUDKIT FIX: Create ModelContainer once as a static property to prevent duplicate registration
    private static let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Bit.self,
            Setlist.self,
            BitVariation.self,
            SetlistAssignment.self,
            Performance.self,
            UserProfile.self,
            Note.self,
            NoteFolder.self
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            cloudKitDatabase: .automatic
        )
        
        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            print("✅ ModelContainer created with CloudKit sync")
            return container
        } catch {
            // FALLBACK: Try without CloudKit
            let fallbackConfig = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true,
                cloudKitDatabase: .none
            )
            
            do {
                let container = try ModelContainer(for: schema, configurations: [fallbackConfig])
                print("⚠️ ModelContainer created without CloudKit: \(error)")
                return container
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }()
    
    // Configure appearance before views are created
    init() {
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
                .onChange(of: appSettings.appFont) { oldValue, newValue in
                    // Update global appearance when font changes
                    // This already applies efficiently without manual refresh
                    configureGlobalAppearance()
                }
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    handleScenePhaseChange(oldPhase: oldPhase, newPhase: newPhase)
                }
                .performanceOverlay()  // Add performance monitoring overlay
        }
        .modelContainer(Self.sharedModelContainer)
    }
    
    private func handleScenePhaseChange(oldPhase: ScenePhase, newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            // App became active - sync settings from iCloud
            print("📱 App became active - syncing settings from iCloud")
            NSUbiquitousKeyValueStore.default.synchronize()
            
            // Trigger UI refresh to show any changes from other devices
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                appSettings.forceRefresh()
            }
            
        case .background:
            // App went to background - ensure latest changes are synced
            print("📱 App going to background - ensuring settings are synced")
            NSUbiquitousKeyValueStore.default.synchronize()
            
        case .inactive:
            // App became inactive (e.g., during transition)
            break
            
        @unknown default:
            break
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

