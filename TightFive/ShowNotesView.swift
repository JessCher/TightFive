import SwiftUI
import SwiftData
import AVFoundation
import UIKit
import Combine

/// Show Notes - Performance review interface with audio playback.
///
/// **Bug Fixes Applied:**
/// - Play button now works correctly (proper toggle logic)
/// - Deletion no longer crashes (proper cleanup, state clearing, timing)
struct ShowNotesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<Performance> { !$0.isDeleted },
        sort: \Performance.createdAt,
        order: .reverse
    ) private var performances: [Performance]
    
    @State private var selectedPerformance: Performance?
    @State private var showStorageInfo = false
    @State private var showCreateNote = false
    
    @State private var isSelecting = false
    @State private var selectedIDs: Set<UUID> = []
    
    var body: some View {
        Group {
                if performances.isEmpty {
                    emptyState
                } else {
                    performanceList
                }
            }
            .navigationTitle("Show Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    TFWordmarkTitle(title: "Show Notes", size: 22)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    if isSelecting && !selectedIDs.isEmpty {
                    } else if !isSelecting {
                        Button {
                            showCreateNote = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(TFTheme.yellow)
                        }
                    }
                }
            }
            .tfBackground()
            .sheet(item: $selectedPerformance) { performance in
                PerformanceDetailView(performance: performance) {
                    // Clear selection BEFORE dismissal completes
                    selectedPerformance = nil
                }
            }
            .sheet(isPresented: $showStorageInfo) {
                StorageInfoView()
            }
            .sheet(isPresented: $showCreateNote) {
                CreateShowNoteView()
            }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform")
                .font(.system(size: 56))
                .foregroundStyle(TFTheme.text.opacity(0.3))
            
            Text("No performances yet")
                .appFont(.title2, weight: .semibold)
                .foregroundStyle(TFTheme.text)
            
            Text("Record a performance in Stage Mode\nand it will appear here.")
                .appFont(.subheadline)
                .foregroundStyle(TFTheme.text.opacity(0.6))
                .multilineTextAlignment(.center)
        }
    }
    
    private var performanceList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // MARK: - Performances List
                ForEach(performances) { performance in
                    PerformanceRowView(
                        performance: performance,
                        isSelected: selectedIDs.contains(performance.id),
                        isSelecting: isSelecting
                    ) {
                        if isSelecting {
                            toggleSelection(performance)
                        } else {
                            selectedPerformance = performance
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
    }
    
    private func toggleSelection(_ performance: Performance) {
        if selectedIDs.contains(performance.id) {
            selectedIDs.remove(performance.id)
        } else {
            selectedIDs.insert(performance.id)
        }
    }
    
    private func deleteSelectedPerformances() {
        // Stop and clear selection before deletion
        let ids = selectedIDs
        selectedIDs.removeAll()
        isSelecting = false

        // Soft delete performances (moves to trashcan)
        for perf in performances where ids.contains(perf.id) {
            perf.softDelete(context: modelContext)
        }
        // Save after deletion completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            try? modelContext.save()
        }
    }
}

// MARK: - Performance Row

private struct PerformanceRowView: View {
    let performance: Performance
    let isSelected: Bool
    let isSelecting: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Spacer()
                
