import SwiftUI

struct FeatureHelpDetailView: View {
    let feature: Feature
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Overview Section
                sectionCard(title: "Overview") {
                    Text(feature.overview)
                        .appFont(.body)
                        .foregroundStyle(TFTheme.text.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                // How to Use Section
                if !feature.howToUse.isEmpty {
                    sectionCard(title: "How to Use") {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(feature.howToUse.enumerated()), id: \.offset) { index, step in
                                HStack(alignment: .top, spacing: 12) {
                                    Text("\(index + 1).")
                                        .appFont(.body, weight: .semibold)
                                        .foregroundStyle(TFTheme.yellow)
                                        .frame(width: 24)
                                    
                                    Text(step)
                                        .appFont(.body)
                                        .foregroundStyle(TFTheme.text.opacity(0.8))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                }
                
                // Key Features Section
                if !feature.keyFeatures.isEmpty {
                    sectionCard(title: "Key Features") {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(feature.keyFeatures, id: \.self) { featurePoint in
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.body)
                                        .foregroundStyle(TFTheme.yellow)
                                        .frame(width: 24)
                                    
                                    Text(featurePoint)
                                        .appFont(.body)
                                        .foregroundStyle(TFTheme.text.opacity(0.8))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                }
                
                // Tips Section
                if !feature.tips.isEmpty {
                    sectionCard(title: "Tips & Best Practices") {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(feature.tips, id: \.self) { tip in
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "lightbulb.fill")
                                        .font(.body)
                                        .foregroundStyle(TFTheme.yellow)
                                        .frame(width: 24)
                                    
                                    Text(tip)
                                        .appFont(.body)
                                        .foregroundStyle(TFTheme.text.opacity(0.8))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .navigationTitle(feature.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                TFWordmarkTitle(title: feature.name, size: 22)
            }
        }
        .tfBackground()
    }
    
    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .appFont(.headline, weight: .semibold)
                .foregroundStyle(TFTheme.yellow)
            
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .tfDynamicCard(cornerRadius: 18)
    }
}

// MARK: - Feature Model

struct Feature: Identifiable {
    let id = UUID()
    let name: String
    let shortDescription: String
    let overview: String
    let howToUse: [String]
    let keyFeatures: [String]
    let tips: [String]
    
    static let bits = Feature(
        name: "Bits",
        shortDescription: "Organizing and refining material",
        overview: "Fill in information about how Bits helps you organize and refine your comedy material.",
        howToUse: [
            "Add your first step here",
            "Add your second step here",
            "Add additional steps as needed"
        ],
        keyFeatures: [
            "Add key feature descriptions here",
            "Describe what makes this feature useful"
        ],
        tips: [
            "Add helpful tips for using Bits effectively",
            "Share best practices"
        ]
    )
    
    static let notebook = Feature(
        name: "Notebook",
        shortDescription: "Capturing notes and managing folders",
        overview: "Fill in information about how Notebook helps you capture notes and organize them into folders.",
        howToUse: [
            "Add your first step here",
            "Add your second step here",
            "Add additional steps as needed"
        ],
        keyFeatures: [
            "Add key feature descriptions here",
            "Describe what makes this feature useful"
        ],
        tips: [
            "Add helpful tips for using Notebook effectively",
            "Share best practices"
        ]
    )
    
    static let setlists = Feature(
        name: "Setlists",
        shortDescription: "Building and rehearsing performance flow",
        overview: "Fill in information about how Setlists helps you build and rehearse your performance flow.",
        howToUse: [
            "Add your first step here",
            "Add your second step here",
            "Add additional steps as needed"
        ],
        keyFeatures: [
            "Add key feature descriptions here",
            "Describe what makes this feature useful"
        ],
        tips: [
            "Add helpful tips for using Setlists effectively",
            "Share best practices"
        ]
    )
    
    static let runThrough = Feature(
        name: "Run Through",
        shortDescription: "Guided timed practice",
        overview: "Fill in information about how Run Through provides guided timed practice sessions.",
        howToUse: [
            "Add your first step here",
            "Add your second step here",
            "Add additional steps as needed"
        ],
        keyFeatures: [
            "Add key feature descriptions here",
            "Describe what makes this feature useful"
        ],
        tips: [
            "Add helpful tips for using Run Through effectively",
            "Share best practices"
        ]
    )
    
    static let showNotes = Feature(
        name: "Show Notes",
        shortDescription: "Post-show review and feedback",
        overview: "Fill in information about how Show Notes helps you review performances and collect feedback.",
        howToUse: [
            "Add your first step here",
            "Add your second step here",
            "Add additional steps as needed"
        ],
        keyFeatures: [
            "Add key feature descriptions here",
            "Describe what makes this feature useful"
        ],
        tips: [
            "Add helpful tips for using Show Notes effectively",
            "Share best practices"
        ]
    )
    
    static let allFeatures: [Feature] = [bits, notebook, setlists, runThrough, showNotes]
}

#Preview {
    NavigationStack {
        FeatureHelpDetailView(feature: .bits)
    }
}
