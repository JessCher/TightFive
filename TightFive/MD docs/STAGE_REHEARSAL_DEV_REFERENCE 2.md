# Stage Rehearsal - Developer Quick Reference

## File Locations

```
/StageRehearsalEngine.swift      - Recognition engine (no recording)
/StageRehearsalView.swift        - Rehearsal UI with analytics
/RunModeView.swift               - Modified (added button + sheet)
```

## Key APIs

### StageRehearsalEngine

```swift
@MainActor
final class StageRehearsalEngine: ObservableObject {
    
    // Published State
    @Published private(set) var currentCardIndex: Int
    @Published private(set) var isRunning: Bool
    @Published private(set) var isListening: Bool
    @Published private(set) var audioLevel: Float
    @Published private(set) var exitPhraseConfidence: Double
    @Published private(set) var anchorPhraseConfidence: Double
    @Published private(set) var lastDetectionType: DetectionType?
    @Published private(set) var isAudioTooLow: Bool
    @Published private(set) var isAudioTooHigh: Bool
    
    // Lifecycle
    func configure(cards: [CueCard])
    func start() async
    func stop() -> RehearsalAnalytics
    
    // Navigation
    func advanceToNextCard(automatic: Bool = false)
    func goToPreviousCard()
    func jumpToCard(index: Int)
    
    // Current State
    var currentCard: CueCard?
    var hasNextCard: Bool
    var hasPreviousCard: Bool
    var progressFraction: Double
    var formattedTime: String
    var formattedProgress: String
}
```

### RehearsalAnalytics

```swift
struct RehearsalAnalytics {
    var sessionStartTime: Date?
    var sessionEndTime: Date?
    var totalDuration: TimeInterval
    
    var automaticTransitions: Int
    var manualTransitions: Int
    var transitions: [(from: Int, to: Int, timestamp: TimeInterval, wasAutomatic: Bool, exitConfidence: Double?)]
    
    var totalTranscriptionsReceived: Int
    var recognitionErrors: Int
    var confidenceScores: [Double]
    
    var cardAnalytics: [Int: CardAnalytics]
    var audioLevelSamples: [Double]
    
    // Computed
    var totalTransitions: Int
    var automaticTransitionPercentage: Double
    var averageConfidence: Double
    var averageAudioLevel: Double
    var peakAudioLevel: Double
    var cardsWithSuccessfulRecognition: Int
    var cardsWithProblems: [(cardIndex: Int, issues: [String])]
    var recommendations: [String]
    
    struct CardAnalytics {
        var cardIndex: Int
        var anchorDetections: [(confidence: Double, transcript: String)]
        var exitDetections: [(confidence: Double, transcript: String)]
        var recognitionAttempts: [(confidence: Double, exitConf: Double, anchorConf: Double)]
        
        var bestAnchorConfidence: Double
        var bestExitConfidence: Double
        var averageRecognitionConfidence: Double
        var hadSuccessfulAnchor: Bool
        var hadSuccessfulExit: Bool
    }
}
```

### StageRehearsalView

```swift
struct StageRehearsalView: View {
    let setlist: Setlist
    
    @StateObject private var engine = StageRehearsalEngine()
    @ObservedObject private var settings = CueCardSettingsStore.shared
    
    var body: some View { /* ... */ }
}
```

## Usage Example

```swift
// In RunModeView or any other view
@State private var showRehearsal = false

Button("Start Rehearsal") {
    showRehearsal = true
}
.fullScreenCover(isPresented: $showRehearsal) {
    StageRehearsalView(setlist: mySetlist)
}
```

## Data Flow

```
User launches StageRehearsalView
    ↓
View.onAppear
    ↓
engine.configure(cards: extractedCards)
    ↓
engine.start() async
    ↓
┌─────────────────────────────────────┐
│ ACTIVE SESSION                      │
│                                     │
│ Speech Recognition → Transcript     │
│          ↓                          │
│ processTranscript() → Match phrases │
│          ↓                          │
│ Update confidence scores            │
│          ↓                          │
│ Record analytics                    │
│          ↓                          │
│ Auto-advance if exit detected       │
└─────────────────────────────────────┘
    ↓
User taps exit
    ↓
let analytics = engine.stop()
    ↓
Display analytics overlay
    ↓
User taps done
    ↓
Dismiss
```

## Important Methods

### Starting a Session

```swift
private func startRehearsalIfNeeded() {
    guard !isInitialized else { return }
    isInitialized = true
    
    let cards = CueCard.extractCards(from: setlist)
    engine.configure(cards: cards)
    
    Task {
        await engine.start()
    }
}
```

### Ending a Session

```swift
private func endRehearsal() {
    let analytics = engine.stop()
    finalAnalytics = analytics
    showAnalytics = true
}
```

### Handling Swipes