                VStack(alignment: .center, spacing: 4) {
                    Text(performance.displayTitle)
                        .appFont(.headline)
                        .foregroundStyle(TFTheme.text)
                        .lineLimit(1)
                        .multilineTextAlignment(.center)
                    
                    HStack(spacing: 8) {
                        Text(performance.formattedDate)
                            .appFont(.caption)
                            .foregroundStyle(TFTheme.text.opacity(0.5))
                        
                        if !performance.city.isEmpty {
                            Text(performance.city)
                                .appFont(.caption)
                                .foregroundStyle(TFTheme.text.opacity(0.5))
                                .lineLimit(1)
                        } else if !performance.venue.isEmpty {
                            Text(performance.venue)
                                .appFont(.caption)
                                .foregroundStyle(TFTheme.text.opacity(0.5))
                                .lineLimit(1)
                        }
                    }
                    
                    HStack(spacing: 12) {
                        Label(performance.formattedDuration, systemImage: "clock")
                            .appFont(.caption)
                            .foregroundStyle(TFTheme.text.opacity(0.5))
                        
                        if performance.calculatedRating > 0 || performance.rating > 0 {
                            VStack(spacing: 2) {
                                // Show calculated rating if available
                                if performance.calculatedRating > 0 {
                                    HStack(spacing: 2) {
                                        Image(systemName: "chart.bar.fill")
                                            .appFont(.caption2)
                                            .foregroundStyle(TFTheme.yellow.opacity(0.6))
                                        ForEach(1...5, id: \.self) { index in
                                            Image(systemName: index <= performance.calculatedRating ? "star.fill" : "star")
                                                .appFont(.caption2)
                                                .foregroundStyle(index <= performance.calculatedRating ? TFTheme.yellow : .white.opacity(0.3))
                                        }
                                    }
                                }
                                
                                // Show manual rating if available
                                if performance.rating > 0 {
                                    HStack(spacing: 2) {
                                        Image(systemName: "heart.fill")
                                            .appFont(.caption2)
                                            .foregroundStyle(TFTheme.yellow.opacity(0.6))
                                        ForEach(1...5, id: \.self) { index in
                                            Image(systemName: index <= performance.rating ? "star.fill" : "star")
                                                .appFont(.caption2)
                                                .foregroundStyle(index <= performance.rating ? TFTheme.yellow : .white.opacity(0.3))
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                
                Spacer()
                
                if isSelecting {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundStyle(isSelected ? TFTheme.yellow : .white.opacity(0.4))
                }
            }
            .padding(16)
            .tfDynamicCard(cornerRadius: 14)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Performance Detail View

struct PerformanceDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Bindable var performance: Performance
    var onDelete: (() -> Void)?
    
    @StateObject private var player = AudioPlayerManager()
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var isDownloadingFromiCloud = false
    @State private var hasDownloadedFromiCloud = false

    @State private var editableTitle: String = ""
    @State private var setlist: Setlist?
    @ObservedObject private var keyboard = TFKeyboardState.shared
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    performanceDetailsSection
                    
                    if performance.audioFileExists || performance.resolvedAudioURL != nil || hasDownloadedFromiCloud {
                        audioPlayerSection
                        setlistSection
                    } else if performance.needsICloudDownload {
                        iCloudDownloadSection
                    } else {
                        audioMissingSection
                    }
                    
                    ratingSection
                    notesSection
                    actionsSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .dismissKeyboardOnDrag()
            .dismissKeyboardOnTap()
            .navigationTitle("Performance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        player.stop()
                        dismiss()
                    }
                    .foregroundStyle(TFTheme.yellow)
                }
            }
            .tfBackground()
            .confirmationDialog("Delete Performance?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    deletePerformance()
                }
            } message: {
                Text("This will move the recording to the trashcan. You can restore it or delete it permanently later.")
            }
            .onAppear {
                editableTitle = performance.customTitle ?? ""
                loadSetlist()
            }
            .onDisappear {
                player.stop()
            }
        }
    }
    
    private func loadSetlist() {
        let setlistId = performance.setlistId
        let descriptor = FetchDescriptor<Setlist>(predicate: #Predicate { $0.id == setlistId })
        setlist = try? modelContext.fetch(descriptor).first
    }
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Text(performance.displayTitle)
                .appFont(.title2, weight: .bold)
                .foregroundStyle(TFTheme.text)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 16) {
                Label(performance.formattedDuration, systemImage: "clock")
                Label(performance.formattedFileSize, systemImage: "doc")
            }
            .appFont(.caption)
            .foregroundStyle(TFTheme.text.opacity(0.5))
        }
    }
    
    private var setlistSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Setlist")
                    .appFont(.headline)
                    .foregroundStyle(TFTheme.text)
                Spacer()
                Text("Tap cards to rate and add notes")
                    .appFont(.caption2)
                    .foregroundStyle(TFTheme.text.opacity(0.5))
            }
            
            if let setlist = setlist {
                FlippableScriptBlockList(
                    blocks: setlist.effectiveScriptBlocks,
                    assignments: setlist.assignments ?? [],
                    performance: performance
                )
                .frame(maxHeight: 450)
            } else {
                Text("Setlist not found")
                    .appFont(.subheadline)
                    .foregroundStyle(TFTheme.text.opacity(0.5))
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.black.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(16)
        .tfDynamicCard(cornerRadius: 14)
    }
    
    private var performanceDetailsSection: some View {
        VStack(spacing: 12) {
            // Custom Title
            VStack(alignment: .leading, spacing: 8) {
                Text("Show Title")
                    .appFont(.caption, weight: .semibold)
                    .foregroundStyle(TFTheme.text.opacity(0.6))
                    .textCase(.uppercase)
                    .kerning(0.5)
                
                TextField("Use setlist name", text: Binding(
                    get: { editableTitle },
                    set: { newValue in
                        editableTitle = newValue
                        performance.customTitle = newValue.isEmpty ? nil : newValue
                    }
                ))
                    .textFieldStyle(.plain)
                    .appFont(.body)
                    .foregroundStyle(TFTheme.text)
                    .padding(12)
                    .background(Color.black.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                
                if !editableTitle.isEmpty {
                    Text("Original: \(performance.setlistTitle)")
                        .appFont(.caption2)
                        .foregroundStyle(TFTheme.text.opacity(0.4))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .tfDynamicCard(cornerRadius: 14)
            
            // Date Performed
            VStack(alignment: .leading, spacing: 8) {
                Text("Date Performed")
                    .appFont(.caption, weight: .semibold)
                    .foregroundStyle(TFTheme.text.opacity(0.6))
                    .textCase(.uppercase)
                    .kerning(0.5)
                
                DatePicker("", selection: $performance.datePerformed, displayedComponents: [.date])
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .tint(TFTheme.yellow)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .tfDynamicCard(cornerRadius: 14)
            
            // City
            VStack(alignment: .leading, spacing: 8) {
                Text("City")
                    .appFont(.caption, weight: .semibold)
                    .foregroundStyle(TFTheme.text.opacity(0.6))
                    .textCase(.uppercase)
                    .kerning(0.5)
                
                TextField("Enter city", text: $performance.city)
                    .textFieldStyle(.plain)
                    .appFont(.body)
                    .foregroundStyle(TFTheme.text)
                    .padding(12)
                    .background(Color.black.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .tfDynamicCard(cornerRadius: 14)
            
            // Venue
            VStack(alignment: .leading, spacing: 8) {
                Text("Venue")
                    .appFont(.caption, weight: .semibold)
                    .foregroundStyle(TFTheme.text.opacity(0.6))
                    .textCase(.uppercase)
                    .kerning(0.5)
                
                TextField("Enter venue name", text: $performance.venue)
                    .textFieldStyle(.plain)
                    .appFont(.body)
                    .foregroundStyle(TFTheme.text)
                    .padding(12)
                    .background(Color.black.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .tfDynamicCard(cornerRadius: 14)
        }
    }
    
    private var audioPlayerSection: some View {
        VStack(spacing: 16) {
            // Waveform visualization
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.3))
                    .frame(height: 80)
                
                GeometryReader { geometry in
                    HStack(spacing: 2) {
                        ForEach(0..<30, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Double(index) / 30.0 < player.progress ? TFTheme.yellow : Color.white.opacity(0.3))
                                .frame(width: max(0, (geometry.size.width.isFinite ? geometry.size.width : 0) - 60) / 30)
                        }
                    }
                    .frame(height: 40)
                    .frame(maxHeight: .infinity)
                    .padding(.horizontal, 16)
                }
                .frame(height: 80)
            }
            
            // Time display
            HStack {
                Text(player.formattedCurrentTime)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(TFTheme.text.opacity(0.6))
                
                Spacer()
                
                Text(player.formattedDuration)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(TFTheme.text.opacity(0.6))
            }
            
            // Scrubber - FIX: Only seek, don't auto-play
            Slider(value: Binding(
                get: { player.progress },
                set: { newValue in
                    player.seek(to: newValue)
                }
            ), in: 0...1)
            .tint(TFTheme.yellow)
            
            // Playback controls - FIX: Proper play/pause toggle
            HStack(spacing: 32) {
                Button { player.skipBackward(seconds: 15) } label: {
                    Image(systemName: "gobackward.15")
                        .font(.system(size: 24))
                        .foregroundStyle(TFTheme.text)
                }
                
                // FIXED: Play button with proper toggle
                Button {
                    togglePlayback()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(TFTheme.yellow)
                }
                
                Button { player.skipForward(seconds: 15) } label: {
                    Image(systemName: "goforward.15")
                        .font(.system(size: 24))
                        .foregroundStyle(TFTheme.text)
                }
            }
        }
        .padding(20)
        .tfDynamicCard(cornerRadius: 16)
    }
    
    /// FIXED: Proper play/pause toggle – resolves from iCloud when local file is absent
    private func togglePlayback() {
        if player.isPlaying {
            player.pause()
        } else {
            if let url = performance.resolvedAudioURL ?? performance.audioURL {
                player.play(url: url)
            }
        }
    }
    
    private var audioMissingSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundStyle(.orange)

            Text("Recording Not Found")
                .appFont(.headline)
                .foregroundStyle(TFTheme.text)

            Text("The audio file may have been deleted.")
                .appFont(.caption)
                .foregroundStyle(TFTheme.text.opacity(0.6))
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .tfDynamicCard(cornerRadius: 16)
    }

    // MARK: - iCloud Download

    private var iCloudDownloadSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "icloud.and.arrow.down")
                .font(.system(size: 32))
                .foregroundStyle(TFTheme.yellow)

            Text("Recording in iCloud")
                .appFont(.headline)
                .foregroundStyle(TFTheme.text)

            Text("This recording was made on another device. Download it to listen here.")
                .appFont(.caption)
                .foregroundStyle(TFTheme.text.opacity(0.6))
                .multilineTextAlignment(.center)

            if isDownloadingFromiCloud {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: TFTheme.yellow))
                    .padding(.top, 8)
                Text("Downloading...")
                    .appFont(.caption)
                    .foregroundStyle(TFTheme.text.opacity(0.5))
            } else {
                Button {
                    downloadFromiCloud()
                } label: {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                        Text("Download Recording")
                    }
                    .appFont(.subheadline, weight: .semibold)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(TFTheme.yellow)
                    .clipShape(Capsule())
                }
                .padding(.top, 8)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .tfDynamicCard(cornerRadius: 16)
    }

    private func downloadFromiCloud() {
        isDownloadingFromiCloud = true
        Task {
            do {
                _ = try await iCloudAudioBackupManager.shared.downloadRecordingFromiCloud(
                    filename: performance.audioFilename
                )
                hasDownloadedFromiCloud = true
            } catch {
                // Download failed – fall through to show missing section on next render
            }
            isDownloadingFromiCloud = false
        }
    }
    
    private var ratingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Performance Rating")
                .appFont(.headline)
                .foregroundStyle(TFTheme.text)
            
            // "How it went" - Auto-calculated from bit ratings
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .appFont(.subheadline)
                        .foregroundStyle(TFTheme.yellow)
                    Text("How it went")
                        .appFont(.subheadline, weight: .semibold)
                        .foregroundStyle(TFTheme.text)
                    Spacer()
                    if performance.calculatedRating > 0 {
                        Text("(Auto-calculated)")
                            .appFont(.caption2)
                            .foregroundStyle(TFTheme.text.opacity(0.5))
                    }
                }
                
                HStack(spacing: 8) {
                    ForEach(1...5, id: \.self) { index in
                        Image(systemName: index <= performance.calculatedRating ? "star.fill" : "star")
                            .font(.system(size: 24))
                            .foregroundStyle(index <= performance.calculatedRating ? TFTheme.yellow : .white.opacity(0.3))
                    }
                    
                    if performance.calculatedRating == 0 {
                        Spacer()
                        Text("Rate bits above")
                            .appFont(.caption)
                            .foregroundStyle(TFTheme.text.opacity(0.5))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .background(Color.black.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            
            // "How it felt" - Manual overall rating
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "heart.fill")
                        .appFont(.subheadline)
                        .foregroundStyle(TFTheme.yellow)
                    Text("How it felt")
                        .appFont(.subheadline, weight: .semibold)
                        .foregroundStyle(TFTheme.text)
                    Spacer()
                    Text("(Your overall feeling)")
                        .appFont(.caption2)
                        .foregroundStyle(TFTheme.text.opacity(0.5))
                }
                
                HStack(spacing: 8) {
                    ForEach(1...5, id: \.self) { index in
                        Button {
                            performance.rating = (performance.rating == index) ? 0 : index
                        } label: {
                            Image(systemName: index <= performance.rating ? "star.fill" : "star")
                                .font(.system(size: 24))
                                .foregroundStyle(index <= performance.rating ? TFTheme.yellow : .white.opacity(0.3))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .background(Color.black.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(16)
        .tfDynamicCard(cornerRadius: 14)
    }
    
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Overall Show Notes")
                    .appFont(.headline)
                    .foregroundStyle(TFTheme.text)
                Spacer()
                Text("General thoughts about the performance")
                    .appFont(.caption2)
                    .foregroundStyle(TFTheme.text.opacity(0.5))
            }
            
            TextEditor(text: $performance.notes)
                .scrollContentBackground(.hidden)
                .appFont(.body)
                .foregroundStyle(TFTheme.text)
                .frame(minHeight: 120)
                .padding(12)
                .background(Color.black.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color("TFCardStroke").opacity(0.5), lineWidth: 1)
                )
        }
        .padding(16)
        .tfDynamicCard(cornerRadius: 14)
    }
    
    private var actionsSection: some View {
        VStack(spacing: 12) {
            if let url = performance.resolvedAudioURL ?? performance.audioURL, performance.isAudioAvailable {
                ShareLink(item: url) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share Recording")
                    }
                    .appFont(.headline)
                    .foregroundStyle(TFTheme.text)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color("TFCard"))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color("TFCardStroke").opacity(0.6), lineWidth: 1)
                    )
                }
            }
            
            Button { showDeleteConfirmation = true } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Delete Performance")
                }
                .appFont(.headline)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(isDeleting)
        }
    }
    
    /// FIXED: Proper deletion with crash prevention (now uses soft delete)
    private func deletePerformance() {
        // Prevent double-deletion
        guard !isDeleting else { return }
        isDeleting = true
        
        // 1. Stop playback immediately
        player.stop()
        
        // 2. Capture callback before any state changes
        let callback = onDelete
        
        // 3. Soft delete (move to trashcan)
        performance.softDelete(context: modelContext)
        
        // 4. Save after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            try? modelContext.save()
        }
        
        // 5. Dismiss sheet
        dismiss()
        
        // 6. Clear parent's selection after dismissal
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            callback?()
        }
    }
}

