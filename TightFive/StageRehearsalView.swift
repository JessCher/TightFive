import SwiftUI
import SwiftUI
import SwiftData
import Foundation
import UIKit

/// Stage Rehearsal Mode - Test voice recognition and auto-advance without recording
///
/// **Purpose:**
/// - Build confidence with automatic cue card transitions
/// - Verify anchor and exit phrase recognition
/// - Test audio levels and microphone setup
/// - Fine-tune recognition settings before actual performance
/// - No recording, no performance data saved
///
/// **Enhanced Feedback:**
/// - Large, prominent phrase detection indicators
/// - Real-time confidence scores
/// - Audio level monitoring with visual feedback
/// - Detailed analytics on exit
struct StageRehearsalView: View {
    @Environment(\.dismiss) private var dismiss
    
    let setlist: Setlist
    
    @StateObject private var engine = StageRehearsalEngine()
    @State private var showExitConfirmation = false
    @State private var showAnalytics = false
    @State private var finalAnalytics: RehearsalAnalytics?
    @State private var isInitialized = false
    @State private var isRehearsalActive = false  // NEW: Track if rehearsal is running
    
    // Timer
    @State private var elapsedTime: TimeInterval = 0
    @State private var isTimerRunning = false
    @State private var timer: Timer?
    
    // Access settings (using @Observable, so just reference directly)
    private var settings: CueCardSettingsStore { CueCardSettingsStore.shared }
    
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
                        
