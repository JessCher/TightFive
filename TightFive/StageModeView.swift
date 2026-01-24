import SwiftUI
import SwiftData
import UIKit

/// Stage Mode - Live performance teleprompter with voice navigation and recording.
///
/// **Architecture:**
/// - Displays the full SCRIPT (blended freeform + bits) - CONTENT ONLY
/// - Does NOT display bit titles (harms glance readability)
/// - Does NOT display Notes tab content
/// - Voice recognition for anchor phrases
/// - Audio recording of performance
struct StageModeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let setlist: Setlist
    var venue: String = ""
    
    @StateObject private var recorder = PerformanceRecorder()
    @StateObject private var recognizer = StageAnchorRecognizer()
    
    @State private var currentBlockIndex = 0
    @State private var showExitConfirmation = false
    @State private var showSaveConfirmation = false
    @State private var isInitialized = false
    
    private var blocks: [ScriptBlock] {
        setlist.scriptBlocks
    }
    
    private var anchors: [StageAnchor] {
        setlist.stageAnchors.filter { $0.isEnabled && $0.isValid }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                if blocks.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 0) {
                        topBar(geometry: geometry)
                        contentArea
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
        .onAppear { startSession() }
        .onDisappear { cleanup() }
    }
    
    // MARK: - Top Bar
    
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
            
            if recorder.isRecording {
                recordingIndicator
            }
            
            Spacer()
            
            Text(recorder.formattedTime)
                .font(.system(size: 20, weight: .medium, design: .monospaced))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
        .padding(.horizontal, 20)
        .padding(.top, geometry.safeAreaInsets.top + 8)
        .padding(.bottom, 12)
        .background(
            LinearGradient(
                colors: [Color.black, Color.black.opacity(0.8), Color.clear],
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
            
            Text("REC")
                .font(.caption.weight(.bold))
                .foregroundStyle(.red)
            
            AudioLevelBar(level: recorder.audioLevel)
                .frame(width: 40, height: 16)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.6))
        .clipShape(Capsule())
    }
    
    // MARK: - Content Area
    
    private var contentArea: some View {
        TabView(selection: $currentBlockIndex) {
            ForEach(Array(blocks.enumerated()), id: \.element.id) { index, block in
                blockContentView(block: block, index: index)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .onChange(of: currentBlockIndex) { _, _ in
            hapticFeedback()
        }
    }
    
    private func blockContentView(block: ScriptBlock, index: Int) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("BLOCK \(index + 1) OF \(blocks.count)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(TFTheme.yellow)
                    .kerning(2)
                
                Rectangle()
                    .fill(TFTheme.yellow.opacity(0.5))
                    .frame(height: 2)
                    .frame(maxWidth: 100)
                
                // Content ONLY - NO BIT TITLES
                Text(blockContent(block))
                    .font(.system(size: 28, weight: .regular))
                    .foregroundStyle(.white.opacity(0.95))
                    .lineSpacing(12)
                    .fixedSize(horizontal: false, vertical: true)
                
                Spacer(minLength: 100)
            }
            .padding(.horizontal, 32)
            .padding(.top, 24)
        }
        .scrollIndicators(.hidden)
    }
    
    private func blockContent(_ block: ScriptBlock) -> String {
        switch block {
        case .freeform(_, let rtfData):
            return NSAttributedString.fromRTF(rtfData)?.string ?? ""
        case .bit(_, let assignmentId):
            guard let assignment = setlist.assignments.first(where: { $0.id == assignmentId }) else {
                return ""
            }
            // Return ONLY the content, NOT the title
            return assignment.plainText
        }
    }
    
    // MARK: - Bottom Bar
    
    private var bottomBar: some View {
        HStack(spacing: 24) {
            Button {
                if currentBlockIndex > 0 {
                    withAnimation { currentBlockIndex -= 1 }
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(currentBlockIndex > 0 ? .white : .white.opacity(0.3))
                    .frame(width: 56, height: 56)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
            .disabled(currentBlockIndex == 0)
            
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    ForEach(0..<min(blocks.count, 10), id: \.self) { index in
                        Circle()
                            .fill(index == currentBlockIndex ? TFTheme.yellow : Color.white.opacity(0.3))
                            .frame(width: index == currentBlockIndex ? 10 : 6, height: index == currentBlockIndex ? 10 : 6)
                    }
                    
                    if blocks.count > 10 {
                        Text("+\(blocks.count - 10)")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                
                if recognizer.isListening {
                    HStack(spacing: 4) {
                        Image(systemName: "waveform")
                            .font(.caption2)
                        Text("Listening")
                            .font(.caption2)
                    }
                    .foregroundStyle(.green)
                }
            }
            
            Button {
                if currentBlockIndex < blocks.count - 1 {
                    withAnimation { currentBlockIndex += 1 }
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(currentBlockIndex < blocks.count - 1 ? .white : .white.opacity(0.3))
                    .frame(width: 56, height: 56)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
            .disabled(currentBlockIndex >= blocks.count - 1)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 20)
        .background(
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.8), Color.black],
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
            
            VStack(spacing: 24) {
                Text("End Performance?")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                
                if recorder.isRecording {
                    Text("Recording will be saved: \(recorder.formattedTime)")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }
                
                HStack(spacing: 16) {
                    Button { showExitConfirmation = false } label: {
                        Text("Continue")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    Button {
                        showExitConfirmation = false
                        endSession()
                    } label: {
                        Text("End")
                            .font(.headline)
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(TFTheme.yellow)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding(24)
            .background(Color("TFCard"))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal, 40)
        }
    }
    
    private var saveConfirmationOverlay: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.green)
                
                Text("Performance Saved!")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                
                Text("Review it in Show Notes")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                
                Button { dismiss() } label: {
                    Text("Done")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(TFTheme.yellow)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(24)
            .background(Color("TFCard"))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal, 40)
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 56))
                .foregroundStyle(.white.opacity(0.3))
            
            Text("No script content")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
            
            Text("Add content to your setlist script first.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
            
            Button("Go Back") { dismiss() }
                .font(.headline)
                .foregroundStyle(.black)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(TFTheme.yellow)
                .clipShape(Capsule())
        }
    }
    
    // MARK: - Session Management
    
    private func startSession() {
        guard !isInitialized else { return }
        isInitialized = true
        
        Task {
            let filename = Performance.generateFilename(for: setlist.title)
            let success = await recorder.startRecording(filename: filename)
            if !success {
                print("Recording failed: \(recorder.error?.localizedDescription ?? "Unknown")")
            }
        }
        
        if !anchors.isEmpty {
            Task {
                recognizer.onAnchorDetected = { anchor, _ in
                    navigateToAnchor(anchor)
                }
                let success = await recognizer.startListening(for: anchors)
                if !success {
                    print("Recognition failed: \(recognizer.error?.localizedDescription ?? "Unknown")")
                }
            }
        }
    }
    
    private func endSession() {
        recognizer.stopListening()
        
        if let result = recorder.stopRecording() {
            let performance = Performance(
                setlistId: setlist.id,
                setlistTitle: setlist.title,
                venue: venue,
                audioFilename: result.url.lastPathComponent,
                duration: result.duration,
                fileSize: result.fileSize
            )
            modelContext.insert(performance)
            try? modelContext.save()
            showSaveConfirmation = true
        } else {
            dismiss()
        }
    }
    
    private func cleanup() {
        recognizer.stopListening()
        recorder.cancelRecording()
    }
    
    private func navigateToAnchor(_ anchor: StageAnchor) {
        // FIXED: Handle both bit and freeform block references
        let blockIndex: Int?
        
        switch anchor.blockReference {
        case .bit(let assignmentId):
            blockIndex = blocks.firstIndex { block in
                if case .bit(_, let blockAssignmentId) = block {
                    return blockAssignmentId == assignmentId
                }
                return false
            }
        case .freeform(let blockId):
            blockIndex = blocks.firstIndex { block in
                block.id == blockId
            }
        }
        
        if let index = blockIndex {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentBlockIndex = index
            }
            hapticFeedback()
            
            // CRITICAL: Clear detection state to allow recognizing the NEXT anchor
            recognizer.clearLastDetection()
        }
    }
    
    private func hapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}

// MARK: - Audio Level Bar

private struct AudioLevelBar: View {
    let level: Float
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.2))
                
                RoundedRectangle(cornerRadius: 2)
                    .fill(levelColor)
                    .frame(width: geometry.size.width * CGFloat(level))
            }
        }
    }
    
    private var levelColor: Color {
        if level > 0.8 { return .red }
        if level > 0.5 { return .yellow }
        return .green
    }
}

#Preview {
    let setlist = Setlist(title: "Friday Night Set", isDraft: false)
    return StageModeView(setlist: setlist)
}