// MARK: - Audio Player Manager (FIXED)

@MainActor
final class AudioPlayerManager: NSObject, ObservableObject {
    @Published var isPlaying = false
    @Published var progress: Double = 0
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    
    private var player: AVAudioPlayer?
    private var timer: Timer?
    private var currentURL: URL?
    
    var formattedCurrentTime: String { formatTime(currentTime) }
    var formattedDuration: String { formatTime(duration) }
    
    override init() {
        super.init()
    }
    
    func play(url: URL) {
        // If same file and paused, just resume
        if currentURL == url, let existingPlayer = player {
            if !existingPlayer.isPlaying {
                existingPlayer.play()
                isPlaying = true
                startTimer()
            }
            return
        }
        
        // Stop any existing playback
        stop()
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.prepareToPlay()
            
            if player?.play() == true {
                currentURL = url
                duration = player?.duration ?? 0
                isPlaying = true
                startTimer()
            }
        } catch {
            print("Failed to play audio: \(error)")
        }
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
        stopTimer()
    }
    
    func stop() {
        player?.stop()
        player = nil
        currentURL = nil
        isPlaying = false
        progress = 0
        currentTime = 0
        duration = 0
        stopTimer()
        
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    
    func seek(to progress: Double) {
        guard let player = player else { return }
        let time = progress * player.duration
        player.currentTime = time
        currentTime = time
        self.progress = progress
        // Note: Do NOT auto-play on seek
    }
    
    func skipForward(seconds: TimeInterval) {
        guard let player = player else { return }
        let newTime = min(player.currentTime + seconds, player.duration)
        player.currentTime = newTime
        currentTime = newTime
        progress = player.duration > 0 ? newTime / player.duration : 0
    }
    
    func skipBackward(seconds: TimeInterval) {
        guard let player = player else { return }
        let newTime = max(player.currentTime - seconds, 0)
        player.currentTime = newTime
        currentTime = newTime
        progress = player.duration > 0 ? newTime / player.duration : 0
    }
    
    private func startTimer() {
        stopTimer()
        let timer = Timer(timeInterval: 0.1, target: self, selector: #selector(timerFired(_:)), userInfo: nil, repeats: true)
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    @objc private func timerFired(_ timer: Timer) {
        // We're on the main run loop; AudioPlayerManager is @MainActor
        updateProgress()
    }
    
    private func updateProgress() {
        guard let player = player else { return }
        currentTime = player.currentTime
        progress = player.duration > 0 ? player.currentTime / player.duration : 0
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    deinit {
        timer?.invalidate()
    }
}

extension AudioPlayerManager: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.progress = 0
            self.currentTime = 0
            self.stopTimer()
        }
    }
}

