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
                    Button("Cancel") { dismiss() }
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
            .tfUndoRedoToolbar(isVisible: keyboard.isVisible)
        }
        .onDisappear {
            speech.stopTranscribing()
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
    
    // MARK: - Logic
    
    // This was missing in your snippet!
    private var isEmpty: Bool {
        let plain = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return plain.isEmpty
    }
    
    private func saveAndDismiss() {
        if speech.isRecording {
            commitTranscription()
            speech.stopTranscribing()
        }
        let plain = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !plain.isEmpty else { return }
        
        // Assumes you have a 'Bit' model in SwiftData
        modelContext.insert(Bit(text: plain, status: .loose))
        dismiss()
    }
    
    private func commitTranscription() {
        guard !speech.transcript.isEmpty else { return }
        
        // Append transcribed text to existing text
        let prefix = text.isEmpty ? "" : " "
        text += prefix + speech.transcript
    }
}

