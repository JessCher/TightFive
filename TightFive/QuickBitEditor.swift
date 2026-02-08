import SwiftUI
import Foundation
import SwiftData
import Combine
import UIKit // Needed for UIColor/UIFont

/// Quick Bit Editor - Fast bit capture with dictation support
/// Uses PlainTextEditor for text input with full undo/redo support
struct QuickBitEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    // Assumes SpeechRecognizer.swift exists
    @StateObject private var speech = SpeechRecognizer()
    @State private var text: String = ""
    
    // Animation state for the recording pulse
    @State private var pulsePhase = false

    @ObservedObject private var keyboard = TFKeyboardState.shared

    // MARK: - Auto-Save State
    /// Tracks whether the user explicitly tapped Cancel (discard) vs. any other dismissal (save)
    @State private var userCancelled = false
    @State private var saveIndicatorVisible = false
    @State private var autoSaveTask: Task<Void, Never>? = nil
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // Main Content
                VStack(spacing: 12) {
                    PlainTextEditor(text: $text)
                        .ignoresSafeArea(.keyboard, edges: .bottom)
                        .padding(.horizontal, 12)
                        .padding(.top, 12)
                    
                    Spacer(minLength: 0)
                }
                
                // The Brand-Matched Transcription Card
                if speech.isRecording {
                    transcriptionOverlay
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(2)
                }
            }
            .navigationTitle("Quick Bit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { cancelAndDismiss() }
                        .foregroundStyle(Color("TFYellow"))
                }
                
                // The New "Physical" Mic Button
                ToolbarItem(placement: .principal) {
                    micButton
                        .offset(y: 4) // Push down slightly to sit nicely in the bar
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveAndDismiss()
                    }
                    .foregroundStyle(Color("TFYellow"))
                    .disabled(isEmpty && !speech.isRecording)
                }
            }
            .hideKeyboardInteractively() // Use combined tap + swipe-down dismissal
            // Auto-save indicator — small, unobtrusive, bottom-trailing
            .overlay(alignment: .bottomTrailing) {
                saveIndicator
            }
        }
        .onDisappear {
            speech.stopTranscribing()
            // Save to Loose Ideas on any close EXCEPT explicit Cancel
            guard !userCancelled else { return }
            commitTranscription()
            let plain = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !plain.isEmpty else { return }
            modelContext.insert(Bit(text: plain, status: .loose))
        }
        .onChange(of: text) {
            scheduleIndicator()
        }
    }
    
    // MARK: - The "Physical" Mic Button
    
    private var micButton: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                if speech.isRecording {
                    commitTranscription()
                    speech.stopTranscribing()
                    pulsePhase = false
                } else {
                    speech.startTranscribing()
                    pulsePhase = true
                }
            }
        } label: {
            ZStack {
                // Layer 1: The Pulsing "Dust" Ring (Only when recording)
                if speech.isRecording {
                    Circle()
                        .stroke(Color.red.opacity(0.4), lineWidth: 4)
                        .scaleEffect(pulsePhase ? 1.6 : 1.0)
                        .opacity(pulsePhase ? 0.0 : 1.0)
                        .animation(
                            .easeOut(duration: 1.5).repeatForever(autoreverses: false),
                            value: pulsePhase
                        )
                }
                
                // Layer 2: The Physical Button with Dust INSIDE
                ZStack {
                    // Base yellow circle
                    Circle()
                        .fill(speech.isRecording ? Color(red: 0.85, green: 0.2, blue: 0.2) : Color("TFYellow"))
                    
                    // Dynamic dust layers (only when not recording) - MATCHES YOUR CARDS
                    if !speech.isRecording {
                        // Coarse dust layer
                        StaticGritLayer(
                            density: 60,
                            opacity: 0.12,
                            seed: 9991
                        )
                        
                        // Fine dust layer
                        StaticGritLayer(
                            density: 40,
                            opacity: 0.25,
                            seed: 9992
                        )
                    }
                }
                .frame(width: 48, height: 48)
                .clipShape(Circle())
                // Deep shadow for "pop" off the chalkboard
                .shadow(color: .black.opacity(0.6), radius: 4, x: 0, y: 3)
                .overlay(
                    // Inner "highlight" ring for 3D effect
                    Circle()
                        .strokeBorder(.white.opacity(0.25), lineWidth: 1.5)
                        .blendMode(.screen)
                        .padding(1)
                )
                .overlay(
                    // Outer dark ring for definition
                    Circle()
                        .strokeBorder(.black.opacity(0.15), lineWidth: 1)
                )
                
                // Layer 3: The Icon (on top of everything)
                Image(systemName: speech.isRecording ? "waveform" : "mic.fill")
                    .appFont(size: 20, weight: .black)
                    .foregroundStyle(speech.isRecording ? .white : .black.opacity(0.85))
                    .symbolEffect(.variableColor.iterative, isActive: speech.isRecording)
                    .contentTransition(.symbolEffect(.replace))
            }
        }
        .accessibilityLabel(speech.isRecording ? "Stop Recording" : "Start Dictation")
    }
    
    // MARK: - The Brand-Matched Note Card
    
    private var transcriptionOverlay: some View {
        VStack(spacing: 12) {
            // Status Header
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                Text("LISTENING")
                    .appFont(.caption, weight: .bold)
                    .foregroundStyle(Color.red)
                    .kerning(1.2)
            }
            .padding(.top, 4)
            
            // The Live Text
            Text(speech.transcript.isEmpty ? "Say something funny..." : speech.transcript)
                .appFont(.title3, weight: .medium)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .padding(.horizontal)
                .frame(minHeight: 40)
                .animation(.smooth, value: speech.transcript)
            
            // Action Hint
            Text("Tap mic to finish")
                .appFont(.caption)
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        // BACKGROUND: Use your app's dark card color instead of generic material
        .background(Color("TFCard"))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        // BORDER: Use your app's Gold Stroke
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color("TFCardStroke"), lineWidth: 1.5)
                .opacity(0.9)
        )
        // SHADOW: Physical lift
        .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
        .padding(20)
    }
    
    // MARK: - Save Indicator

    private var saveIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption2)
            Text("Saved")
                .appFont(.caption2, weight: .medium)
        }
        .foregroundStyle(Color("TFYellow").opacity(0.8))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial, in: Capsule())
        .padding(.bottom, 12)
        .padding(.trailing, 16)
        .opacity(saveIndicatorVisible ? 1 : 0)
        .animation(.easeInOut(duration: 0.3), value: saveIndicatorVisible)
    }

    // MARK: - Auto-Save Logic

    /// Debounce: shows the "Saved" indicator 2 s after the user stops typing.
    private func scheduleIndicator() {
        autoSaveTask?.cancel()
        autoSaveTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            await showSaveIndicator()
        }
    }

    @MainActor
    private func showSaveIndicator() {
        saveIndicatorVisible = true
        Task {
            try? await Task.sleep(for: .seconds(1.8))
            saveIndicatorVisible = false
        }
    }

    // MARK: - Logic

    private var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func saveAndDismiss() {
        if speech.isRecording {
            commitTranscription()
            speech.stopTranscribing()
        }
        let plain = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !plain.isEmpty else { return }
        modelContext.insert(Bit(text: plain, status: .loose))
        userCancelled = true // prevent onDisappear from double-inserting
        dismiss()
    }

    private func cancelAndDismiss() {
        userCancelled = true
        dismiss()
    }

    private func commitTranscription() {
        guard !speech.transcript.isEmpty else { return }
        let prefix = text.isEmpty ? "" : " "
        text += prefix + speech.transcript
    }
}

