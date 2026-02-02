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
    
    // Timer
    @State private var elapsedTime: TimeInterval = 0
    @State private var isTimerRunning = false
    @State private var timer: Timer?
    
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
        .onAppear { 
            // Keep screen awake during Stage Mode
            UIApplication.shared.isIdleTimerDisabled = true
            startSessionIfNeeded() 
        }
        .onDisappear { 
            // Re-enable screen dimming when exiting Stage Mode
            UIApplication.shared.isIdleTimerDisabled = false
            stopTimer()
            engine.stop() 
        }
    }
    
    private func startSessionIfNeeded() {
        guard !isInitialized else { return }
        isInitialized = true
        
        // Start timer automatically
        startTimer()
        
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
    
    private func discardSession() {
        // Stop recording and delete the audio file without saving performance
        engine.stop()
        dismiss()
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
                
                // Timer display
                timerDisplay
                
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
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(TFTheme.yellow)
                
                Text("Save Performance?")
                    .appFont(.title2, weight: .bold)
                    .foregroundStyle(.white)
                
                Text("Do you want to save this performance recording?")
                    .appFont(.body)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                VStack(spacing: 12) {
                    // Save Performance
                    Button {
                        showExitConfirmation = false
                        endSession()
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Save Performance")
                        }
                        .appFont(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(TFTheme.yellow)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // Discard
                    Button {
                        showExitConfirmation = false
                        discardSession()
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Discard")
                        }
                        .appFont(.headline)
                        .foregroundStyle(.red.opacity(0.9))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // Cancel
                    Button("Cancel") { 
                        showExitConfirmation = false 
                    }
                    .appFont(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.top, 4)
                }
                .padding(.horizontal, 32)
                .padding(.top, 8)
            }
            .padding(32)
            .background(Color(white: 0.12))
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
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
    
    // MARK: - Timer
    
    private var timerDisplay: some View {
        Button { toggleTimer() } label: {
            HStack(spacing: 10) {
                Image(systemName: isTimerRunning ? "pause.fill" : "play.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isTimerRunning ? TFTheme.yellow : .white.opacity(0.5))
                
                Text(formatTime(elapsedTime))
                    .font(.system(size: 20, weight: .medium, design: .monospaced))
                    .foregroundStyle(isTimerRunning ? TFTheme.yellow : .white)
                    .monospacedDigit()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.08))
            .clipShape(Capsule())
        }
    }
    
    private func formatTime(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func startTimer() {
        isTimerRunning = true
        timer = Timer(timeInterval: 1.0, repeats: true) { _ in
            elapsedTime += 1
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    private func stopTimer() {
        isTimerRunning = false
        timer?.invalidate()
        timer = nil
    }
    
    private func toggleTimer() {
        if isTimerRunning {
            stopTimer()
        } else {
            startTimer()
        }
    }
}

#Preview {
    StageModeViewScript(setlist: Setlist(title: "Preview Set"), venue: "Test Venue")
}
