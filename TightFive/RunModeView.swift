import SwiftUI
import SwiftData
import UIKit

/// Run Through Mode - A focused practice view for running through the performance script.
///
/// Now includes a Traditional Teleprompter mode:
/// - Toggle between Script and Teleprompter
/// - Auto-scroll through a centered, static context window
/// - Adjustable scroll speed + font size
struct RunModeView: View {
    @Environment(\.dismiss) private var dismiss

    let setlist: Setlist
    var onDismiss: (() -> Void)?

    // Timer
    @State private var elapsedTime: TimeInterval = 0
    @State private var isTimerRunning = false
    @State private var timer: Timer?

    // Reading modes
    enum ReadingMode: String, CaseIterable, Identifiable {
        case script = "Script"
        case teleprompter = "Teleprompter"
        case rehearsal = "Rehearsal"
        var id: String { rawValue }
    }

    @State private var readingMode: ReadingMode = .script
    @State private var isTeleprompterSettingsPresented = false
    @State private var isRunModeSettingsPresented = false

    // Teleprompter state synced with settings
    @State private var teleprompterFontSize: CGFloat = 34
    @State private var teleprompterSpeed: CGFloat = 40
    @State private var teleprompterWindowHeight: CGFloat = 180
    @State private var isTeleprompterPlaying: Bool = false
    @State private var teleprompterResetCounter: Int = 0

    @ObservedObject private var settings = RunModeSettingsStore.shared

