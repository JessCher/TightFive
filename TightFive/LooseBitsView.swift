import SwiftUI
import SwiftData

struct LooseBitsView: View {
    enum Mode {
        case all
        case loose
        case finished
    }

    let mode: Mode

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Bit.updatedAt, order: .reverse) private var bits: [Bit]

    @State private var query: String = ""
    @State private var showQuickBit = false

    private var title: String {
        switch mode {
        case .all: return "Bits"
        case .loose: return "Loose Bits"
        case .finished: return "Finished Bits"
        }
    }

    private var filtered: [Bit] {
        let base: [Bit] = {
            switch mode {
            case .all: return bits
            case .loose: return bits.filter { $0.status == .loose }
            case .finished: return bits.filter { $0.status == .finished }
            }
        }()

        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return base }
        return base.filter { $0.text.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if filtered.isEmpty {
                        emptyState
                            .padding(.top, 40)
                    } else {
                        ForEach(filtered) { bit in
                            NavigationLink {
                                BitDetailView(bit: bit)
                            } label: {
                                BitCardRow(bit: bit)
                                    .contentShape(Rectangle())
                            }
                            .contextMenu {
                                Button {
                                    withAnimation(.easeInOut) {
                                        toggleStatus(bit)
                                    }
                                } label: {
                                    Label(bit.status == .loose ? "Mark Finished" : "Mark Loose",
                                          systemImage: bit.status == .loose ? "checkmark.seal" : "tray.full")
                                }

                                Button(role: .destructive) {
                                    withAnimation(.easeInOut) {
                                        modelContext.delete(bit)
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    withAnimation(.easeInOut) {
                                        modelContext.delete(bit)
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    withAnimation(.easeInOut) {
                                        toggleStatus(bit)
                                    }
                                } label: {
                                    Label(bit.status == .loose ? "Finish" : "Loose",
                                          systemImage: bit.status == .loose ? "checkmark.seal.fill" : "tray.full.fill")
                                }
                                .tint(TFTheme.yellow)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .tfBackground()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "Search bits")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    TFWordmarkTitle(title: title, size: 22)
                        .offset(x: -6)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showQuickBit = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(TFTheme.yellow)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.10))
                            .clipShape(Circle())
                            .overlay(
                                Circle().stroke(Color("TFCardStroke").opacity(0.9), lineWidth: 1)
                            )
                    }
                    .accessibilityLabel("New Bit")
                }
            }
            .sheet(isPresented: $showQuickBit) {
                QuickBitEditor()
                    .presentationDetents([.medium, .large])
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Text(mode == .finished ? "No finished bits yet" : "No loose bits yet")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            Text(mode == .finished
                 ? "Move a bit to Finished when it’s stage-ready."
                 : "Tap + to capture an idea and it’ll show up here.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.65))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 26)

            Button {
                showQuickBit = true
            } label: {
                Text("Quick Bit")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(TFTheme.yellow)
                    .clipShape(Capsule())
            }
            .padding(.top, 6)
        }
    }

    private func toggleStatus(_ bit: Bit) {
        bit.status = (bit.status == .loose) ? .finished : .loose
        bit.updatedAt = Date()
    }
}

// MARK: - Bit row

private struct BitCardRow: View {
    let bit: Bit

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: bit.status == .finished ? "checkmark.seal.fill" : "tray.full.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(TFTheme.yellow)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 6) {
                Text(bit.titleLine)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text(bit.updatedAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.25))
                .padding(.top, 4)
        }
        .tfTexturedCard(cornerRadius: 18)
    }
}

// MARK: - Detail

private struct BitDetailView: View {
    @Bindable var bit: Bit

    var body: some View {
        Form {
            Section("Text") {
                TextEditor(text: $bit.text)
                    .frame(minHeight: 240)
            }

            Section("Status") {
                Picker("Status", selection: Binding(
                    get: { bit.status },
                    set: { newValue in
                        bit.status = newValue
                        bit.updatedAt = Date()
                    }
                )) {
                    Text("Loose").tag(BitStatus.loose)
                    Text("Finished").tag(BitStatus.finished)
                }
                .pickerStyle(.segmented)
            }
        }
        .scrollContentBackground(.hidden)
        .tfBackground()
        .navigationTitle("Bit")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: bit.text) {
            bit.updatedAt = Date()
        }
    }
}

