import Foundation

/// Bridges TeleprompterScrollTracker (voice matching) with ContinuousScrollEngine (auto-scroll)
/// 
/// This is the key integration layer:
/// - Uses TeleprompterScrollTracker to find where your voice is in the script
/// - Feeds that information to ContinuousScrollEngine as confidence/position signals
/// - The scroll engine decides whether to pause, continue, or correct based on voice input
@MainActor
struct VoiceAwareScrollController {
    
    private(set) var scrollEngine = ContinuousScrollEngine()  // Expose for metrics
    private var voiceTracker: TeleprompterScrollTracker
    
    var currentLineIndex: Int {
        scrollEngine.currentLineIndex
    }
    
    var currentIndex: Int {
        scrollEngine.currentLineIndex
    }
    
    var voiceConfidence: Double {
        scrollEngine.voiceConfidence
    }
    
    var isScrolling: Bool {
        scrollEngine.isScrolling
    }
    
    init(lines: [TeleprompterScrollTracker.Line]) {
        self.voiceTracker = TeleprompterScrollTracker(lines: lines)
        self.scrollEngine.configure(lines: lines)
    }
    
    mutating func start() {
        scrollEngine.start()
    }
    
    mutating func stop() {
        scrollEngine.stop()
    }
    
    mutating func reset(to index: Int) {
        voiceTracker.reset(to: index)
        scrollEngine.reset(to: index)
    }
    
    mutating func jumpToBlock(blockId: UUID) {
        voiceTracker.jumpToBlock(blockId: blockId)
        scrollEngine.jumpToBlock(blockId: blockId)
    }
    
    mutating func jumpToPrevious() {
        let newIndex = max(0, scrollEngine.currentLineIndex - 1)
        reset(to: newIndex)
    }
    
    mutating func jumpToNext() {
        let newIndex = min(voiceTracker.lines.count - 1, scrollEngine.currentLineIndex + 1)
        reset(to: newIndex)
    }
    
    /// Main integration point: feed transcript to voice tracker, which feeds scroll engine
    mutating func ingestTranscript(_ transcript: String) {
        guard !transcript.isEmpty else {
            scrollEngine.signalNoVoiceActivity()
            return
        }
        
        // Use voice tracker to find where we are in the script
        _ = voiceTracker.ingestTranscript(transcript)
        
        let voiceIndex = voiceTracker.currentIndex
        let voiceConf = voiceTracker.currentConfidence
        
        // Feed to scroll engine (which decides whether to pause, continue, or correct)
        _ = scrollEngine.ingestVoiceMatch(lineIndex: voiceIndex, confidence: voiceConf)
    }
    
    var lines: [TeleprompterScrollTracker.Line] {
        voiceTracker.lines
    }
}