    private func handleDismiss() {
        stopTimer()
        if let onDismiss {
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

                        switch readingMode {
                        case .script:
                            scriptContent
                        case .teleprompter:
                            teleprompterContent(contextWindowHeight: teleprompterWindowHeight)
                        case .rehearsal:
                            StageRehearsalView(setlist: setlist)
                        }
                    }
                }
            }
        }
        .statusBarHidden(true)
        .navigationBarHidden(true)
        .onAppear {
            // Keep screen awake during Run Mode
            UIApplication.shared.isIdleTimerDisabled = true
            
            // Initialize from settings on appear - these are the defaults
            teleprompterFontSize = CGFloat(settings.defaultFontSize)
            teleprompterSpeed = CGFloat(settings.defaultSpeed)
            readingMode = (settings.defaultMode == .script) ? .script : .teleprompter
            
            // Auto-start timer if enabled
            if settings.autoStartTimer && !isTimerRunning {
                startTimer()
            }
            
            // Auto-start teleprompter if enabled and in teleprompter mode
            if settings.autoStartTeleprompter && readingMode == .teleprompter {
                isTeleprompterPlaying = true
            }
        }
        .onDisappear { 
            // Re-enable screen dimming when exiting Run Mode
            UIApplication.shared.isIdleTimerDisabled = false
            
            stopTimer()
            // Don't save session adjustments - let settings page control defaults
        }
        .sheet(isPresented: $isTeleprompterSettingsPresented) {
            teleprompterSettingsSheet
        }
        .fullScreenCover(isPresented: $isRunModeSettingsPresented) {
            RunModeSettingsView()
        }
        .onChange(of: settings.defaultFontSize) { _, newValue in
            // When settings change, update the current session immediately
            teleprompterFontSize = CGFloat(newValue)
        }
        .onChange(of: settings.defaultSpeed) { _, newValue in
            // When settings change, update the current session immediately
            teleprompterSpeed = CGFloat(newValue)
        }
        .environment(\._teleprompterFontColor, settings.teleprompterFontColor.color)
    }

    // MARK: - Top Bar

    private func topBar(geometry: GeometryProxy) -> some View {
        VStack(spacing: 12) {
            ZStack {
                // Left side - Close button
                HStack {
                    Button { handleDismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(TFTheme.text.opacity(0.7))
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                
                // Center - Timer and Reset
                HStack(spacing: 10) {
                    timerDisplay
                    Button {
                        resetRunMode()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(TFTheme.text.opacity(0.9))
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
                .frame(maxWidth: .infinity)
                
                // Right side - Settings button
                HStack {
                    Spacer()
                    Button {
                        isRunModeSettingsPresented = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(TFTheme.text.opacity(0.85))
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, geometry.safeAreaInsets.top + 8)

            // Mode toggle
            Picker("", selection: $readingMode) {
                ForEach(ReadingMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
        }
        .background(
            LinearGradient(
                colors: [Color.black, Color.black.opacity(0.86), Color.clear],
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
                    .foregroundStyle(isTimerRunning ? RunModeSettingsStore.shared.timerColor.color : .white.opacity(0.5))

                Text(formatTime(elapsedTime))
                    .font(.system(size: CGFloat(RunModeSettingsStore.shared.timerSize), weight: .medium, design: .monospaced))
                    .foregroundStyle(isTimerRunning ? RunModeSettingsStore.shared.timerColor.color : .white)
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
            // If the timer is paused via the pill, pause teleprompter too
            isTeleprompterPlaying = false
        } else {
            startTimer()
            // If the timer is started via the pill, start teleprompter too
            isTeleprompterPlaying = true
        }
    }

    private func resetRunMode() {
        // Pause both systems
        if isTimerRunning { stopTimer() }
        isTimerRunning = false
        isTeleprompterPlaying = false

        // Reset the timer
        elapsedTime = 0

        // Signal teleprompter to jump to the start
        teleprompterResetCounter &+= 1
    }

    // MARK: - Script Content (existing behavior)

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
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(RunModeSettingsStore.shared.scriptFontColor.color.opacity(0.9))
                .lineSpacing(10)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Teleprompter Content

    private func teleprompterContent(contextWindowHeight: CGFloat) -> some View {
        GeometryReader { geo in
            let midY = geo.size.height / 2
            let topClear = max(0, midY - contextWindowHeight / 2)

            ZStack {
                TeleprompterTextView(
                    text: teleprompterFullText,
                    fontSize: teleprompterFontSize,
                    lineSpacing: 14,
                    speedPointsPerSecond: teleprompterSpeed,
                    isPlaying: isTeleprompterPlaying,
                    startInsetTop: topClear,
                    resetSignal: teleprompterResetCounter
                )
                .ignoresSafeArea(edges: .bottom)

                // Context window overlay: dim outside center band, keep a clear "read zone"
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
            let midY = fullH / 2-40
            let topDimH = max(0, midY - height / 2)
            let bottomDimH = max(0, fullH - (midY + height / 2))

            ZStack {
                // Dim regions (guaranteed full coverage) - made darker
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

    // MARK: - Shared Block Text

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

                        Slider(value: $teleprompterFontSize, in: 22...54, step: 1)
                        Text("\(Int(teleprompterFontSize)) pt")
                            .appFont(.caption)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Scroll Speed")
                            .appFont(.headline)

                        Slider(value: $teleprompterSpeed, in: 0...140, step: 1)
                        Text("\(Int(teleprompterSpeed)) pts/sec")
                            .appFont(.caption)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Context Window Height")
                            .appFont(.headline)

                        Slider(value: $teleprompterWindowHeight, in: 120...280, step: 1)
                        Text("\(Int(teleprompterWindowHeight)) pt tall")
                            .appFont(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Text("Tip: Use the timer Play/Pause to start or stop scrolling hands-free.")
                        .appFont(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Teleprompter Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { isTeleprompterSettingsPresented = false }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 56))
                .foregroundStyle(TFTheme.text.opacity(0.3))

            Text("No script content")
                .appFont(.title2, weight: .semibold)
                .foregroundStyle(TFTheme.text)

            Text("Add content to your setlist script first.")
                .appFont(.subheadline)
                .foregroundStyle(TFTheme.text.opacity(0.6))

            Button("Go Back") { handleDismiss() }
                .appFont(.headline)
                .foregroundStyle(.black)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(TFTheme.yellow)
                .clipShape(Capsule())
        }
    }
}

// MARK: - Run Mode Launcher (unchanged)

struct RunModeLauncherView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Setlist> { $0.isDraft == false }, sort: \Setlist.updatedAt, order: .reverse) private var finishedSetlists: [Setlist]
    @Query(filter: #Predicate<Setlist> { $0.isDraft == true }, sort: \Setlist.updatedAt, order: .reverse) private var draftSetlists: [Setlist]

    @State private var selectedSetlist: Setlist?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
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
                .padding(.top, 12)
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
                    .appFont(.headline)
                    .foregroundStyle(TFTheme.text)
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
                .appFont(.title3, weight: .semibold)
                .foregroundStyle(TFTheme.text)
            Text("Create a setlist and add some content.")
                .appFont(.subheadline)
                .foregroundStyle(TFTheme.text.opacity(0.6))
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
                // MARK: - HIDDEN: Icons removed to match other tiles
                // Image(systemName: setlist.hasScriptContent ? "doc.text.fill" : "doc.text")
                //     .font(.system(size: 22))
                //     .foregroundStyle(setlist.hasScriptContent ? TFTheme.yellow : .white.opacity(0.4))
                //     .frame(width: 44, height: 44)
                //     .background(Color("TFCard"))
                //     .clipShape(Circle())
                //     .overlay(
                //         Circle().strokeBorder(
                //             setlist.hasScriptContent ? TFTheme.yellow.opacity(0.5) : Color("TFCardStroke").opacity(0.5),
                //             lineWidth: 1
                //         )
                //     )

                Spacer()

                VStack(alignment: .center, spacing: 4) {
                    Text(setlist.title)
                        .appFont(.headline)
                        .foregroundStyle(TFTheme.text)

                    HStack(spacing: 8) {
                        Text(setlist.hasScriptContent ? "Has script" : "No script yet")
                            .appFont(.caption)
                            .foregroundStyle(setlist.hasScriptContent ? TFTheme.yellow.opacity(0.8) : .white.opacity(0.4))

                        if setlist.bitCount > 0 {
                            Text("\(setlist.bitCount) bits")
                                .appFont(.caption)
                                .foregroundStyle(TFTheme.text.opacity(0.5))
                        }
                    }
                }

                Spacer()

                // MARK: - HIDDEN: Play icon removed to match other tiles
                // Image(systemName: "play.fill")
                //     .font(.system(size: 16))
                //     .foregroundStyle(setlist.hasScriptContent ? TFTheme.yellow : .white.opacity(0.3))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            .tfDynamicCard(cornerRadius: 20)
        }
        .buttonStyle(.plain)
        .opacity(setlist.hasScriptContent ? 1.0 : 0.6)
    }
}

#Preview {
    RunModeLauncherView()
}

