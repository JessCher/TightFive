import SwiftUI
import PhotosUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query private var profiles: [UserProfile]
    @Query(filter: #Predicate<Bit> { bit in !bit.isDeleted && bit.statusRaw == "loose" }, sort: \Bit.updatedAt, order: .reverse) private var looseBits: [Bit]
    @Query(filter: #Predicate<Bit> { bit in !bit.isDeleted && bit.statusRaw == "finished" }, sort: \Bit.updatedAt, order: .reverse) private var finishedBits: [Bit]
    @Query(sort: \Setlist.updatedAt, order: .reverse) private var setlists: [Setlist]
    
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var profileImage: UIImage?
    @State private var name: String = ""
    @State private var showsPerformed: Int = 0
    
    private var profile: UserProfile? {
        profiles.first
    }
    
    var body: some View {
        NavigationStack {
            Form {
                
                Section("Name") {
                    TextField("Enter your name", text: $name)
                        .onChange(of: name) { _, newValue in
                            if let profile = profile {
                                profile.name = newValue
                                profile.updatedAt = Date()
                                saveProfile()
                            }
                        }
                }
                
                Section {
                    HStack {
                        Stepper(value: $showsPerformed, in: 0...9999) {
                            Text("\(showsPerformed)")
                                .appFont(.title2, weight: .semibold)
                                .foregroundStyle(TFTheme.yellow)
                        }
                        .onChange(of: showsPerformed) { _, newValue in
                            if let profile = profile {
                                profile.showsPerformed = newValue
                                profile.updatedAt = Date()
                                saveProfile()
                            }
                        }
                    }
                } header: {
                    Text("Shows Performed")
                } footer: {
                    Text("Track how many live comedy shows you've performed.")
                }
                
                if profile != nil, !name.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Profile Summary")
                                .appFont(.headline)
                                .foregroundStyle(.white)

                            Text("\(name) has performed \(showsPerformed) show\(showsPerformed == 1 ? "" : "s").")
                                .appFont(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))

                            // Counters
                            HStack(spacing: 12) {
                                counterCard(icon: "doc.text", color: TFTheme.yellow, value: "\(looseBits.count)", label: "Loose Ideas")
                                counterCard(icon: "checkmark.seal.fill", color: .green, value: "\(finishedBits.count)", label: "Finished Bits")
                            }

                            HStack(spacing: 12) {
                                counterCard(icon: "list.bullet.rectangle", color: .cyan, value: "\(setlists.count)", label: "Setlists")
                                Spacer(minLength: 0)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .tfBackground()
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    TFWordmarkTitle(title: "Profile", size: 22)
                }
            }
            .onAppear {
                loadProfile()
            }
            .onDisappear {
                saveProfile()
            }
        }
    }
    
    // MARK: - Methods
    
    private func loadProfile() {
        if profiles.isEmpty {
            let newProfile = UserProfile()
            modelContext.insert(newProfile)
            do {
                try modelContext.save()
            } catch {
                assertionFailure("Error creating profile: \(error.localizedDescription)")
            }
        }
        
        if let profile = profile {
            name = profile.name
            showsPerformed = profile.showsPerformed
        } else {
            assertionFailure("No profile found after creation attempt")
        }
    }
    
    private func saveProfile() {
        guard profile != nil else {
            assertionFailure("Attempted to save but no profile exists")
            return
        }
        
        do {
            try modelContext.save()
        } catch {
            assertionFailure("Error saving profile: \(error.localizedDescription)")
        }
    }
    
    private func counterCard(icon: String, color: Color, value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)
                Spacer()
            }
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(label)
                .appFont(.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .tfDynamicCard(cornerRadius: 14)
    }
}

#Preview {
    ProfileView()
}
