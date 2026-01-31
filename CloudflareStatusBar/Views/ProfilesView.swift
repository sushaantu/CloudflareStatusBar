import SwiftUI

struct ProfilesView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var profiles: [Profile] = []
    @State private var activeProfileId: String?
    @State private var showingAddProfile = false
    @State private var editingProfile: Profile?
    @State private var showingDeleteConfirmation = false
    @State private var profileToDelete: Profile?

    var onProfileChanged: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Manage Profiles")
                    .font(.headline)
                Spacer()
                Button(action: { showingAddProfile = true }) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
                .help("Add Profile")
            }
            .padding()

            Divider()

            if profiles.isEmpty {
                emptyStateView
            } else {
                profileListView
            }

            Divider()

            // Footer
            HStack {
                Text("Active profile is used for API calls")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 400, height: 350)
        .onAppear {
            loadProfiles()
        }
        .sheet(isPresented: $showingAddProfile) {
            ProfileEditView(
                profile: nil,
                onSave: { profile in
                    ProfileService.shared.addProfile(profile)
                    loadProfiles()
                    // Auto-select first profile if none active
                    if activeProfileId == nil {
                        setActiveProfile(profile.id)
                    }
                }
            )
        }
        .sheet(item: $editingProfile) { profile in
            ProfileEditView(
                profile: profile,
                onSave: { updated in
                    ProfileService.shared.updateProfile(updated)
                    loadProfiles()
                }
            )
        }
        .alert("Delete Profile", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let profile = profileToDelete {
                    deleteProfile(profile)
                }
            }
        } message: {
            Text("Are you sure you want to delete \"\(profileToDelete?.name ?? "")\"? This cannot be undone.")
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("No Profiles")
                .font(.headline)
            Text("Add a profile to manage multiple Cloudflare accounts.\nWithout profiles, wrangler login credentials are used.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Add Profile") {
                showingAddProfile = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var profileListView: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Wrangler option (use default)
                wranglerOptionRow

                ForEach(profiles) { profile in
                    profileRow(profile)
                }
            }
            .padding()
        }
    }

    private var wranglerOptionRow: some View {
        HStack {
            Image(systemName: activeProfileId == nil ? "checkmark.circle.fill" : "circle")
                .foregroundColor(activeProfileId == nil ? .accentColor : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text("Wrangler Default")
                    .fontWeight(activeProfileId == nil ? .medium : .regular)
                Text("Uses wrangler login credentials")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(10)
        .background(activeProfileId == nil ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture {
            setActiveProfile(nil)
        }
    }

    private func profileRow(_ profile: Profile) -> some View {
        HStack {
            Image(systemName: activeProfileId == profile.id ? "checkmark.circle.fill" : "circle")
                .foregroundColor(activeProfileId == profile.id ? .accentColor : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name)
                    .fontWeight(activeProfileId == profile.id ? .medium : .regular)
                Text("API Token: ••••••••\(String(profile.apiToken.suffix(4)))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: { editingProfile = profile }) {
                Image(systemName: "pencil")
            }
            .buttonStyle(.plain)
            .help("Edit")

            Button(action: {
                profileToDelete = profile
                showingDeleteConfirmation = true
            }) {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
            .foregroundColor(.red)
            .help("Delete")
        }
        .padding(10)
        .background(activeProfileId == profile.id ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture {
            setActiveProfile(profile.id)
        }
    }

    private func loadProfiles() {
        Task {
            let profiles = await ProfileService.shared.getProfilesAsync()
            let activeProfileId = ProfileService.shared.getActiveProfileId()
            self.profiles = profiles
            self.activeProfileId = activeProfileId
        }
    }

    private func setActiveProfile(_ id: String?) {
        activeProfileId = id
        ProfileService.shared.setActiveProfileId(id)
        onProfileChanged?()
    }

    private func deleteProfile(_ profile: Profile) {
        ProfileService.shared.deleteProfile(id: profile.id)
        loadProfiles()
        onProfileChanged?()
    }
}

// MARK: - Profile Edit View

struct ProfileEditView: View {
    @Environment(\.dismiss) private var dismiss

    let profile: Profile?
    let onSave: (Profile) -> Void

    @State private var name: String = ""
    @State private var apiToken: String = ""
    @State private var showingToken = false
    @State private var isValidating = false
    @State private var validationError: String?

    var isEditing: Bool { profile != nil }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(isEditing ? "Edit Profile" : "Add Profile")
                    .font(.headline)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Form
            Form {
                TextField("Profile Name", text: $name)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    if showingToken {
                        TextField("API Token", text: $apiToken)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    } else {
                        SecureField("API Token", text: $apiToken)
                            .textFieldStyle(.roundedBorder)
                    }

                    Button(action: { showingToken.toggle() }) {
                        Image(systemName: showingToken ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.plain)
                }

                if let error = validationError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }

                Text("Get your API token from the Cloudflare dashboard:\nMy Profile → API Tokens → Create Token")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()

            Divider()

            // Footer
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(isValidating ? "Validating..." : "Save") {
                    validateAndSave()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty || apiToken.isEmpty || isValidating)
            }
            .padding()
        }
        .frame(width: 400, height: 280)
        .onAppear {
            if let profile = profile {
                name = profile.name
                apiToken = profile.apiToken
            }
        }
    }

    private func validateAndSave() {
        isValidating = true
        validationError = nil

        // Validate the API token by making a test request
        Task {
            let isValid = await validateToken(apiToken)

            await MainActor.run {
                isValidating = false

                if isValid {
                    let newProfile = Profile(
                        id: profile?.id ?? UUID().uuidString,
                        name: name,
                        apiToken: apiToken
                    )
                    onSave(newProfile)
                    dismiss()
                } else {
                    validationError = "Invalid API token. Please check and try again."
                }
            }
        }
    }

    private func validateToken(_ token: String) async -> Bool {
        guard let url = URL(string: "https://api.cloudflare.com/client/v4/user/tokens/verify") else {
            return false
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return false
            }

            // Check the response for success
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let success = json["success"] as? Bool {
                return success
            }

            return false
        } catch {
            return false
        }
    }
}

#Preview {
    ProfilesView()
}
