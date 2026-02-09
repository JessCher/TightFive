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
        shortDescription: "Creating, organizing and refining material",
        overview: "Bits are the heart of your performance. They are separated into 'ideas', 'finished', and 'favorites'. You can write specific notes for bits, you can track how bits change over time through variations, and you can gather insights based off of your ratings and reflections of bits in Show Notes.",
        howToUse: [
            "Enter a bit from the Quick Bit button or widget.",
            "Find your bit in the 'ideas' section and refine it until you think it is stage ready, and then promote it to 'Finished' by swiping right on it.",
            "Long press a bit to add it to an existing setlist, or add it directly from the setlist builder."
        ],
        keyFeatures: [
            "To record specific notes for a bit, hit the button in the bottom right corner of the bit card. This will flip the card around and show a note pad. When you add a bit to a setlist, these notes transfer to the setlist notes automatically.",
            "If you think a bit needs more work, you can long press the bit to demote it back to an idea.",
            "Every time you edit a bit in a setlist, it creates a 'variation' underneath the bit from the 'finished bits' page. You can see how your bits grow and evolve over time, and you can promote any variation to be the master copy of your bit by swiping right on the variation or long pressing and hitting 'promote to master'.",
            "After performing a bit with Stage Mode, you can rate the bit and record notes in Show Notes. These notes link back to the bit through a 'performance insights' page."
            
        ],
        tips: [
            "Add tags to your bits for easy organization. You can use the search bar to find any bits with shared tags, or search by the content of your bit.",
            "Share finished bits by swiping right on them or hitting the share button in the toolbar. You can customize the appearance of your personalized Bit Share Card in Settings -> Themes and Customization."
        ]
    )
    
    static let notebook = Feature(
        name: "Notebook",
        shortDescription: "Capture any notes or thoughts that aren't strictly related to your material.",
        overview: "The notebook exists to capture all of your general thoughts that aren't specific to a bit or a setlist. Got ideas about what you want your stage persona to be? Trying to keep track of potential themes for upcoming sets? Write it down in your notebook and organize it into folders for easy tracking.",
        howToUse: [
            "Create a new note and give it a title.",
            "Edit the text to fit your workflow. Take advantage of Rich Text features such as bold/italics/underline, colored text, font size options, etc. to get your ideas onto the page.",
            "Create a new folder by hitting the folder button in the toolbar. Swipe right on a note or long press to add it to a folder."
        ],
        keyFeatures: [
            "Edit your text however you'd like! The sky is the limit with full access to a rich text editor."
            
        ],
        tips: [
            "This space is yours for whatever you feel like! Use this how you would use any other notebook and rest assured that all of your thoughts will be here waiting for you when you come back."
        ]
    )
    
    static let setlists = Feature(
        name: "Setlists",
        shortDescription: "Building and rehearsing performance flow",
        overview: "Setlists are where you put together your act. Assemble your bits into a stage-ready flow, jump straight into a Run Through practice session, try a Stage Rehearsal to check that your cue cards and microphone are working, and power your Stage Mode.",
        howToUse: [
            "Choose between a traditional notepad for writing your setlist, or use a modular approach. The modular script allows you to organize your bits and freeform text blocks with drag-and-drop functionality or by hitting the 're-order' option in the menu.",
            "Add bits directly from your library by clicking the plus icon in the corner. You can also write non-bit material by adding a freeform text block.",
            "Hit the stopwatch in the top right corner to start a Run Through practice session, or open the menu to access Stage Rehearsal or Stage Mode."
        ],
        keyFeatures: [
            "Modular and Traditional script modes for different writing styles.",
            "Stage Mode and Stage Rehearsal with cue cards, script, or teleprompter views.",
            "Bit variations tracked per setlist for easy refinement. Find variations on the Bit Card from the Bit tab in the navigation bar."
        ],
        tips: [
            "Use Modular mode to quickly rearrange bits while refining your pacing.",
            "Switch to Traditional mode if you prefer a single continuous script.",
            "Rehearse in Stage Rehearsal to make sure your cue cards are working. If you run into issues you can configure cue cards to have different anchor and exit phrases."
        ]
    )
    
    static let runThrough = Feature(
        name: "Run Through",
        shortDescription: "Guided timed practice",
        overview: "Run Through is a focused practice view that keeps you on pace with a timer and lets you rehearse your script in Script or Teleprompter mode.",
        howToUse: [
            "Open a setlist and tap the timer icon to start Run Through, or navigate directly from the Home screen or navigation bar.",
            "Start the timer to track your total set length.",
            "Toggle between Script and Teleprompter to match your rehearsal style.",
            "Adjust font size, color, and scroll speed to keep your pacing comfortable."
        ],
        keyFeatures: [
            "Built-in timer with quick start, pause, and reset",
            "Script and teleprompter reading modes with adjustable settings",
            "Screen stays awake so you can rehearse without interruptions"
        ],
        tips: [
            "Switch easily between a static script and a teleprompter based on what type of practice you want.",
            "Pause the timer or teleprompter scroll if you need to take a break. Hit the reset button to take it from the top if you need to run through it again."
        ]
    )
    
    static let stageMode = Feature(
        name: "Stage Mode",
        shortDescription: "Performance tools for live stage shows.",
        overview: "Stage Mode is your live performance companion that records audio of your set while providing real-time cue cards, script, or teleprompter support. It captures audio of your performance and creates a Show Notes entry for post-show review and analysis.",
        howToUse: [
            "Use Stage Rehearsal to make sure your microphone is working and the cue cards are functioning how you want. Configure the cue cards to adjust to your performance as needed.",
            "Open a setlist and select 'Stage Mode' from the menu.",
            "Choose your preferred view: Cue Cards, Script, or Teleprompter from the 'Stage Mode Settings' in the drop down menu.",
            "Grant microphone permissions to enable audio recording of your performance.",
            "Navigate through your material in Cue Card mode with voice recognition. You can also hit the advance button or swipe to manually move forward.",
            "End the performance to save the recording and create a Show Notes entry."
        ],
        keyFeatures: [
            "Three viewing modes: Cue Cards are automatically configured based on your Bit or Freeform text blocks, Script displays your full material, and Teleprompter auto-scrolls through your set.",
            "Audio recording captures your entire performance for review and analysis.",
            "Automatic Show Notes generation links your performance to individual bit ratings and insights.",
            "Screen stays awake throughout your performance to prevent interruptions.",
            "Customizable cue card anchor and exit phrases can be configured in settings."
        ],
        tips: [
            "Run Stage Rehearsal first to test your setup and make sure cue cards display correctly.",
            "Use Cue Cards mode if you want minimal prompts and don't want to fumble with scrolling or searching for your next line.",
            "Switch to Script or Teleprompter based on your personal preference.",
            "Check your microphone permissions before going on stage to ensure your performance is recorded. Recording can be toggled off in the Stage Mode Settings.",
            "Review your Show Notes immediately after performing while the details are fresh in your mind."
        ]
    )
    
    static let showNotes = Feature(
        name: "Show Notes",
        shortDescription: "Post-show review and feedback",
        overview: "Show Notes saves an audio recording of your Stage Mode performance and lets you rate and review each bit individually, as well as reflect on the whole show.",
        howToUse: [
            "Flip the bit cards around to rate the bit and record any performance notes.",
            "A rating is automatically calculated from the average of all the bit ratings, but you can also set a rating for 'how the show felt'.",
            "Listen back to your performance and take notes about where you got big laughs and where you can tighten up the material for next time."
        ],
        keyFeatures: [
            "All bit ratings and notes are linked back to the individual bit through 'performance insights'.",
            "Listen to a recording of your performance.",
            "Keep notes tied to specific setlists and performances."
        ],
        tips: [
            "Write notes as soon as possible so details are accurate.",
            "Capture both wins and misses to balance your revisions.",
            "Review notes before the next rehearsal to target improvements."
        ]
    )
    
    static let allFeatures: [Feature] = [bits, notebook, setlists, runThrough, stageMode, showNotes]
}

#Preview {
    NavigationStack {
        FeatureHelpDetailView(feature: .bits)
    }
}
