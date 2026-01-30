import SwiftUI
import PhotosUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query private var profiles: [UserProfile]
    
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
                Section {
                    profileImageSection
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(Color.clear)
                }
                
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
                                .font(.title2.weight(.semibold))
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
                
                if let profile = profile, !name.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Profile Summary")
                                .font(.headline)
                                .foregroundStyle(.white)
                            
                            Text("\(name) has performed \(showsPerformed) show\(showsPerformed == 1 ? "" : "s").")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
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
            .onChange(of: selectedPhoto) { _, newValue in
                Task {
                    guard let newValue = newValue else { return }
                    
                    do {
                        if let data = try await newValue.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            // Update UI state
                            await MainActor.run {
                                profileImage = image
                            }
                            
                            // Update and save profile
                            if let profile = profile {
                                profile.profileImageData = data
                                profile.updatedAt = Date()
                                saveProfile()
                            }
                        }
                    } catch {
                        print("Error loading image: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private var profileImageSection: some View {
        VStack(spacing: 16) {
            profileImageButton
        }
    }
    
    private var profileImageButton: some View {
        PhotosPicker(selection: $selectedPhoto, matching: .images) {
            profileImageContent
        }
        .buttonStyle(.plain)
    }
    
    private var profileImageContent: some View {
        ZStack {
            if let image = profileImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
            } else {
                placeholderProfileImage
            }
            
            cameraBadge
        }
    }
    
    private var placeholderProfileImage: some View {
        Circle()
            .fill(TFTheme.yellow.opacity(0.2))
            .frame(width: 120, height: 120)
            .overlay {
                Image(systemName: "person.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(TFTheme.yellow)
            }
    }
    
    private var cameraBadge: some View {
        Circle()
            .fill(TFTheme.yellow)
            .frame(width: 36, height: 36)
            .overlay {
                Image(systemName: "camera.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.black)
            }
            .offset(x: 40, y: 40)
    }
    
    // MARK: - Methods
    
    private func loadProfile() {
        // Ensure a profile exists
        if profiles.isEmpty {
            print("Creating new profile...")
            let newProfile = UserProfile()
            modelContext.insert(newProfile)
            do {
                try modelContext.save()
                print("New profile created and saved")
            } catch {
                print("Error creating profile: \(error.localizedDescription)")
            }
        }
        
        // Load profile data into state
        if let profile = profile {
            print("Loading profile: name='\(profile.name)', shows=\(profile.showsPerformed)")
            name = profile.name
            showsPerformed = profile.showsPerformed
            
            // Load existing image if available
            if let imageData = profile.profileImageData,
               let image = UIImage(data: imageData) {
                profileImage = image
                print("Profile image loaded successfully")
            } else {
                print("No profile image data available")
            }
        } else {
            print("WARNING: No profile found after creation attempt")
        }
    }
    
    private func saveProfile() {
        guard let profile = profile else {
            print("WARNING: Attempted to save but no profile exists")
            return
        }
        
        do {
            try modelContext.save()
            print("Profile saved: name='\(profile.name)', shows=\(profile.showsPerformed)")
        } catch {
            print("Error saving profile: \(error.localizedDescription)")
        }
    }
}

#Preview {
    ProfileView()
}
