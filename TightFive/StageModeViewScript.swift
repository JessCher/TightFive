import SwiftData
import UIKit
import SwiftUI

/// Stage Mode with Script view - records performance while displaying static script
struct StageModeViewScript: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let setlist: Setlist
    var venue: String = ""
    
    @StateObject private var engine = CueCardEngine()
    @State private var showExitConfirmation = false
    @State private var showSaveConfirmation = false
    @State private var isInitialized = false
    
    // Access settings - using @State to enable bindings to the @Observable singleton
    @State private var settings: StageModeScriptSettings = .shared
    
    private var hasContent: Bool {
        setlist.hasScriptContent
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                if !hasContent {
                    emptyState
                } else {
                    VStack(spacing: 0) {
                        topBar(geometry: geometry)
                        scriptContent
                    }
                }
                
                if showExitConfirmation {
                    exitConfirmationOverlay
                }
                
                if showSaveConfirmation {
                    saveConfirmationOverlay
                }
            }
        }
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .onAppear { startSessionIfNeeded() }
        .onDisappear { engine.stop() }
    }
    
    private func startSessionIfNeeded() {
        guard !isInitialized else { return }
        isInitialized = true
        
        // Configure engine for recording (no cards needed for script mode)
        let cards = CueCard.extractCards(from: setlist)
        engine.configure(cards: cards)
        
        Task {
            await engine.start(filenameBase: setlist.title)
        }
    }
    
    private func endSession() {
        if let result = engine.stopAndFinalize() {
            let performance = Performance(
                setlistId: setlist.id,
                setlistTitle: setlist.title,
                venue: venue,
                audioFilename: result.url.lastPathComponent,
                duration: result.duration,
                fileSize: result.fileSize
            )
            
            performance.insights = result.insights.map {
                PerformanceAnalytics.Insight(
                    title: $0,
                    description: "",
                    severity: .info
                )
            }
            
            modelContext.insert(performance)
            try? modelContext.save()
            showSaveConfirmation = true
        } else {
            dismiss()
        }
    }
    
    // MARK: - Top Bar
    
    private func topBar(geometry: GeometryProxy) -> some View {
        VStack(spacing: 12) {
            HStack {
                // Close button
                Button {
                    showExitConfirmation = true
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                
                Spacer()
                
                // Recording indicator
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    
                    Text("RECORDING")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                        .kerning(1)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.1))
                .clipShape(Capsule())
                
                Spacer()
                
                // Settings button
                Button {
                    // Could open settings if needed
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .opacity(0) // Hidden for now
            }
            .padding(.horizontal, 20)
            .padding(.top, geometry.safeAreaInsets.top + 12)
        }
        .background(
            LinearGradient(
                colors: [Color.black, Color.black.opacity(0.9), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)
        )
    }
    
    // MARK: - Script Content
    
    private var scriptContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(setlist.title.uppercased())
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(TFTheme.yellow)
                    .kerning(2)
                
                Rectangle()
                    .fill(TFTheme.yellow.opacity(0.5))
                    .frame(height: 2)
                    .frame(maxWidth: 100)
                
                ForEach(setlist.scriptBlocks) { block in
                    scriptBlockContent(block)
                }
                
                Spacer(minLength: 100)
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)
        }
        .scrollIndicators(.hidden)
    }
    
    @ViewBuilder
    private func scriptBlockContent(_ block: ScriptBlock) -> some View {
        let content = blockContentText(block)
        if !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Text(content)
                .font(.system(size: CGFloat(settings.fontSize), weight: .regular))
                .foregroundStyle(settings.textColor.color.opacity(0.9))
                .lineSpacing(CGFloat(settings.lineSpacing))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    private func blockContentText(_ block: ScriptBlock) -> String {
        switch block {
        case .freeform(_, let rtfData):
            return NSAttributedString.fromRTF(rtfData)?.string ?? ""
        case .bit(_, let assignmentId):
            guard let assignment = setlist.assignments.first(where: { $0.id == assignmentId }) else {
                return ""
            }
            return assignment.plainText
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 72))
                .foregroundStyle(TFTheme.yellow.opacity(0.3))
            
            Text("No Script Content")
                .appFont(.title, weight: .bold)
                .foregroundStyle(.white)
            
            Text("Add content to your setlist before entering Stage Mode")
                .appFont(.body)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button {
                dismiss()
            } label: {
                Text("Go Back")
                    .appFont(.headline)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(TFTheme.yellow)
                    .clipShape(Capsule())
            }
            .padding(.top, 12)
        }
    }
    
    // MARK: - Exit Confirmation
    
    private var exitConfirmationOverlay: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(TFTheme.yellow)
                
                Text("End Performance?")
                    .appFont(.title2, weight: .bold)
                    .foregroundStyle(.white)
                
                Text("Your performance will be saved with audio recording and show notes.")
                    .appFont(.body)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                HStack(spacing: 16) {
                    Button {
                        showExitConfirmation = false
                    } label: {
                        Text("Keep Going")
                            .appFont(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    Button {
                        showExitConfirmation = false
                        endSession()
                    } label: {
                        Text("End & Save")
                            .appFont(.headline)
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(TFTheme.yellow)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 32)
                .padding(.top, 8)
            }
            .padding(32)
            .background(Color(white: 0.12))
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .padding(.horizontal, 32)
        }
    }
    
    // MARK: - Save Confirmation
    
    private var saveConfirmationOverlay: some View {
        ZStack {
            Color.black.opacity(0.9)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(TFTheme.yellow)
                
                Text("Performance Saved!")
                    .appFont(.title, weight: .bold)
                    .foregroundStyle(.white)
                
                Text("Your recording and show notes are ready to review.")
                    .appFont(.body)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                Button {
                    showSaveConfirmation = false
                    dismiss()
                } label: {
                    Text("Done")
                        .appFont(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(TFTheme.yellow)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 32)
                .padding(.top, 8)
            }
            .padding(32)
            .background(Color(white: 0.12))
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .padding(.horizontal, 32)
        }
    }
}

#Preview {
    StageModeViewScript(setlist: Setlist(title: "Preview Set"), venue: "Test Venue")
}
