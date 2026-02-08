import SwiftUI
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
            // MARK: - HIDDEN: Custom Icons
            // Hiding: IconInProgress, IconFinishedSetlist
            // if isAsset {
            //     Image(iconName)
            //         .renderingMode(.original)
            //         .resizable()
            //         .scaledToFit()
            //         .frame(width: 34, height: 34)
            // } else {
            //     Image(systemName: iconName)
            //         .appFont(size: 22, weight: .semibold)
            //         .foregroundStyle(TFTheme.yellow)
            //         .frame(width: 34, height: 34)
            // }

            Spacer()

            VStack(alignment: .center, spacing: 4) {
                Text(title)
                    .appFont(.headline)
                    .foregroundStyle(TFTheme.text)

                Text(subtitle)
                    .appFont(.subheadline)
                    .foregroundStyle(TFTheme.text.opacity(0.62))
                    .multilineTextAlignment(.center)
            }

            Spacer()
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

    @State private var selectedSetlist: Setlist?
    @State private var showDeleteConfirmation = false
    @State private var setlistToDelete: Setlist?

    var body: some View {
        Group {
            if setlists.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(setlists) { s in
                            CardSwipeView(
                                swipeRightEnabled: false,
                                swipeRightIcon: "play.fill",
                                swipeRightColor: .green,
                                swipeRightLabel: "Run",
                                swipeLeftIcon: "trash.fill",
                                swipeLeftColor: .red,
                                swipeLeftLabel: "Delete",
                                onSwipeRight: {},
                                onSwipeLeft: {
                                    setlistToDelete = s
                                    showDeleteConfirmation = true
                                },
                                onTap: { selectedSetlist = s }
                            ) {
                                row(s)
                            }
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
        .navigationDestination(item: $selectedSetlist) { s in
            SetlistBuilderView(setlist: s)
        }
        .alert("Delete Setlist?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                if let s = setlistToDelete {
                    s.isDeleted = true
                    s.deletedAt = Date()
                    try? modelContext.save()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This setlist will be moved to the trash.")
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "hammer")
                .appFont(size: 48)
                .foregroundStyle(TFTheme.text.opacity(0.3))
            Text("No setlists in progress")
                .appFont(.title3, weight: .semibold)
                .foregroundStyle(TFTheme.text)
            Text("Create a new setlist to start building.")
                .appFont(.subheadline)
                .foregroundStyle(TFTheme.text.opacity(0.6))
            Spacer()
        }
    }

    private func row(_ s: Setlist) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(s.title)
                    .appFont(.headline)
                    .foregroundStyle(TFTheme.text)
                
                Spacer()
            }
            
            HStack(spacing: 8) {
                Text(s.updatedAt, style: .date)
                    .appFont(.caption)
                    .foregroundStyle(TFTheme.text.opacity(0.5))
                
                if s.bitCount > 0 {
                    Text("\(s.bitCount) bits")
                        .appFont(.caption)
                        .foregroundStyle(TFTheme.text.opacity(0.5))
                }
                
                if s.blockCount > s.bitCount {
                    Text("\(s.blockCount - s.bitCount) text")
                        .appFont(.caption)
                        .foregroundStyle(TFTheme.text.opacity(0.4))
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

    @State private var selectedSetlist: Setlist?
    @State private var showDeleteConfirmation = false
    @State private var setlistToDelete: Setlist?
    @State private var runThroughSetlist: Setlist?

    var body: some View {
        Group {
            if setlists.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(setlists) { s in
                            CardSwipeView(
                                swipeRightEnabled: true,
                                swipeRightIcon: "play.fill",
                                swipeRightColor: .green,
                                swipeRightLabel: "Run",
                                swipeLeftIcon: "trash.fill",
                                swipeLeftColor: .red,
                                swipeLeftLabel: "Delete",
                                onSwipeRight: { runThroughSetlist = s },
                                onSwipeLeft: {
                                    setlistToDelete = s
                                    showDeleteConfirmation = true
                                },
                                onTap: { selectedSetlist = s }
                            ) {
                                row(s)
                            }
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
        .navigationDestination(item: $selectedSetlist) { s in
            SetlistBuilderView(setlist: s)
        }
        .fullScreenCover(item: $runThroughSetlist) { s in
            RunModeView(setlist: s)
        }
        .alert("Delete Setlist?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                if let s = setlistToDelete {
                    s.isDeleted = true
                    s.deletedAt = Date()
                    try? modelContext.save()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This setlist will be moved to the trash.")
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "checkmark.seal")
                .appFont(size: 48)
                .foregroundStyle(TFTheme.text.opacity(0.3))
            Text("No finished setlists")
                .appFont(.title3, weight: .semibold)
                .foregroundStyle(TFTheme.text)
            Text("Mark a setlist as finished when it's stage-ready.")
                .appFont(.subheadline)
                .foregroundStyle(TFTheme.text.opacity(0.6))
            Spacer()
        }
    }

    private func row(_ s: Setlist) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(s.title)
                    .appFont(.headline)
                    .foregroundStyle(TFTheme.text)
                
                Spacer()
            }
            
            HStack(spacing: 8) {
                // Duration estimate
                if s.hasScriptContent {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .appFont(.caption2)
                        Text(s.formattedDuration)
                    }
                    .appFont(.caption, weight: .medium)
                    .foregroundStyle(TFTheme.yellow)
                }
                
                Text(s.updatedAt, style: .date)
                    .appFont(.caption)
                    .foregroundStyle(TFTheme.text.opacity(0.5))
                
                if s.bitCount > 0 {
                    Text("\(s.bitCount) bits")
                        .appFont(.caption)
                        .foregroundStyle(TFTheme.text.opacity(0.5))
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
