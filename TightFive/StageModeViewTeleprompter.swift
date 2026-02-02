import SwiftData
import UIKit
import SwiftUI

/// Stage Mode with Teleprompter view - records performance with auto-scrolling teleprompter
struct StageModeViewTeleprompter: View {
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
    
    // Teleprompter state
    @State private var isTeleprompterPlaying: Bool = true
    @State private var teleprompterResetCounter: Int = 0
    @State private var isTeleprompterSettingsPresented = false
    
    // Access settings - using @State to enable bindings to the @Observable singleton
    @State private var settings: StageModeTeleprompterSettings = .shared
    
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
                        teleprompterContent(contextWindowHeight: CGFloat(settings.contextWindowHeight))
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
        .sheet(isPresented: $isTeleprompterSettingsPresented) {
            teleprompterSettingsSheet
        }
    }
    
    private func startSessionIfNeeded() {
        guard !isInitialized else { return }
        isInitialized = true
        
        // Initialize auto-start from settings
        isTeleprompterPlaying = settings.autoStartScrolling
        
        // Start timer automatically
        startTimer()
        
        // Configure engine for recording
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
                
                Spacer()
                
                // Play/Pause button
                Button {
                    toggleTeleprompter()
                } label: {
                    Image(systemName: isTeleprompterPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
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
    
    // MARK: - Teleprompter Content
    
    private func teleprompterContent(contextWindowHeight: CGFloat) -> some View {
        GeometryReader { geo in
            let midY = geo.size.height / 2
            let topClear = max(0, midY - contextWindowHeight / 2)
            
            ZStack {
                TeleprompterTextView(
                    text: teleprompterFullText,
                    fontSize: CGFloat(settings.fontSize),
                    lineSpacing: CGFloat(settings.lineSpacing),
                    speedPointsPerSecond: CGFloat(settings.scrollSpeed),
                    isPlaying: isTeleprompterPlaying,
                    startInsetTop: topClear,
                    resetSignal: teleprompterResetCounter
                )
                .ignoresSafeArea(edges: .bottom)
                .environment(\._teleprompterFontColor, settings.textColor.color)
                
                // Context window overlay
                teleprompterWindowOverlay(height: contextWindowHeight)
                    .allowsHitTesting(false)
                
                // Bottom-right drawer handle for teleprompter settings
                TeleprompterSettingsDrawer(isPresented: $isTeleprompterSettingsPresented)
                    .padding(.trailing, 10)
                    .padding(.bottom, 10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
    }
    
    private func teleprompterWindowOverlay(height: CGFloat) -> some View {
        GeometryReader { geo in
            let fullH = geo.size.height
            let midY = fullH / 2 - 40
            let topDimH = max(0, midY - height / 2)
            let bottomDimH = max(0, fullH - (midY + height / 2))
            
            ZStack {
                // Dim regions
                VStack(spacing: 0) {
                    settings.contextWindowColor.color.opacity(0.75)
                        .frame(height: topDimH)
                    
                    Color.clear
                        .frame(height: height)
                    
                    settings.contextWindowColor.color.opacity(0.75)
                        .frame(height: bottomDimH)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                
                // Read-band border lines
                VStack(spacing: 0) {
                    Spacer().frame(height: topDimH)
                    
                    Rectangle()
                        .fill(settings.contextWindowColor.color.opacity(0.9))
                        .frame(height: 1)
                    
                    Spacer().frame(height: height)
                    
                    Rectangle()
                        .fill(settings.contextWindowColor.color.opacity(0.9))
                        .frame(height: 1)
                    
                    Spacer().frame(height: bottomDimH)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .ignoresSafeArea()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var teleprompterFullText: String {
        var parts: [String] = []
        parts.append(setlist.title.uppercased())
        parts.append("") // breathing room
        
        for block in setlist.scriptBlocks {
            let content = blockContentText(block).trimmingCharacters(in: .whitespacesAndNewlines)
            if content.isEmpty { continue }
            
            parts.append(content)
            parts.append("")          // spacing
            parts.append("• • •")     // a subtle divider to cue block transitions
            parts.append("")
        }
        
        return parts.joined(separator: "\n")
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
    
    // MARK: - Teleprompter Settings Sheet
    
    private var teleprompterSettingsSheet: some View {
        NavigationStack {
            Form {
                Section("Teleprompter") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Font Size")
                            .appFont(.headline)
                        
                        Slider(value: $settings.fontSize, in: 22...54, step: 1)
                        Text("\(Int(settings.fontSize)) pt")
                            .appFont(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Scroll Speed")
                            .appFont(.headline)
                        
                        Slider(value: $settings.scrollSpeed, in: 0...140, step: 1)
                        Text("\(Int(settings.scrollSpeed)) pts/sec")
                            .appFont(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Context Window Height")
                            .appFont(.headline)
                        
                        Slider(value: $settings.contextWindowHeight, in: 120...280, step: 1)
                        Text("\(Int(settings.contextWindowHeight)) pt tall")
                            .appFont(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section {
                    Text("Tip: Use the Play/Pause button to control scrolling during your performance.")
                        .appFont(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .tfBackground()
            .navigationTitle("Teleprompter Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { isTeleprompterSettingsPresented = false }
                        .fontWeight(.semibold)
                        .foregroundStyle(TFTheme.yellow)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "scroll.fill")
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
        HStack(spacing: 10) {
            Image(systemName: isTimerRunning ? "clock.fill" : "clock")
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
    
    private func toggleTeleprompter() {
        isTeleprompterPlaying.toggle()
        // Sync timer with teleprompter
        if isTeleprompterPlaying && !isTimerRunning {
            startTimer()
        } else if !isTeleprompterPlaying && isTimerRunning {
            stopTimer()
        }
    }
}

#Preview {
    StageModeViewTeleprompter(setlist: Setlist(title: "Preview Set"), venue: "Test Venue")
}