```swift
private func handleSwipe(_ gesture: DragGesture.Value) {
    let horizontalMovement = gesture.translation.width
    let verticalMovement = gesture.translation.height
    
    guard abs(horizontalMovement) > abs(verticalMovement) else { return }
    
    if horizontalMovement < -50 {
        engine.advanceToNextCard(automatic: false)
    } else if horizontalMovement > 50 {
        engine.goToPreviousCard()
    }
}
```

## View Components

### Audio Level Indicator

```swift
private var audioLevelIndicator: some View {
    VStack(spacing: 6) {
        HStack(spacing: 8) {
            Image(systemName: "mic.fill")
                .foregroundStyle(audioLevelColor)
            
            // Level bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(audioLevelColor)
                        .frame(width: geo.size.width * CGFloat(engine.audioLevel))
                }
            }
            .frame(height: 8)
            
            Text("\(Int(engine.audioLevel * 100))%")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
        }
        
        // Warnings
        if engine.isAudioTooLow {
            warningView(text: "Audio too low - speak louder or move closer")
        }
    }
}
```

### Phrase Detection Card

```swift
private func phraseDetectionCard(type: String, confidence: Double, isActive: Bool, color: Color) -> some View {
    VStack(spacing: 8) {
        HStack(spacing: 6) {
            Circle()
                .fill(isActive ? color : Color.white.opacity(0.3))
                .frame(width: 8, height: 8)
            Text(type)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(isActive ? color : .white.opacity(0.6))
        }
        
        Text("\(Int(confidence * 100))%")
            .font(.system(size: 24, weight: .bold, design: .rounded))
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
        .frame(height: 4)
    }
    .padding(16)
    .frame(maxWidth: .infinity)
    .background(
        RoundedRectangle(cornerRadius: 16)
            .fill(isActive ? color.opacity(0.15) : Color.white.opacity(0.05))
    )
    .overlay(
        RoundedRectangle(cornerRadius: 16)
            .stroke(isActive ? color.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 2)
    )
    .scaleEffect(isActive ? 1.05 : 1.0)
    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isActive)
}
```

## Analytics Display

### Summary Stats

```swift
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
```

### Problem Cards

```swift
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
            }
        }
    }
}
```

### Recommendations

```swift
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
    }
}
```

## Engine Implementation Details

### Audio Monitoring (No Recording)

```swift
// Install tap for level monitoring only
inputNode.installTap(onBus: 0, bufferSize: 256, format: inputFormat) { [weak self] buffer, _ in
    guard let self else { return }
    
    // Send to speech recognizer
    self.recognitionRequest?.append(buffer)
    
    // Compute level (NO file writing)
    let level = Self.computeLevel(from: buffer)
    Task { @MainActor in
        self.audioLevel = level
        self.updateAudioQualityIndicators(level: level)
    }
}
```

### Analytics Recording

```swift
mutating func recordTransition(from: Int, to: Int, timestamp: TimeInterval, wasAutomatic: Bool, exitConfidence: Double?) {
    transitions.append((from: from, to: to, timestamp: timestamp, wasAutomatic: wasAutomatic, exitConfidence: exitConfidence))
}

mutating func recordAnchorPhraseDetection(cardIndex: Int, confidence: Double, transcript: String) {
    if cardAnalytics[cardIndex] == nil {
        cardAnalytics[cardIndex] = CardAnalytics(cardIndex: cardIndex)
    }
    cardAnalytics[cardIndex]?.anchorDetections.append((confidence: confidence, transcript: transcript))
}

mutating func recordExitPhraseDetection(cardIndex: Int, confidence: Double, transcript: String) {
    if cardAnalytics[cardIndex] == nil {
        cardAnalytics[cardIndex] = CardAnalytics(cardIndex: cardIndex)
    }
    cardAnalytics[cardIndex]?.exitDetections.append((confidence: confidence, transcript: transcript))
}
```

### Recommendation Generation

```swift
var recommendations: [String] {
    var suggestions: [String] = []
    
    // Audio level
    if averageAudioLevel < 0.1 {
        suggestions.append("🎤 Audio levels are low. Speak louder or move closer to the microphone.")
    } else if averageAudioLevel > 0.8 {
        suggestions.append("🎤 Audio levels are high. You may be too close to the microphone or speaking too loudly.")
    }
    
    // Recognition confidence
    if averageConfidence < 0.5 {
        suggestions.append("🗣️ Overall recognition confidence is low. Ensure clear pronunciation and minimal background noise.")
    }
    
    // Automatic transitions
    if totalTransitions > 3 && automaticTransitionPercentage < 30 {
        suggestions.append("🔄 Most transitions were manual. Consider refining your anchor and exit phrases for better automatic detection.")
    } else if automaticTransitionPercentage > 80 {
        suggestions.append("✅ Excellent automatic transition rate! Your phrases are working well.")
    }
    
    // Per-card issues
    let problematic = cardsWithProblems
    if !problematic.isEmpty && problematic.count <= 3 {
        for (cardIndex, issues) in problematic {
            suggestions.append("📝 Card \(cardIndex + 1): \(issues.joined(separator: ", "))")
        }
    }
    
    return suggestions
}
```

