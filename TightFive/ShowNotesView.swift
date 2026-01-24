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
    @Query(sort: \Performance.createdAt, order: .reverse) private var performances: [Performance]
    
    @State private var selectedPerformance: Performance?
    @State private var showStorageInfo = false
    
    var body: some View {
        NavigationStack {
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
                    Button { showStorageInfo = true } label: {
                        Image(systemName: "internaldrive")
                            .foregroundStyle(.white.opacity(0.7))
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
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform")
                .font(.system(size: 56))
                .foregroundStyle(.white.opacity(0.3))
            
            Text("No performances yet")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
            
            Text("Record a performance in Stage Mode\nand it will appear here.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
    }
    
    private var performanceList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(performances) { performance in
                    PerformanceRowView(performance: performance) {
                        selectedPerformance = performance
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
    }
}

// MARK: - Performance Row

private struct PerformanceRowView: View {
    let performance: Performance
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(performance.isReviewed ? TFTheme.yellow.opacity(0.2) : Color.white.opacity(0.1))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: performance.isReviewed ? "checkmark.seal.fill" : "waveform")
                        .font(.system(size: 20))
                        .foregroundStyle(performance.isReviewed ? TFTheme.yellow : .white.opacity(0.6))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(performance.setlistTitle)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        Text(performance.formattedDate)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                        
                        if !performance.venue.isEmpty {
                            Text(performance.venue)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                                .lineLimit(1)
                        }
                    }
                    
                    HStack(spacing: 12) {
                        Label(performance.formattedDuration, systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                        
                        if performance.rating > 0 {
                            HStack(spacing: 2) {
                                ForEach(1...5, id: \.self) { index in
                                    Image(systemName: index <= performance.rating ? "star.fill" : "star")
                                        .font(.caption2)
                                        .foregroundStyle(index <= performance.rating ? TFTheme.yellow : .white.opacity(0.3))
                                }
                            }
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(16)
            .background(Color("TFCard"))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color("TFCardStroke").opacity(0.6), lineWidth: 1)
            )
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
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    
                    if performance.audioFileExists {
                        audioPlayerSection
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
                Text("This will delete the recording and cannot be undone.")
            }
            .onDisappear {
                player.stop()
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Text(performance.setlistTitle)
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 16) {
                Label(performance.formattedDate, systemImage: "calendar")
                
                if !performance.venue.isEmpty {
                    Label(performance.venue, systemImage: "mappin")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.6))
            
            HStack(spacing: 16) {
                Label(performance.formattedDuration, systemImage: "clock")
                Label(performance.formattedFileSize, systemImage: "doc")
            }
            .font(.caption)
            .foregroundStyle(.white.opacity(0.5))
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
                    .foregroundStyle(.white.opacity(0.6))
                
                Spacer()
                
                Text(player.formattedDuration)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.6))
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
                        .foregroundStyle(.white)
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
                        .foregroundStyle(.white)
                }
            }
        }
        .padding(20)
        .background(Color("TFCard"))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color("TFCardStroke").opacity(0.6), lineWidth: 1)
        )
    }
    
    /// FIXED: Proper play/pause toggle
    private func togglePlayback() {
        if player.isPlaying {
            player.pause()
        } else {
            if let url = performance.audioURL {
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
                .font(.headline)
                .foregroundStyle(.white)
            
            Text("The audio file may have been deleted.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color("TFCard"))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var ratingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Rating")
                .font(.headline)
                .foregroundStyle(.white)
            
            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { index in
                    Button {
                        performance.rating = (performance.rating == index) ? 0 : index
                    } label: {
                        Image(systemName: index <= performance.rating ? "star.fill" : "star")
                            .font(.system(size: 32))
                            .foregroundStyle(index <= performance.rating ? TFTheme.yellow : .white.opacity(0.3))
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .background(Color("TFCard"))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color("TFCardStroke").opacity(0.6), lineWidth: 1)
        )
    }
    
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notes")
                .font(.headline)
                .foregroundStyle(.white)
            
            TextEditor(text: $performance.notes)
                .scrollContentBackground(.hidden)
                .font(.body)
                .foregroundStyle(.white)
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
        .background(Color("TFCard"))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color("TFCardStroke").opacity(0.6), lineWidth: 1)
        )
    }
    
    private var actionsSection: some View {
        VStack(spacing: 12) {
            if performance.audioFileExists, let url = performance.audioURL {
                ShareLink(item: url) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share Recording")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
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
                .font(.headline)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(isDeleting)
        }
    }
    
    /// FIXED: Proper deletion with crash prevention
    private func deletePerformance() {
        // Prevent double-deletion
        guard !isDeleting else { return }
        isDeleting = true
        
        // 1. Stop playback immediately
        player.stop()
        
        // 2. Capture callback before any state changes
        let callback = onDelete
        
        // 3. Delete the audio file first
        performance.deleteAudioFile()
        
        // 4. Delete from context
        modelContext.delete(performance)
        
        // 5. Save immediately
        do {
            try modelContext.save()
        } catch {
            print("Failed to save after deletion: \(error)")
        }
        
        // 6. Dismiss sheet
        dismiss()
        
        // 7. Clear parent's selection after dismissal
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
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateProgress()
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
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
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text("used")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    
                    Text("\(performances.count) recordings")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.top, 20)
                
                if !performances.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("RECORDINGS")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white.opacity(0.5))
                            .kerning(1.5)
                        
                        ForEach(performances) { performance in
                            HStack {
                                Text(performance.setlistTitle)
                                    .font(.subheadline)
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                Text(performance.formattedFileSize)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            .padding(.vertical, 8)
                            
                            if performance.id != performances.last?.id {
                                Divider().opacity(0.2)
                            }
                        }
                    }
                    .padding(16)
                    .background(Color("TFCard"))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 16)
                }
                
                Spacer()
                
                if !performances.isEmpty {
                    Button { showClearConfirmation = true } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Clear All Recordings")
                        }
                        .font(.headline)
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
            .navigationTitle("Storage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(TFTheme.yellow)
                }
            }
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