// MARK: - Storage Info View

struct StorageInfoView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Performance.createdAt, order: .reverse) private var performances: [Performance]
    
    @State private var showClearConfirmation = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 8)
                            .frame(width: 100, height: 100)
                        
                        Circle()
                            .trim(from: 0, to: storagePercentage)
                            .stroke(TFTheme.yellow, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .frame(width: 100, height: 100)
                            .rotationEffect(.degrees(-90))
                        
                        VStack(spacing: 2) {
                            Text(Performance.formattedTotalStorage)
                                .appFont(.headline)
                                .foregroundStyle(TFTheme.text)
                            Text("used")
                                .appFont(.caption)
                                .foregroundStyle(TFTheme.text.opacity(0.5))
                        }
                    }
                    
                    Text("\(performances.count) recordings")
                        .appFont(.subheadline)
                        .foregroundStyle(TFTheme.text.opacity(0.6))
                }
                .padding(.top, 20)
                
                if !performances.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("RECORDINGS")
                            .appFont(.caption, weight: .bold)
                            .foregroundStyle(TFTheme.text.opacity(0.5))
                            .kerning(1.5)
                        
                        ForEach(performances) { performance in
                            HStack {
                                Text(performance.setlistTitle)
                                    .appFont(.subheadline)
                                    .foregroundStyle(TFTheme.text)
                                    .lineLimit(1)

                                Spacer()

                                Text(performance.formattedFileSize)
                                    .appFont(.caption)
                                    .foregroundStyle(TFTheme.text.opacity(0.5))

                                if let url = performance.resolvedAudioURL ?? performance.audioURL, performance.isAudioAvailable {
                                    ShareLink(item: url) {
                                        Image(systemName: "square.and.arrow.up")
                                            .font(.system(size: 14))
                                            .foregroundStyle(TFTheme.yellow)
                                    }
                                }
                            }
                            .padding(.vertical, 8)

                            if performance.id != performances.last?.id {
                                Divider().opacity(0.2)
                            }
                        }
                    }
                    .padding(16)
                    .tfDynamicCard(cornerRadius: 14)
                    .padding(.horizontal, 16)
                }
                
                Spacer()
                
                if !performances.isEmpty {
                    Button { showClearConfirmation = true } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Clear All Recordings")
                        }
                        .appFont(.headline)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Recording Storage")
            .navigationBarTitleDisplayMode(.inline)
            .tfBackground()
            .confirmationDialog("Clear All Recordings?", isPresented: $showClearConfirmation, titleVisibility: .visible) {
                Button("Clear All", role: .destructive) {
                    clearAllRecordings()
                }
            } message: {
                Text("This will delete all \(performances.count) recordings.")
            }
        }
    }
    
    private var storagePercentage: Double {
        let used = Performance.totalStorageUsed
        let max: Int64 = 500_000_000
        return min(Double(used) / Double(max), 1.0)
    }
    
    private func clearAllRecordings() {
        for performance in performances {
            performance.deleteAudioFile()
            modelContext.delete(performance)
        }
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    ShowNotesView()
}

