import Foundation
import Security

class ProfileService {
    static let shared = ProfileService()

    private let profilesKey = "com.cloudflarestatusbar.profiles"
    private let activeProfileIdKey = "activeProfileId"

    private init() {}

    // MARK: - Profile Management

    func getProfiles() -> [Profile] {
        guard let data = KeychainHelper.load(key: profilesKey),
              let profiles = try? JSONDecoder().decode([Profile].self, from: data) else {
            return []
        }
        return profiles
    }

    func saveProfiles(_ profiles: [Profile]) {
        guard let data = try? JSONEncoder().encode(profiles) else { return }
        KeychainHelper.save(key: profilesKey, data: data)
    }

    func addProfile(_ profile: Profile) {
        var profiles = getProfiles()
        profiles.append(profile)
        saveProfiles(profiles)
    }

    func updateProfile(_ profile: Profile) {
        var profiles = getProfiles()
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profile
            saveProfiles(profiles)
        }
    }

    func deleteProfile(id: String) {
        var profiles = getProfiles()
        profiles.removeAll { $0.id == id }
        saveProfiles(profiles)

        // Clear active profile if deleted
        if getActiveProfileId() == id {
            setActiveProfileId(nil)
        }
    }

    // MARK: - Active Profile

    func getActiveProfileId() -> String? {
        UserDefaults.standard.string(forKey: activeProfileIdKey)
    }

    func setActiveProfileId(_ id: String?) {
        UserDefaults.standard.set(id, forKey: activeProfileIdKey)
    }

    func getActiveProfile() -> Profile? {
        guard let activeId = getActiveProfileId() else { return nil }
        return getProfiles().first { $0.id == activeId }
    }

    func setActiveProfile(_ profile: Profile?) {
        setActiveProfileId(profile?.id)
    }

    // MARK: - Credential Resolution

    /// Returns the API token to use, prioritizing: active profile > wrangler config
    func getActiveCredentials() -> WranglerCredentials {
        // First, check for active profile
        if let profile = getActiveProfile() {
            return WranglerCredentials(
                oauthToken: nil,
                apiToken: profile.apiToken,
                accountId: nil
            )
        }

        // Fall back to wrangler config
        return WranglerAuthService.shared.loadCredentials()
    }

    /// Check if using profiles or wrangler config
    var isUsingProfiles: Bool {
        getActiveProfile() != nil
    }
}

// MARK: - Keychain Helper

private enum KeychainHelper {
    static func save(key: String, data: Data) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        // Delete existing item first
        SecItemDelete(query as CFDictionary)

        // Add new item
        SecItemAdd(query as CFDictionary, nil)
    }

    static func load(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
