import SwiftUI
import SwiftData
import UIKit

struct SetlistsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Setlist.updatedAt, order: .reverse) private var setlists: [Setlist]

    @State private var newlyCreated: Setlist?

    var body: some View {
        VStack(spacing: 20) {
                NavigationLink {
                    InProgressSetlistsView()
                } label: {
                    SetlistMenuTile(
                        title: "In Progress",
                        subtitle: "Keep working on drafts.",
                        iconName: "IconInProgress",
                        isAsset: true
                    )
                }

                NavigationLink {
                    FinishedSetlistsView()
                } label: {
                    SetlistMenuTile(
                        title: "Finished",
                        subtitle: "Ready for the stage.",
                        iconName: "IconFinishedSetlist",
                        isAsset: true
                    )
                }

                Spacer()
            }
            .hideKeyboardInteractively()
            .padding()
            .navigationTitle("Set lists")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    TFWordmarkTitle(title: "Set lists", size: 22)
                        .offset(x: -6)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        let s = Setlist(title: "Untitled Set", notesRTF: Data(), isDraft: true)
                        modelContext.insert(s)
                        try? modelContext.save()
                        newlyCreated = s
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("New Setlist")
                }
            }
            .tfBackground()
            .navigationDestination(item: $newlyCreated) { set in
                SetlistBuilderView(setlist: set)
            }
    }
}

private struct SetlistMenuTile: View {
    let title: String
    let subtitle: String
    let iconName: String
    let isAsset: Bool

    var body: some View {
        HStack(spacing: 14) {
            if isAsset {
                Image(iconName)
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 34, height: 34)
            } else {
                Image(systemName: iconName)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(TFTheme.yellow)
                    .frame(width: 34, height: 34)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.62))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.28))
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 16)
        .tfDynamicCard(cornerRadius: 20)
    }
}

// MARK: - In Progress List

struct InProgressSetlistsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<Setlist> { $0.isDraft == true && !$0.isDeleted },
        sort: \Setlist.updatedAt,
        order: .reverse
    ) private var setlists: [Setlist]

    var body: some View {
        Group {
            if setlists.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(setlists) { s in
                            NavigationLink { 
                                SetlistBuilderView(setlist: s) 
                            } label: {
                                row(s)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }
            }
        }
        .navigationTitle("In Progress")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                TFWordmarkTitle(title: "In Progress", size: 22)
                    .offset(x: -6)
            }
        }
        .tfBackground()
    }
    
    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "hammer")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.3))
            Text("No setlists in progress")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
            Text("Create a new setlist to start building.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
            Spacer()
        }
    }

    private func row(_ s: Setlist) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(s.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                
                if s.hasConfiguredAnchors {
                    Image(systemName: "waveform")
                        .font(.caption)
                        .foregroundStyle(TFTheme.yellow)
                }
                
                Spacer()
            }
            
            HStack(spacing: 8) {
                Text(s.updatedAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                
                if s.bitCount > 0 {
                    Text("\(s.bitCount) bits")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
                
                if s.blockCount > s.bitCount {
                    Text("\(s.blockCount - s.bitCount) text")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .tfDynamicCard(cornerRadius: 18)
    }
}

// MARK: - Finished List

struct FinishedSetlistsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<Setlist> { $0.isDraft == false && !$0.isDeleted },
        sort: \Setlist.updatedAt,
        order: .reverse
    ) private var setlists: [Setlist]

    var body: some View {
        Group {
            if setlists.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(setlists) { s in
                            NavigationLink { 
                                SetlistBuilderView(setlist: s) 
                            } label: {
                                row(s)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }
            }
        }
        .navigationTitle("Finished")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                TFWordmarkTitle(title: "Finished", size: 22)
                    .offset(x: -6)
            }
        }
        .tfBackground()
    }
    
    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "checkmark.seal")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.3))
            Text("No finished setlists")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
            Text("Mark a setlist as finished when it's stage-ready.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
            Spacer()
        }
    }

    private func row(_ s: Setlist) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(s.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                
                if s.isStageReady {
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill")
                        Text("Stage Ready")
                    }
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(TFTheme.yellow)
                    .clipShape(Capsule())
                } else if s.hasConfiguredAnchors {
                    Image(systemName: "waveform")
                        .font(.caption)
                        .foregroundStyle(TFTheme.yellow)
                }
                
                Spacer()
            }
            
            HStack(spacing: 8) {
                // Duration estimate
                if s.hasScriptContent {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text(s.formattedDuration)
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(TFTheme.yellow)
                }
                
                Text(s.updatedAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                
                if s.bitCount > 0 {
                    Text("\(s.bitCount) bits")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .tfDynamicCard(cornerRadius: 18)
    }
}

#Preview {
    SetlistsView()
}
