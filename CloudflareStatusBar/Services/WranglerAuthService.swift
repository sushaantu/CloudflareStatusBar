import Foundation

struct WranglerCredentials {
    let oauthToken: String?
    let apiToken: String?
    let accountId: String?

    var isAuthenticated: Bool {
        oauthToken != nil || apiToken != nil
    }

    var authorizationHeader: String? {
        if let token = oauthToken {
            return "Bearer \(token)"
        } else if let token = apiToken {
            return "Bearer \(token)"
        }
        return nil
    }
}

class WranglerAuthService {
    static let shared = WranglerAuthService()

    private init() {}

    func loadCredentials() -> WranglerCredentials {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser

        // Try multiple possible locations for wrangler config
        let possiblePaths = [
            homeDir.appendingPathComponent("Library/Preferences/.wrangler/config/default.toml"),
            homeDir.appendingPathComponent(".wrangler/config/default.toml"),
            homeDir.appendingPathComponent(".config/.wrangler/config/default.toml"),
            homeDir.appendingPathComponent(".config/wrangler/config/default.toml"),
        ]

        for path in possiblePaths {
            if let credentials = parseWranglerConfig(at: path) {
                return credentials
            }
        }

        // Fallback: Check for environment variables
        let envToken = ProcessInfo.processInfo.environment["CLOUDFLARE_API_TOKEN"]
        let envAccountId = ProcessInfo.processInfo.environment["CLOUDFLARE_ACCOUNT_ID"]

        return WranglerCredentials(
            oauthToken: nil,
            apiToken: envToken,
            accountId: envAccountId
        )
    }

    private func parseWranglerConfig(at url: URL) -> WranglerCredentials? {
        guard FileManager.default.fileExists(atPath: url.path),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }

        var oauthToken: String?
        var apiToken: String?
        var accountId: String?

        let lines = content.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("oauth_token") {
                oauthToken = extractValue(from: trimmed)
            } else if trimmed.hasPrefix("api_token") {
                apiToken = extractValue(from: trimmed)
            } else if trimmed.hasPrefix("account_id") {
                accountId = extractValue(from: trimmed)
            }
        }

        if oauthToken != nil || apiToken != nil {
            return WranglerCredentials(
                oauthToken: oauthToken,
                apiToken: apiToken,
                accountId: accountId
            )
        }

        return nil
    }

    private func extractValue(from line: String) -> String? {
        guard let equalIndex = line.firstIndex(of: "=") else { return nil }

        let valueStart = line.index(after: equalIndex)
        var value = String(line[valueStart...])
            .trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))

        // Remove inline comments
        if let commentIndex = value.firstIndex(of: "#") {
            value = String(value[..<commentIndex]).trimmingCharacters(in: .whitespaces)
        }

        return value.isEmpty ? nil : value
    }

    func refreshOAuthToken() async throws -> String? {
        // Wrangler stores refresh tokens - implement refresh logic if needed
        // For now, we rely on the stored token
        return loadCredentials().oauthToken
    }
}