                        ZStack {
                            cueCardContent
                            
                            // Enhanced recognition feedback overlay
                            VStack {
                                Spacer()
                                recognitionFeedbackOverlay
                            }
                        }
                    }
                }
                
                if showExitConfirmation {
                    exitConfirmationOverlay
                }
                
                if showAnalytics, let analytics = finalAnalytics {
                    analyticsOverlay(analytics: analytics)
                }
            }
        }
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .onAppear { 
            // Keep screen awake during Stage Rehearsal
            UIApplication.shared.isIdleTimerDisabled = true
            startRehearsalIfNeeded() 
        }
        .onDisappear { 
            // Re-enable screen dimming when exiting Stage Rehearsal
            UIApplication.shared.isIdleTimerDisabled = false
            _ = engine.stop()
        }
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    handleSwipe(value)
                }
        )
    }
    
    private func startRehearsalIfNeeded() {
        guard !isInitialized else { return }
        isInitialized = true
        
        let cards = CueCard.extractCards(from: setlist)
        engine.configure(cards: cards)
        
        // Don't start automatically - wait for user to press play
    }
    
    private func startRehearsal() {
        guard !isRehearsalActive else { return }
        isRehearsalActive = true
        
        Task {
            await engine.start()
        }
        
        startTimer()
    }
    
    private func pauseRehearsal() {
        stopTimer()
        // Keep engine running but pause timer
    }
    
    private func toggleRehearsal() {
        if isTimerRunning {
            pauseRehearsal()
        } else {
            if !isRehearsalActive {
                startRehearsal()
            } else {
                startTimer()
            }
        }
    }
    
    private func endRehearsal() {
        let analytics = engine.stop()
        finalAnalytics = analytics
        showAnalytics = true
    }
    
    private func handleSwipe(_ gesture: DragGesture.Value) {
        let horizontalMovement = gesture.translation.width
        let verticalMovement = gesture.translation.height
        
        // Only handle horizontal swipes (not vertical scrolling)
        guard abs(horizontalMovement) > abs(verticalMovement) else { return }
        
        if horizontalMovement < -50 {
            // Swipe left = next card
            engine.advanceToNextCard(automatic: false)
        } else if horizontalMovement > 50 {
            // Swipe right = previous card
            engine.goToPreviousCard()
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
                
                // Timer display (clickable to start/pause)
                Button {
                    toggleRehearsal()
                } label: {
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
                
                Spacer()
                
                // Rehearsal indicator
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    
                    Text("REHEARSAL")
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
            
            // Audio level indicator
            audioLevelIndicator
                .padding(.horizontal, 20)
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
    
    // MARK: - Audio Level Indicator
    
    private var audioLevelIndicator: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(audioLevelColor)
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.1))
                        
                        // Level bar
                        RoundedRectangle(cornerRadius: 4)
                            .fill(audioLevelColor)
                            .frame(width: geo.size.width * CGFloat(engine.audioLevel))
                    }
                }
                .frame(height: 8)
                
                Text("\(Int(engine.audioLevel * 100))%")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 40, alignment: .trailing)
            }
            
            // Audio quality warning
            if engine.isAudioTooLow {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                    Text("Audio too low - speak louder or move closer")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(.orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.15))
                .clipShape(Capsule())
            } else if engine.isAudioTooHigh {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                    Text("Audio too high - move back from microphone")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(.orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.15))
                .clipShape(Capsule())
            }
        }
    }
    
    private var audioLevelColor: Color {
        if engine.isAudioTooLow || engine.isAudioTooHigh {
            return .orange
        } else if engine.audioLevel > 0.2 {
            return .green
        } else {
            return .white.opacity(0.5)
        }
    }
    
    // MARK: - Cue Card Content
    
    private var cueCardContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                if let card = engine.currentCard {
                    Text(card.fullText)
                        .font(.system(size: calculateFontSize(for: card), weight: .regular))
                        .foregroundStyle(settings.textColor.color.opacity(0.9))
                        .lineSpacing(CGFloat(settings.lineSpacing))
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 40)
                } else {
                    Text("No card available")
                        .appFont(.body)
                        .foregroundStyle(.white.opacity(0.5))
                }
                
                // Add more space at bottom for analytics overlay
                Spacer(minLength: 350)
            }
        }
        .scrollIndicators(.hidden)
    }
    
    private func calculateFontSize(for card: CueCard) -> CGFloat {
        let baseSize = CGFloat(settings.fontSize)
        let textLength = card.fullText.count
        
        // Scale font based on content length - more aggressive scaling for rehearsal
        if textLength < 200 {
            return baseSize * 1.0 // Reduced from 1.2 to fit better
        } else if textLength > 800 {
            return baseSize * 0.6 // Reduced from 0.7 to fit better
        } else {
            return baseSize * 0.85 // Slightly smaller overall
        }
    }
    
    // MARK: - Recognition Feedback Overlay
    
    private var recognitionFeedbackOverlay: some View {
        VStack(spacing: 12) {
            // Card progress
            HStack(spacing: 12) {
                Text(engine.formattedProgress)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.2))
                        
                        RoundedRectangle(cornerRadius: 3)
                            .fill(TFTheme.yellow)
                            .frame(width: geo.size.width * engine.progressFraction)
                    }
                }
                .frame(height: 5)
            }
            .padding(.horizontal, 24)
            
            // Phrase detection indicators
            if settings.showPhraseFeedback {
                HStack(spacing: 12) {
                    // Anchor phrase
                    phraseDetectionCard(
                        type: "ANCHOR",
                        confidence: engine.anchorPhraseConfidence,
                        isActive: engine.lastDetectionType == .anchor,
                        color: .blue
                    )
                    
                    // Exit phrase
                    phraseDetectionCard(
                        type: "EXIT",
                        confidence: engine.exitPhraseConfidence,
                        isActive: engine.lastDetectionType == .exit,
                        color: .green
                    )
                }
                .padding(.horizontal, 24)
            }
            
            // Swipe hint
            if !engine.isListening || engine.partialTranscript.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "hand.draw")
                        .font(.system(size: 10))
                    Text("Swipe left/right to navigate manually")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(.white.opacity(0.5))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.05))
                .clipShape(Capsule())
            }
        }
        .padding(.vertical, 16)
        .padding(.bottom, 8)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.95), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    private func phraseDetectionCard(type: String, confidence: Double, isActive: Bool, color: Color) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Circle()
                    .fill(isActive ? color : Color.white.opacity(0.3))
                    .frame(width: 6, height: 6)
                
                Text(type)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(isActive ? color : .white.opacity(0.6))
                    .kerning(0.3)
            }
            
            Text("\(Int(confidence * 100))%")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(isActive ? color : .white.opacity(0.6))
                .monospacedDigit()
            
            // Confidence bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.1))
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(isActive ? color : Color.white.opacity(0.3))
                        .frame(width: geo.size.width * confidence)
                }
            }
            .frame(height: 3)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isActive ? color.opacity(0.15) : Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isActive ? color.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1.5)
        )
        .scaleEffect(isActive ? 1.03 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isActive)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(TFTheme.yellow.opacity(0.3))
            
            Text("No Content to Rehearse")
                .appFont(.title, weight: .bold)
                .foregroundStyle(.white)
            
            Text("Add content to your setlist before starting rehearsal")
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
                Image(systemName: "flag.checkered.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.green)
                
                Text("End Rehearsal?")
                    .appFont(.title2, weight: .bold)
                    .foregroundStyle(.white)
                
                Text("You'll see a detailed analytics report of your rehearsal session.")
                    .appFont(.body)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                VStack(spacing: 12) {
                    // View Analytics
                    Button {
                        showExitConfirmation = false
                        endRehearsal()
                    } label: {
                        HStack {
                            Image(systemName: "chart.bar.fill")
                            Text("View Analytics")
                        }
                        .appFont(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(TFTheme.yellow)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // Cancel
                    Button("Continue Rehearsing") { 
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
    
    // MARK: - Analytics Overlay
    
    private func analyticsOverlay(analytics: RehearsalAnalytics) -> some View {
        ZStack {
            Color.black.opacity(0.95)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "chart.bar.doc.horizontal.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(TFTheme.yellow)
                        
                        Text("Rehearsal Analytics")
                            .appFont(.title, weight: .bold)
                            .foregroundStyle(.white)
                        
                        Text("Duration: \(formatDuration(analytics.totalDuration))")
                            .appFont(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.top, 40)
                    
                    // Summary Stats
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            statCard(
                                value: "\(analytics.automaticTransitions)",
                                label: "Auto Transitions",
                                color: .green
                            )
                            
                            statCard(
                                value: "\(analytics.manualTransitions)",
                                label: "Manual Transitions",
                                color: .blue
                            )
                        }
                        
                        HStack(spacing: 12) {
                            statCard(
                                value: "\(Int(analytics.automaticTransitionPercentage))%",
                                label: "Auto Success Rate",
                                color: analytics.automaticTransitionPercentage > 70 ? .green : .orange
                            )
                            
                            statCard(
                                value: "\(Int(analytics.averageConfidence * 100))%",
                                label: "Avg Confidence",
                                color: analytics.averageConfidence > 0.7 ? .green : .orange
                            )
                        }
                    }
                    .padding(.horizontal, 32)
                    
                    // Audio Quality
                    analyticsSectionCard(title: "Audio Quality", icon: "waveform") {
                        VStack(spacing: 12) {
                            HStack {
                                Text("Average Level:")
                                    .foregroundStyle(.white.opacity(0.7))
                                Spacer()
                                Text("\(Int(analytics.averageAudioLevel * 100))%")
                                    .foregroundStyle(.white)
                                    .bold()
                            }
                            
                            HStack {
                                Text("Peak Level:")
                                    .foregroundStyle(.white.opacity(0.7))
                                Spacer()
                                Text("\(Int(analytics.peakAudioLevel * 100))%")
                                    .foregroundStyle(.white)
                                    .bold()
                            }
                        }
                        .appFont(.body)
                    }
                    
                    // Recognition Performance
                    analyticsSectionCard(title: "Recognition Performance", icon: "mic.fill") {
                        VStack(spacing: 12) {
                            HStack {
                                Text("Cards Practiced:")
                                    .foregroundStyle(.white.opacity(0.7))
                                Spacer()
                                Text("\(analytics.cardAnalytics.count)")
                                    .foregroundStyle(.white)
                                    .bold()
                            }
                            
                            HStack {
                                Text("Successful Recognition:")
                                    .foregroundStyle(.white.opacity(0.7))
                                Spacer()
                                Text("\(analytics.cardsWithSuccessfulRecognition)")
                                    .foregroundStyle(.white)
                                    .bold()
                            }
                            
                            HStack {
                                Text("Total Transcriptions:")
                                    .foregroundStyle(.white.opacity(0.7))
                                Spacer()
                                Text("\(analytics.totalTranscriptionsReceived)")
                                    .foregroundStyle(.white)
                                    .bold()
                            }
                        }
                        .appFont(.body)
                    }
                    
                    // Problem Cards
                    if !analytics.cardsWithProblems.isEmpty {
                        analyticsSectionCard(title: "Cards Needing Attention", icon: "exclamationmark.triangle.fill") {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(analytics.cardsWithProblems, id: \.cardIndex) { cardIndex, issues in
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Card \(cardIndex + 1)")
                                            .appFont(.headline)
                                            .foregroundStyle(TFTheme.yellow)
                                        
                                        ForEach(issues, id: \.self) { issue in
                                            HStack(spacing: 6) {
                                                Circle()
                                                    .fill(Color.orange)
                                                    .frame(width: 4, height: 4)
                                                Text(issue)
                                                    .appFont(.subheadline)
                                                    .foregroundStyle(.white.opacity(0.8))
                                            }
                                        }
                                    }
                                    .padding(.bottom, 8)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    
                    // Recommendations
                    if !analytics.recommendations.isEmpty {
                        analyticsSectionCard(title: "Recommendations", icon: "lightbulb.fill") {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(analytics.recommendations, id: \.self) { recommendation in
                                    HStack(alignment: .top, spacing: 8) {
                                        Text("•")
                                            .foregroundStyle(TFTheme.yellow)
                                        Text(recommendation)
                                            .appFont(.body)
                                            .foregroundStyle(.white.opacity(0.9))
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    
                    // Done button
                    Button {
                        showAnalytics = false
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
                    .padding(.bottom, 40)
                }
            }
        }
    }
    
    private func statCard(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .monospacedDigit()
            
            Text(label)
                .appFont(.caption)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func analyticsSectionCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(TFTheme.yellow)
                
                Text(title)
                    .appFont(.headline)
                    .foregroundStyle(.white)
            }
            
            content()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 32)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
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
}

#Preview {
    StageRehearsalView(setlist: Setlist(title: "Preview Set"))
}
