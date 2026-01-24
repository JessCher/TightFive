import SwiftUI
import SwiftData

struct StageModeMenuItems: View {
    let setlist: Setlist
    @Binding var showAnchorEditor: Bool
    @Binding var showStageMode: Bool
    
    var body: some View {
        if !setlist.isDraft && !setlist.orderedAssignments.isEmpty {
            Section {
                if setlist.hasConfiguredAnchors {
                    Button {
                        showStageMode = true
                    } label: {
                        Label("Start Stage Mode", systemImage: "mic.fill")
                    }
                    
                    Button {
                        showAnchorEditor = true
                    } label: {
                        Label("Edit Anchors", systemImage: "waveform")
                    }
                } else {
                    Button {
                        showAnchorEditor = true
                    } label: {
                        Label("Configure Stage Mode", systemImage: "waveform.badge.plus")
                    }
                }
            }
        }
    }
}

struct StageModeReadyBadge: View {
    let setlist: Setlist
    
    var body: some View {
        if setlist.isStageReady {
            HStack(spacing: 4) {
                Image(systemName: "mic.fill")
                    .font(.caption2)
                Text("Stage Ready")
                    .font(.caption2.weight(.medium))
            }
            .foregroundStyle(.black)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(TFTheme.yellow)
            .clipShape(Capsule())
        } else if !setlist.isDraft && !setlist.orderedAssignments.isEmpty {
            HStack(spacing: 4) {
                Image(systemName: "waveform")
                    .font(.caption2)
                Text("Configure Stage")
                    .font(.caption2.weight(.medium))
            }
            .foregroundStyle(.white.opacity(0.7))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.1))
            .clipShape(Capsule())
        }
    }
}

struct SetlistRowWithStageStatus: View {
    let setlist: Setlist
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(setlist.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                
                HStack(spacing: 8) {
                    Text(setlist.updatedAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                    
                    if setlist.bitCount > 0 {
                        Text("\(setlist.bitCount) bits")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    
                    if setlist.isStageReady {
                        HStack(spacing: 2) {
                            Image(systemName: "mic.fill")
                                .font(.caption2)
                            Text("Ready")
                                .font(.caption2)
                        }
                        .foregroundStyle(TFTheme.yellow)
                    }
                }
            }
            
            Spacer()
            
            if setlist.isStageReady {
                Image(systemName: "mic.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(TFTheme.yellow)
            }
        }
        .padding(.vertical, 4)
    }
}

struct StageModeFAB: View {
    let setlist: Setlist
    let action: () -> Void
    
    var body: some View {
        if setlist.isStageReady {
            Button(action: action) {
                HStack(spacing: 8) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 18, weight: .bold))
                    Text("Stage Mode")
                        .font(.headline)
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(TFTheme.yellow)
                .clipShape(Capsule())
                .shadow(color: TFTheme.yellow.opacity(0.3), radius: 10, x: 0, y: 4)
                .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 3)
            }
        }
    }
}

struct StageModeOnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    
    let setlist: Setlist
    let onConfigure: () -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                ZStack {
                    Circle()
                        .fill(TFTheme.yellow.opacity(0.15))
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "mic.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(TFTheme.yellow)
                }
                .padding(.top, 20)
                
                VStack(spacing: 8) {
                    Text("Stage Mode")
                        .font(.title.weight(.bold))
                        .foregroundStyle(.white)
                    
                    Text("Your voice-activated teleprompter")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    featureRow(icon: "waveform", title: "Voice Navigation", description: "Say your opening lines and the teleprompter follows")
                    featureRow(icon: "record.circle", title: "Auto Recording", description: "Capture your entire performance for review")
                    featureRow(icon: "text.alignleft", title: "Full-Screen Display", description: "Large, readable text optimized for stage lighting")
                    featureRow(icon: "note.text", title: "Show Notes", description: "Review recordings and add reflections after")
                }
                .padding(20)
                .background(Color("TFCard"))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                
                Spacer()
                
                VStack(spacing: 12) {
                    Button {
                        dismiss()
                        onConfigure()
                    } label: {
                        Text("Configure Anchor Phrases")
                            .font(.headline)
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(TFTheme.yellow)
                            .clipShape(Capsule())
                    }
                    
                    Text("\(setlist.bitCount) bits ready to configure")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.bottom, 20)
            }
            .padding(.horizontal, 20)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Later") {
                        dismiss()
                    }
                    .foregroundStyle(.white.opacity(0.7))
                }
            }
            .tfBackground()
        }
    }
    
    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(TFTheme.yellow)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }
}

struct StageModeLaunchSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    let setlist: Setlist
    let onStart: (String) -> Void
    
    @State private var venue: String = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text(setlist.title)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                    
                    let enabledAnchors = setlist.stageAnchors.filter { $0.isEnabled }
                    Text("\(setlist.bitCount) bits - \(enabledAnchors.count) anchors")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.top, 20)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Venue (optional)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                    
                    TextField("e.g., The Comedy Store", text: $venue)
                        .textFieldStyle(.plain)
                        .foregroundStyle(.white)
                        .padding(14)
                        .background(Color("TFCard"))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color("TFCardStroke").opacity(0.5), lineWidth: 1)
                        )
                }
                .padding(.horizontal, 20)
                
                VStack(alignment: .leading, spacing: 12) {
                    checklistItem("Microphone access granted", isChecked: true)
                    checklistItem("Speech recognition ready", isChecked: true)
                    
                    let validAnchors = setlist.stageAnchors.filter { $0.isEnabled && $0.isValid }
                    checklistItem("\(validAnchors.count) anchors configured", isChecked: setlist.hasConfiguredAnchors)
                    checklistItem("Recording will start automatically", isChecked: true)
                }
                .padding(16)
                .background(Color("TFCard"))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 20)
                
                Spacer()
                
                VStack(spacing: 12) {
                    Button {
                        dismiss()
                        onStart(venue)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "mic.fill")
                            Text("Begin Performance")
                        }
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(TFTheme.yellow)
                        .clipShape(Capsule())
                    }
                    
                    Text("Recording starts immediately")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .navigationTitle("Stage Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(TFTheme.yellow)
                }
            }
            .tfBackground()
        }
    }
    
    private func checklistItem(_ text: String, isChecked: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isChecked ? .green : .white.opacity(0.3))
            
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(isChecked ? 0.9 : 0.5))
            
            Spacer()
        }
    }
}

#Preview("Onboarding") {
    let setlist = Setlist(title: "My Test Set", isDraft: false)
    return StageModeOnboardingView(setlist: setlist, onConfigure: {})
}

#Preview("Launch") {
    let setlist = Setlist(title: "Friday Night Set", isDraft: false)
    return StageModeLaunchSheet(setlist: setlist, onStart: { _ in })
}
