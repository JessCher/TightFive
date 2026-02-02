import SwiftUI
import SwiftUI
import SwiftData
import UIKit

/// Wrapper for Stage Mode - routes to appropriate implementation based on settings
struct StageModeView: View {
    let setlist: Setlist
    var venue: String = ""
    
    // Access settings - using @State to enable observation of the @Observable singleton
    @State private var settings: CueCardSettingsStore = .shared
    
    var body: some View {
        switch settings.stageModeType {
        case .cueCards:
            StageModeViewCueCard(setlist: setlist, venue: venue)
        case .script:
            StageModeViewScript(setlist: setlist, venue: venue)
        case .teleprompter:
            StageModeViewTeleprompter(setlist: setlist, venue: venue)
        }
    }
}

/// New Stage Mode with cue card architecture and dual-phrase recognition.
///
/// **Key Features:**
/// - Display ONE card at a time (full screen, auto-scaled)
/// - Exit phrase detection triggers next card
/// - Anchor phrase confirms current card
/// - Manual swipe gestures for fallback
/// - Clean, glanceable performance UI
struct StageModeViewCueCard: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let setlist: Setlist
    var venue: String = ""
    
    @StateObject private var engine = CueCardEngine()
    @State private var showExitConfirmation = false
    @State private var showSaveConfirmation = false
    @State private var isInitialized = false
    @State private var dragOffset: CGFloat = 0
    @State private var cardScale: CGFloat = 1.0
    
    // Access settings - using @State to enable bindings to the @Observable singleton
    @State private var settings: CueCardSettingsStore = .shared
    
    private var hasContent: Bool {
        !engine.cards.isEmpty
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
                        cardContent(geometry: geometry)
                        bottomBar
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
            engine.stop() 
        }
        .gesture(
            DragGesture()
                .onChanged { gesture in
                    dragOffset = gesture.translation.width
                }
                .onEnded { gesture in
                    let threshold: CGFloat = 100
                    
                    if gesture.translation.width > threshold {
                        // Swipe right → previous card
                        engine.goToPreviousCard()
                    } else if gesture.translation.width < -threshold {
                        // Swipe left → next card
                        engine.advanceToNextCard(automatic: false)
                    }
                    
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        dragOffset = 0
                    }
                }
        )
    }
    
    private func startSessionIfNeeded() {
        guard !isInitialized else { return }
        isInitialized = true
        
        let cards = CueCard.extractCards(from: setlist)
        engine.configure(cards: cards)
        
        engine.onCardTransition = { index, card in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                cardScale = 1.05
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    cardScale = 1.0
                }
            }
        }
        
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
            
            // Store insights as strings (can be enhanced with structured data later)
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
    
    // MARK: - UI Components
    
    private func topBar(geometry: GeometryProxy) -> some View {
        HStack(spacing: 16) {
            Button { showExitConfirmation = true } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
            
            Spacer()
            
            // Progress indicator
            VStack(spacing: 2) {
                Text(engine.formattedProgress)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                
                ProgressView(value: engine.progressFraction)
                    .tint(TFTheme.yellow)
                    .frame(width: 80)
            }
            
            Spacer()
            
            if engine.isRunning {
                recordingIndicator
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, geometry.safeAreaInsets.top + 8)
        .padding(.bottom, 12)
        .background(
            LinearGradient(
                colors: [Color.black, Color.black.opacity(0.85), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)
        )
    }
    
    private var recordingIndicator: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.red)
                .frame(width: 10, height: 10)
            
            Text(engine.formattedTime)
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.6))
        .clipShape(Capsule())
    }
    
    private func cardContent(geometry: GeometryProxy) -> some View {
        ZStack {
            if let card = engine.currentCard {
                cueCardView(card: card, geometry: geometry)
                    .scaleEffect(cardScale)
                    .offset(x: dragOffset * 0.5) // Parallax effect on drag
            } else {
                Text("No more cards")
                    .appFont(.title, weight: .bold)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func cueCardView(card: CueCard, geometry: GeometryProxy) -> some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                // Main card content - auto-scale to fit
                ScrollView {
                    Text(card.fullText)
                        .font(scaledFont(for: card.fullText, in: geo.size))
                        .foregroundStyle(settings.textColor.color)
                        .lineSpacing(settings.lineSpacing)
                        .multilineTextAlignment(.leading)
                        .padding(32)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollIndicators(.hidden)
                
                // Recognition feedback (optional)
                if settings.showPhraseFeedback {
                    phraseFeedbackBar
                        .padding(.horizontal, 24)
                        .padding(.bottom, 12)
                }
            }
        }
    }
    
    private func scaledFont(for text: String, in size: CGSize) -> Font {
        let wordCount = text.split(whereSeparator: \.isWhitespace).count
        
        // Start with user's preferred base font size
        let userBaseFontSize = settings.fontSize
        
        // Apply scaling factor based on content length
        let scaleFactor: CGFloat
        if wordCount < 30 {
            scaleFactor = 1.2 // Short bit - slightly larger
        } else if wordCount < 60 {
            scaleFactor = 1.0 // Medium bit - use base size
        } else if wordCount < 100 {
            scaleFactor = 0.85 // Longer bit - slightly smaller
        } else {
            scaleFactor = 0.7 // Very long bit - much smaller
        }
        
        let finalSize = userBaseFontSize * scaleFactor
        return .system(size: finalSize, weight: .medium)
    }
    
    private var phraseFeedbackBar: some View {
        HStack(spacing: 16) {
            // Anchor phrase indicator
            VStack(alignment: .leading, spacing: 4) {
                Text("Anchor")
                    .appFont(.caption2, weight: .semibold)
                    .foregroundStyle(.white.opacity(0.5))
                
                ProgressView(value: engine.anchorPhraseConfidence)
                    .tint(.green.opacity(0.8))
                    .frame(width: 60)
            }
            
            Spacer()
            
            // Listening indicator
            HStack(spacing: 6) {
                Image(systemName: engine.isListening ? "waveform" : "waveform.slash")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(engine.isListening ? .green : .white.opacity(0.4))
                
                Text(engine.isListening ? "Listening" : "Silent")
                    .appFont(.caption2, weight: .semibold)
                    .foregroundStyle(engine.isListening ? .green : .white.opacity(0.4))
            }
            
            Spacer()
            
            // Exit phrase indicator
            VStack(alignment: .trailing, spacing: 4) {
                Text("Exit")
                    .appFont(.caption2, weight: .semibold)
                    .foregroundStyle(.white.opacity(0.5))
                
                ProgressView(value: engine.exitPhraseConfidence)
                    .tint(TFTheme.yellow.opacity(0.8))
                    .frame(width: 60)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private var bottomBar: some View {
        HStack(spacing: 18) {
            // Auto-advance toggle
            Button {
                settings.autoAdvanceEnabled.toggle()
                hapticFeedback()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: settings.autoAdvanceEnabled ? "sparkles" : "hand.raised.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text(settings.autoAdvanceEnabled ? "Auto" : "Manual")
                        .appFont(.caption, weight: .bold)
                }
                .foregroundStyle(settings.autoAdvanceEnabled ? .black : .white.opacity(0.9))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(settings.autoAdvanceEnabled ? TFTheme.yellow : Color.white.opacity(0.12))
                .clipShape(Capsule())
            }
            
            Spacer()
            
            // Previous card
            Button {
                engine.goToPreviousCard()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(engine.hasPreviousCard ? .white.opacity(0.9) : .white.opacity(0.3))
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(engine.hasPreviousCard ? 0.1 : 0.05))
                    .clipShape(Circle())
            }
            .disabled(!engine.hasPreviousCard)
            
            // Next card
            Button {
                engine.advanceToNextCard(automatic: false)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(engine.hasNextCard ? .white.opacity(0.9) : .white.opacity(0.3))
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(engine.hasNextCard ? 0.1 : 0.05))
                    .clipShape(Circle())
            }
            .disabled(!engine.hasNextCard)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.85), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    // MARK: - Overlays
    
    private var exitConfirmationOverlay: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture { showExitConfirmation = false }
            
            VStack(spacing: 18) {
                Text("Save Performance?")
                    .appFont(.title2, weight: .bold)
                    .foregroundStyle(.white)
                
                Text("Do you want to save this performance recording?")
                    .appFont(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                
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
                        .padding(.vertical, 14)
                        .background(TFTheme.yellow)
                        .clipShape(Capsule())
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
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Capsule())
                    }
                    
                    // Cancel
                    Button("Cancel") { 
                        showExitConfirmation = false 
                    }
                    .appFont(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.top, 4)
                }
            }
            .padding(22)
            .background(Color.black.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .padding(.horizontal, 24)
        }
    }
    
    private var saveConfirmationOverlay: some View {
        ZStack {
            Color.black.opacity(0.8).ignoresSafeArea()
            
            VStack(spacing: 14) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.green)
                
                Text("Performance Saved")
                    .appFont(.title3, weight: .bold)
                    .foregroundStyle(.white)
                
                Button("Done") { dismiss() }
                    .appFont(.headline)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(TFTheme.yellow)
                    .clipShape(Capsule())
                    .padding(.top, 6)
            }
            .padding(22)
            .background(Color.black.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .padding(.horizontal, 24)
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 56))
                .foregroundStyle(.white.opacity(0.3))
            
            Text("No script content")
                .appFont(.title2, weight: .semibold)
                .foregroundStyle(.white)
            
            Text("Add content to your setlist script first.")
                .appFont(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
            
            Button("Go Back") { dismiss() }
                .appFont(.headline)
                .foregroundStyle(.black)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(TFTheme.yellow)
                .clipShape(Capsule())
        }
    }
    
    // MARK: - Helpers
    
    private func hapticFeedback() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

#Preview {
    StageModeViewCueCard(setlist: Setlist(title: "Test Set"))
}