// MARK: - Create Show Note View
struct CreateShowNoteView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Setlist> { $0.isDraft == false }, sort: \Setlist.updatedAt, order: .reverse) private var finishedSetlists: [Setlist]
    
    @State private var selectedSetlist: Setlist?
    @State private var datePerformed = Date()
    @State private var city = ""
    @State private var venue = ""
    @State private var showAudioPicker = false
    @State private var selectedAudioURL: URL?
    @State private var isImporting = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Setlist Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Setlist")
                            .appFont(.headline)
                            .foregroundStyle(TFTheme.text)
                        
                        if finishedSetlists.isEmpty {
                            Text("No finished setlists available")
                                .appFont(.subheadline)
                                .foregroundStyle(TFTheme.text.opacity(0.5))
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.white.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            Menu {
                                ForEach(finishedSetlists) { setlist in
                                    Button(setlist.title) {
                                        selectedSetlist = setlist
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(selectedSetlist?.title ?? "Select a setlist")
                                        .foregroundStyle(selectedSetlist == nil ? .white.opacity(0.5) : .white)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .appFont(.caption)
                                        .foregroundStyle(TFTheme.text.opacity(0.5))
                                }
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                    .padding(16)
                    .tfDynamicCard(cornerRadius: 14)
                    
                    // Audio File
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Audio Recording")
                            .appFont(.headline)
                            .foregroundStyle(TFTheme.text)
                        
                        Button {
                            showAudioPicker = true
                        } label: {
                            HStack {
                                Image(systemName: selectedAudioURL == nil ? "music.note" : "checkmark.circle.fill")
                                    .foregroundStyle(selectedAudioURL == nil ? .white.opacity(0.5) : TFTheme.yellow)
                                
                                Text(selectedAudioURL?.lastPathComponent ?? "Select audio file")
                                    .foregroundStyle(selectedAudioURL == nil ? .white.opacity(0.5) : .white)
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                Image(systemName: "folder")
                                    .appFont(.caption)
                                    .foregroundStyle(TFTheme.text.opacity(0.5))
                            }
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(16)
                    .tfDynamicCard(cornerRadius: 14)
                    
                    // Date Performed
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Date Performed")
                            .appFont(.headline)
                            .foregroundStyle(TFTheme.text)
                        
                        DatePicker("", selection: $datePerformed, displayedComponents: [.date])
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .tint(TFTheme.yellow)
                    }
                    .padding(16)
                    .tfDynamicCard(cornerRadius: 14)
                    
                    // City
                    VStack(alignment: .leading, spacing: 12) {
                        Text("City")
                            .appFont(.headline)
                            .foregroundStyle(TFTheme.text)
                        
                        TextField("Enter city", text: $city)
                            .textFieldStyle(.plain)
                            .appFont(.body)
                            .foregroundStyle(TFTheme.text)
                            .padding(12)
                            .background(Color.black.opacity(0.3))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(16)
                    .tfDynamicCard(cornerRadius: 14)
                    
                    // Venue
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Venue")
                            .appFont(.headline)
                            .foregroundStyle(TFTheme.text)
                        
                        TextField("Enter venue name", text: $venue)
                            .textFieldStyle(.plain)
                            .appFont(.body)
                            .foregroundStyle(TFTheme.text)
                            .padding(12)
                            .background(Color.black.opacity(0.3))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(16)
                    .tfDynamicCard(cornerRadius: 14)
                    
                    if let errorMessage {
                        Text(errorMessage)
                            .appFont(.caption)
                            .foregroundStyle(.red)
                            .padding()
                    }
                    
                    // Create Button
                    Button {
                        createShowNote()
                    } label: {
                        if isImporting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .black))
                        } else {
                            Text("Create Show Note")
                                .appFont(.headline)
                                .foregroundStyle(.black)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(canCreate ? TFTheme.yellow : Color.gray)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .disabled(!canCreate || isImporting)
                    .padding(.horizontal, 16)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .navigationTitle("New Show Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(TFTheme.yellow)
                }
            }
            .tfBackground()
            .fileImporter(
                isPresented: $showAudioPicker,
                allowedContentTypes: [.audio],
                allowsMultipleSelection: false
            ) { result in
                handleAudioSelection(result)
            }
        }
    }
    
    private var canCreate: Bool {
        selectedSetlist != nil && selectedAudioURL != nil
    }
    
    private func handleAudioSelection(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            
            // Start accessing security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "Cannot access the selected file"
                return
            }
            
            selectedAudioURL = url
            errorMessage = nil
            
            // Stop accessing after storing
            url.stopAccessingSecurityScopedResource()
        } catch {
            errorMessage = "Failed to select audio file: \(error.localizedDescription)"
        }
    }
    
    private func createShowNote() {
        guard let setlist = selectedSetlist,
              let sourceURL = selectedAudioURL else { return }
        
        isImporting = true
        errorMessage = nil
        
        Task {
            // Start accessing security-scoped resource
            guard sourceURL.startAccessingSecurityScopedResource() else {
                await MainActor.run {
                    errorMessage = "Cannot access the audio file"
                    isImporting = false
                }
                return
            }
            
            defer {
                sourceURL.stopAccessingSecurityScopedResource()
            }
            
            do {
                // Generate filename and destination
                let filename = Performance.generateFilename(for: setlist.title)
                let destination = Performance.recordingsDirectory.appendingPathComponent(filename)
                
                // Copy the file
                try FileManager.default.copyItem(at: sourceURL, to: destination)
                
                // Get file attributes
                let attributes = try FileManager.default.attributesOfItem(atPath: destination.path)
                let fileSize = attributes[.size] as? Int64 ?? 0
                
                // Get audio duration using modern async API
                let asset = AVURLAsset(url: destination)
                let duration = try await asset.load(.duration).seconds
                
                // Create performance
                let performance = Performance(
                    setlistId: setlist.id,
                    setlistTitle: setlist.title,
                    datePerformed: datePerformed,
                    city: city,
                    venue: venue,
                    audioFilename: filename,
                    duration: duration,
                    fileSize: fileSize
                )
                
                await MainActor.run {
                    modelContext.insert(performance)
                    try? modelContext.save()
                    
                    isImporting = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to import audio: \(error.localizedDescription)"
                    isImporting = false
                }
            }
        }
    }
}
