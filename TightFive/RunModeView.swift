import SwiftUI
import SwiftData

/// Run Through Mode - A focused practice view for running through the performance script.
///
/// **Architecture:**
/// - Displays the Performance Script (blended freeform + bits)
/// - Does NOT display Notes tab content
/// - Does NOT display bit titles (just content)
/// - Timer overlay for practice timing
/// - Minimal UI for distraction-free practice
struct RunModeView: View {
    @Environment(\.dismiss) private var dismiss
    
    let setlist: Setlist
    var onDismiss: (() -> Void)?
    
    @State private var elapsedTime: TimeInterval = 0
    @State private var isTimerRunning = true
    @State private var timer: Timer?
    
    private func handleDismiss() {
        stopTimer()
        if let onDismiss = onDismiss {
            onDismiss()
        } else {
            dismiss()
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                if !setlist.hasScriptContent {
                    emptyState
                } else {
                    VStack(spacing: 0) {
                        topBar(geometry: geometry)
                        scriptContent
                    }
                }
            }
        }
        .statusBarHidden(true)
        .navigationBarHidden(true)
        .onAppear { startTimer() }
        .onDisappear { stopTimer() }
    }
    
    // MARK: - Top Bar
    
    private func topBar(geometry: GeometryProxy) -> some View {
        HStack {
            Button { handleDismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
            
            Spacer()
            timerDisplay
            Spacer()
            
            Color.clear.frame(width: 36, height: 36)
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
    
    // MARK: - Timer
    
    private var timerDisplay: some View {
        Button { toggleTimer() } label: {
            HStack(spacing: 10) {
                Image(systemName: isTimerRunning ? "pause.fill" : "play.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isTimerRunning ? TFTheme.yellow : .white.opacity(0.5))
                
                Text(formatTime(elapsedTime))
                    .font(.system(size: 32, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white)
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
        RunLoop.main.add(timer!, forMode: .common)
    }
    
    private func stopTimer() {
        isTimerRunning = false
        timer?.invalidate()
        timer = nil
    }
    
    private func toggleTimer() {
        if isTimerRunning { stopTimer() }
        else { startTimer() }
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
                
                // Display script content block by block - CONTENT ONLY, NO TITLES
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
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(.white.opacity(0.9))
                .lineSpacing(10)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    private func blockContentText(_ block: ScriptBlock) -> String {
        switch block {
        case .freeform(_, let rtfData):
            return NSAttributedString.fromRTF(rtfData)?.string ?? ""
        case .bit(_, let assignmentId):
            // Return ONLY the content, NOT the title
            guard let assignment = setlist.assignments.first(where: { $0.id == assignmentId }) else {
                return ""
            }
            return assignment.plainText
        }
    }
    
    // MARK: - Empty State
    
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
            
            Button("Go Back") { handleDismiss() }
                .font(.headline)
                .foregroundStyle(.black)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(TFTheme.yellow)
                .clipShape(Capsule())
        }
    }
}

// MARK: - Run Mode Launcher

struct RunModeLauncherView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Setlist> { $0.isDraft == false }, sort: \Setlist.updatedAt, order: .reverse) private var finishedSetlists: [Setlist]
    @Query(filter: #Predicate<Setlist> { $0.isDraft == true }, sort: \Setlist.updatedAt, order: .reverse) private var draftSetlists: [Setlist]
    
    @State private var selectedSetlist: Setlist?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Image(systemName: "timer")
                            .font(.system(size: 48))
                            .foregroundStyle(TFTheme.yellow)
                        
                        Text("Run Through")
                            .font(.title.weight(.bold))
                            .foregroundStyle(.white)
                        
                        Text("Practice your set with a timer")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 10)
                    
                    if !finishedSetlists.isEmpty {
                        setlistSection(title: "Stage Ready", setlists: finishedSetlists, icon: "checkmark.seal.fill")
                    }
                    
                    if !draftSetlists.isEmpty {
                        setlistSection(title: "In Progress", setlists: draftSetlists, icon: "hammer.fill")
                    }
                    
                    if finishedSetlists.isEmpty && draftSetlists.isEmpty {
                        emptyState
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
            .navigationTitle("Run Through")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    TFWordmarkTitle(title: "Run Through", size: 22)
                }
            }
            .tfBackground()
            .fullScreenCover(item: $selectedSetlist) { setlist in
                RunModeView(setlist: setlist) { selectedSetlist = nil }
            }
        }
    }
    
    private func setlistSection(title: String, setlists: [Setlist], icon: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(TFTheme.yellow)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            .padding(.leading, 4)
            
            ForEach(setlists) { setlist in
                RunModeSetlistRow(setlist: setlist) { selectedSetlist = setlist }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 14) {
            Text("No setlists yet")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
            Text("Create a setlist and add some content.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 40)
    }
}

private struct RunModeSetlistRow: View {
    let setlist: Setlist
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Image(systemName: setlist.hasScriptContent ? "doc.text.fill" : "doc.text")
                    .font(.system(size: 22))
                    .foregroundStyle(setlist.hasScriptContent ? TFTheme.yellow : .white.opacity(0.4))
                    .frame(width: 44, height: 44)
                    .background(Color("TFCard"))
                    .clipShape(Circle())
                    .overlay(
                        Circle().strokeBorder(
                            setlist.hasScriptContent ? TFTheme.yellow.opacity(0.5) : Color("TFCardStroke").opacity(0.5),
                            lineWidth: 1
                        )
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(setlist.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    HStack(spacing: 8) {
                        Text(setlist.hasScriptContent ? "Has script" : "No script yet")
                            .font(.caption)
                            .foregroundStyle(setlist.hasScriptContent ? TFTheme.yellow.opacity(0.8) : .white.opacity(0.4))
                        
                        if setlist.bitCount > 0 {
                            Text("\(setlist.bitCount) bits")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "play.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(setlist.hasScriptContent ? TFTheme.yellow : .white.opacity(0.3))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color("TFCard"))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color("TFCardStroke").opacity(0.6), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .opacity(setlist.hasScriptContent ? 1.0 : 0.6)
    }
}

#Preview {
    RunModeLauncherView()
}