## Permissions Handling

```swift
func start() async {
    errorMessage = nil
    
    guard let recognizer = speechRecognizer, recognizer.isAvailable else {
        errorMessage = "Speech recognition not available."
        return
    }
    
    let speechOK = await Permissions.requestSpeechIfNeeded()
    let micOK = await Permissions.requestMicrophoneIfNeeded()
    
    guard speechOK && micOK else {
        errorMessage = "Speech or microphone permission not granted."
        return
    }
    
    // Continue with setup...
}
```

## Settings Integration

```swift
// In StageRehearsalView
@ObservedObject private var settings = CueCardSettingsStore.shared

// Font size calculation
private func calculateFontSize(for card: CueCard) -> CGFloat {
    let baseSize = CGFloat(settings.fontSize)
    let textLength = card.fullText.count
    
    if textLength < 200 {
        return baseSize * 1.2
    } else if textLength > 800 {
        return baseSize * 0.7
    } else {
        return baseSize
    }
}

// Text color
Text(card.fullText)
    .foregroundStyle(settings.textColor.color.opacity(0.9))

// Line spacing
Text(card.fullText)
    .lineSpacing(CGFloat(settings.lineSpacing))
```

## Cleanup

```swift
.onDisappear {
    _ = engine.stop()
}

func stop() -> RehearsalAnalytics {
    isRunning = false
    isListening = false
    
    analytics.sessionEndTime = Date()
    analytics.totalDuration = currentTime
    
    // Invalidate timers
    levelTimer?.invalidate(); levelTimer = nil
    timeTimer?.invalidate(); timeTimer = nil
    watchdogTimer?.invalidate(); watchdogTimer = nil
    
    // Stop recognition
    cancelRecognitionOnly()
    
    // Stop audio engine
    if let engine = audioEngine {
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
    }
    audioEngine = nil
    
    return analytics
}
```

## Common Patterns

### Confidence Display

```swift
// Always show as percentage (0-100)
Text("\(Int(confidence * 100))%")
    .monospacedDigit()

// Color based on value
.foregroundStyle(confidence > 0.7 ? .green : confidence > 0.4 ? .orange : .red)
```

### Animation on Detection

```swift
.scaleEffect(isActive ? 1.05 : 1.0)
.animation(.spring(response: 0.3, dampingFraction: 0.7), value: isActive)
```

### Haptic Feedback

```swift
private func hapticFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle) {
    UIImpactFeedbackGenerator(style: style).impactOccurred()
}

// Usage
engine.advanceToNextCard(automatic: true)  // .medium haptic
engine.goToPreviousCard()                  // .light haptic
```

## Debug Logging

```swift
print("✅ EXIT detected (confidence: \(String(format: "%.2f", exitResult.confidence)))")
print("✅ ANCHOR confirmed (confidence: \(String(format: "%.2f", anchorResult.confidence)))")
print("🎤 Audio configured: \(session.sampleRate)Hz, \(session.ioBufferDuration * 1000)ms buffer")
```

## Performance Tips

- Audio level computation is optimized (RMS calculation)
- Analytics use Swift arrays (efficient for append)
- Card analytics lazy-initialized (only when detection occurs)
- Recommendations computed once at end (not real-time)
- No file I/O during session (memory only)

## Common Issues

### "No transcriptions received"
- Check microphone permission
- Verify speech recognition available
- Check audio level > 0

### "Analytics show 0 detections"
- Verify phrases exist in CueCard
- Check user is saying actual script
- Lower sensitivity if needed

### "Memory usage high"
- Normal during long sessions
- Analytics store every transcript
- Released on dismiss

## Testing Commands

```swift
// Unit test helpers
func testAnalyticsInitialization() {
    let analytics = RehearsalAnalytics()
    XCTAssertEqual(analytics.automaticTransitions, 0)
    XCTAssertEqual(analytics.manualTransitions, 0)
    XCTAssertTrue(analytics.recommendations.isEmpty)
}

func testTransitionRecording() {
    var analytics = RehearsalAnalytics()
    analytics.recordTransition(from: 0, to: 1, timestamp: 5.0, wasAutomatic: true, exitConfidence: 0.85)
    XCTAssertEqual(analytics.transitions.count, 1)
    XCTAssertEqual(analytics.automaticTransitions, 1)
}
```

## Quick Checklist

- [ ] Engine configured with cards
- [ ] Start called with async/await
- [ ] Audio levels monitoring
- [ ] Phrase confidences updating
- [ ] Auto-advance triggering
- [ ] Analytics recording
- [ ] Stop returns analytics
- [ ] No recording created
- [ ] No performance saved
- [ ] Proper cleanup on dismiss

## Summary

StageRehearsalEngine + StageRehearsalView provide a complete practice environment with:
- ✅ Full voice recognition
- ✅ Enhanced visual feedback
- ✅ Detailed analytics
- ✅ No recording/persistence
- ✅ Perfect for preparation

Access via RunModeView's floating "Stage Rehearsal" button.
