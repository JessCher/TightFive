import SwiftUI
import SwiftData

/// Run Mode - A focused performance view for running through setlist notes on stage.
///
/// Features:
/// - Large, readable text from notes
/// - Scrollable content
/// - Persistent timer bar at top
/// - Minimal UI to avoid distraction
struct RunModeView: View {
    @Environment(\.dismiss) private var dismiss
    
    let setlist: Setlist
    var onDismiss: (() -> Void)?  // Optional callback for launcher dismissal
    
    @State private var elapsedTime: TimeInterval = 0
    @State private var isTimerRunning: Bool = true
    @State private var timer: Timer?
    
    /// Extract plain text from notes RTF
    private var notesText: String {
        NSAttributedString.fromRTF(setlist.notesRTF)?.string ?? ""
    }
    
    /// Check if notes are empty
    private var hasNotes: Bool {
        !notesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// Handle dismissal - uses callback if provided, otherwise environment dismiss
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
                // Background
                Color.black.ignoresSafeArea()
                
                if !hasNotes {
                    emptyState
                } else {
                    VStack(spacing: 0) {
                        // Persistent top bar with timer
                        topBar(geometry: geometry)
                        
                        // Main content - scrollable notes
                        ScrollView {
                            VStack(alignment: .leading, spacing: 20) {
                                // Title
                                Text(setlist.title.uppercased())
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(TFTheme.yellow)
                                    .kerning(2)
                                
                                // Divider
                                Rectangle()
                                    .fill(TFTheme.yellow.opacity(0.5))
                                    .frame(height: 2)
                                    .frame(maxWidth: 100)
                                
                                // Notes content
                                Text(notesText)
                                    .font(.system(size: 22, weight: .regular))
                                    .foregroundStyle(.white.opacity(0.9))
                                    .lineSpacing(10)
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                Spacer(minLength: 100)
                            }
                            .padding(.horizontal, 28)
                            .padding(.top, 24)
                        }
                        .scrollIndicators(.hidden)
                    }
                }
            }
        }
        .statusBarHidden(true)
        .navigationBarHidden(true)
        .onAppear {
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
    }
    
    // MARK: - Top Bar (Always Visible)
    
    private func topBar(geometry: GeometryProxy) -> some View {
        HStack {
            // Close button
            Button {
                handleDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
            
            Spacer()
            
            // Timer display - large and prominent
            timerDisplay
            
            Spacer()
            
            // Placeholder for balance (same width as close button)
            Color.clear
                .frame(width: 36, height: 36)
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
    
    // MARK: - Timer Display
    
    private var timerDisplay: some View {
        Button {
            toggleTimer()
        } label: {
            HStack(spacing: 10) {
                // Play/Pause indicator
                Image(systemName: isTimerRunning ? "pause.fill" : "play.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isTimerRunning ? TFTheme.yellow : .white.opacity(0.5))
                
                // Time - large and readable
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
        // Use .common mode so timer continues during scroll
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
        if isTimerRunning {
            stopTimer()
        } else {
            startTimer()
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 56))
                .foregroundStyle(.white.opacity(0.3))
            
            Text("No notes in this set")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
            
            Text("Add some notes to your setlist first.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
            
            Button("Go Back") {
                handleDismiss()
            }
            .font(.headline)
            .foregroundStyle(.black)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(TFTheme.yellow)
            .clipShape(Capsule())
            .padding(.top, 8)
        }
    }
}

// MARK: - Run Mode Launcher

/// A view shown in the Run Mode tab that lets users select a setlist to run
struct RunModeLauncherView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Setlist> { $0.isDraft == false }, sort: \Setlist.updatedAt, order: .reverse) private var finishedSetlists: [Setlist]
    @Query(filter: #Predicate<Setlist> { $0.isDraft == true }, sort: \Setlist.updatedAt, order: .reverse) private var draftSetlists: [Setlist]
    
    @State private var selectedSetlist: Setlist?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "timer")
                            .font(.system(size: 48))
                            .foregroundStyle(TFTheme.yellow)
                        
                        Text("Run Mode")
                            .font(.title.weight(.bold))
                            .foregroundStyle(.white)
                        
                        Text("Select a setlist to perform")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 10)
                    
                    // Finished setlists (preferred)
                    if !finishedSetlists.isEmpty {
                        setlistSection(title: "Stage Ready", setlists: finishedSetlists, icon: "checkmark.seal.fill")
                    }
                    
                    // Draft setlists
                    if !draftSetlists.isEmpty {
                        setlistSection(title: "In Progress", setlists: draftSetlists, icon: "hammer.fill")
                    }
                    
                    // Empty state
                    if finishedSetlists.isEmpty && draftSetlists.isEmpty {
                        emptyState
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
            .navigationTitle("Run Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    TFWordmarkTitle(title: "Run Mode", size: 22)
                        .offset(x: -6)
                }
            }
            .tfBackground()
            // Use item-based fullScreenCover for reliable presentation/dismissal
            .fullScreenCover(item: $selectedSetlist) { setlist in
                RunModeView(setlist: setlist, onDismiss: {
                    selectedSetlist = nil
                })
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
                RunModeSetlistRow(setlist: setlist) {
                    selectedSetlist = setlist
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 14) {
            Text("No setlists yet")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
            
            Text("Create a setlist and add some notes to get started.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 40)
    }
}

// MARK: - Setlist Row for Run Mode

private struct RunModeSetlistRow: View {
    let setlist: Setlist
    let onTap: () -> Void
    
    /// Check if setlist has notes content
    private var hasNotes: Bool {
        let text = NSAttributedString.fromRTF(setlist.notesRTF)?.string ?? ""
        return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Notes indicator
                Image(systemName: hasNotes ? "doc.text.fill" : "doc.text")
                    .font(.system(size: 22))
                    .foregroundStyle(hasNotes ? TFTheme.yellow : .white.opacity(0.4))
                    .frame(width: 44, height: 44)
                    .background(Color("TFCard"))
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .strokeBorder(hasNotes ? TFTheme.yellow.opacity(0.5) : Color("TFCardStroke").opacity(0.5), lineWidth: 1)
                    )
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(setlist.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    HStack(spacing: 8) {
                        if hasNotes {
                            Text("Has notes")
                                .font(.caption)
                                .foregroundStyle(TFTheme.yellow.opacity(0.8))
                        } else {
                            Text("No notes yet")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        
                        if setlist.bitCount > 0 {
                            Text("•")
                                .foregroundStyle(.white.opacity(0.3))
                            Text("\(setlist.bitCount) bits")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                }
                
                Spacer()
                
                // Play indicator
                Image(systemName: "play.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(hasNotes ? TFTheme.yellow : .white.opacity(0.3))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color("TFCard"))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color("TFCardStroke").opacity(0.6), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .opacity(hasNotes ? 1.0 : 0.6)
    }
}

// MARK: - Preview

#Preview {
    RunModeLauncherView()
}
