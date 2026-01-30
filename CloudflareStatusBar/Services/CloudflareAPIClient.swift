import Foundation

enum CloudflareAPIError: Error, LocalizedError {
    case notAuthenticated
    case tokenExpired
    case networkError(Error)
    case invalidResponse
    case apiError(String)
    case decodingError(Error)
    case decodingErrorWithPreview(Error, String)
    case unexpectedContentType(String?, String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated. Run 'wrangler login' in Terminal or add a profile."
        case .tokenExpired:
            return "Session expired. Run 'wrangler login' in Terminal to re-authenticate."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from Cloudflare API"
        case .apiError(let message):
            return "API error: \(message)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .decodingErrorWithPreview(_, let preview):
            return "Failed to parse API response. This may be caused by a proxy or firewall. Response preview: \(preview)"
        case .unexpectedContentType(let contentType, let preview):
            return "Unexpected response format (received \(contentType ?? "unknown")). This may be caused by a proxy or firewall. Preview: \(preview)"
        }
    }

    /// Check if an error message indicates an authentication problem
    static func isAuthError(_ message: String) -> Bool {
        let authKeywords = [
            "invalid access token",
            "invalid token",
            "expired",
            "authentication",
            "unauthorized",
            "not authorized",
            "invalid credentials",
            "token is invalid"
        ]
        let lowercased = message.lowercased()
        return authKeywords.contains { lowercased.contains($0) }
    }
}

struct CloudflareAPIResponse<T: Decodable>: Decodable {
    let success: Bool
    let errors: [CloudflareError]
    let messages: [String]
    let result: T?
    let resultInfo: ResultInfo?

    enum CodingKeys: String, CodingKey {
        case success, errors, messages, result
        case resultInfo = "result_info"
    }
}

struct CloudflareError: Decodable {
    let code: Int
    let message: String
}

struct ResultInfo: Decodable {
    let page: Int?
    let perPage: Int?
    let totalCount: Int?
    let totalPages: Int?
    let count: Int?

    enum CodingKeys: String, CodingKey {
        case page
        case perPage = "per_page"
        case totalCount = "total_count"
        case totalPages = "total_pages"
        case count
    }
}

// R2 has a nested response structure
struct R2BucketsResponse: Decodable {
    let buckets: [R2Bucket]
}

class CloudflareAPIClient {
    static let shared = CloudflareAPIClient()
    static let diagnosticsEnabledKey = "diagnosticsEnabled"

    private let baseURL = "https://api.cloudflare.com/client/v4"
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        session = URLSession(configuration: config)
    }

    private static func normalizeFractionalSeconds(_ dateString: String) -> String? {
        guard let dotIndex = dateString.firstIndex(of: ".") else { return nil }
        let fractionStart = dateString.index(after: dotIndex)
        guard let zoneIndex = dateString[fractionStart...].firstIndex(where: { $0 == "Z" || $0 == "+" || $0 == "-" }) else {
            return nil
        }
        let fraction = dateString[fractionStart..<zoneIndex]
        guard !fraction.isEmpty else { return nil }
        let trimmed = String(fraction.prefix(3))
        let padded = trimmed.padding(toLength: 3, withPad: "0", startingAt: 0)
        let prefix = String(dateString[..<fractionStart])
        let suffix = String(dateString[zoneIndex...])
        return prefix + padded + suffix
    }

    @discardableResult
    private static func logDecodingFailure(
        endpoint: String,
        data: Data,
        response: HTTPURLResponse?,
        error: Error
    ) -> URL? {
        guard UserDefaults.standard.bool(forKey: diagnosticsEnabledKey) else { return nil }
        guard let logURL = diagnosticsLogURL() else { return nil }

        let timestampFormatter = ISO8601DateFormatter()
        timestampFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let previewData = data.prefix(300)
        let previewText = String(data: previewData, encoding: .utf8) ?? "<binary data>"
        let previewBase64 = previewData.base64EncodedString()
        let statusCode = response?.statusCode ?? -1
        let contentType = response?.value(forHTTPHeaderField: "Content-Type") ?? "unknown"

        let entry = """
        -----
        Time: \(timestampFormatter.string(from: Date()))
        Endpoint: \(endpoint)
        Status: \(statusCode)
        Content-Type: \(contentType)
        Error: \(error)
        Preview(utf8): \(previewText)
        Preview(base64): \(previewBase64)

        """

        appendDiagnostics(entry, to: logURL)
        return logURL
    }

    static func diagnosticsLogURL() -> URL? {
        let fileManager = FileManager.default
        guard let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let folderName = Bundle.main.bundleIdentifier ?? "CloudflareStatusBar"
        let folderURL = baseURL.appendingPathComponent(folderName, isDirectory: true)
        do {
            try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
        } catch {
            return nil
        }
        return folderURL.appendingPathComponent("diagnostics.log")
    }

    private static func appendDiagnostics(_ entry: String, to url: URL) {
        let data = Data(entry.utf8)
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                let handle = try FileHandle(forWritingTo: url)
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
                try handle.close()
            } catch {
                // Diagnostics should never break the main flow.
            }
        } else {
            try? data.write(to: url, options: .atomic)
        }
    }

    private func makeRequest<T: Decodable>(endpoint: String, method: String = "GET") async throws -> T {
        let credentials = ProfileService.shared.getActiveCredentials()

        guard let authHeader = credentials.authorizationHeader else {
            throw CloudflareAPIError.notAuthenticated
        }

        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw CloudflareAPIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw CloudflareAPIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CloudflareAPIError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw CloudflareAPIError.notAuthenticated
        }

        // Validate Content-Type before attempting to decode
        let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type")
        let isJSON = contentType?.lowercased().contains("application/json") ?? false

        if !isJSON {
            // Response is not JSON - likely a proxy/firewall HTML page
            let preview = String(data: data.prefix(200), encoding: .utf8) ?? "<binary data>"
            throw CloudflareAPIError.unexpectedContentType(contentType, preview)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { @Sendable decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            let fractionalFormatter = ISO8601DateFormatter()
            fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let standardFormatter = ISO8601DateFormatter()
            standardFormatter.formatOptions = [.withInternetDateTime]

            if let date = fractionalFormatter.date(from: dateString) {
                return date
            }
            if let normalized = Self.normalizeFractionalSeconds(dateString),
               let date = fractionalFormatter.date(from: normalized) {
                return date
            }
            if let date = standardFormatter.date(from: dateString) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(dateString)")
        }

        do {
            let apiResponse = try decoder.decode(CloudflareAPIResponse<T>.self, from: data)

            if !apiResponse.success {
                let errorMessage = apiResponse.errors.map { $0.message }.joined(separator: ", ")
                // Check if this is an authentication error
                if CloudflareAPIError.isAuthError(errorMessage) {
                    throw CloudflareAPIError.tokenExpired
                }
                throw CloudflareAPIError.apiError(errorMessage.isEmpty ? "Unknown error" : errorMessage)
            }

            guard let result = apiResponse.result else {
                throw CloudflareAPIError.invalidResponse
            }

            return result
        } catch let error as CloudflareAPIError {
            throw error
        } catch let error as DecodingError {
            // Include data preview for debugging
            let preview = String(data: data.prefix(300), encoding: .utf8) ?? "<binary data>"
            if let logURL = Self.logDecodingFailure(endpoint: endpoint, data: data, response: httpResponse, error: error) {
                let previewWithLog = "\(preview)\nDiagnostics log: \(logURL.path)"
                throw CloudflareAPIError.decodingErrorWithPreview(error, previewWithLog)
            }
            throw CloudflareAPIError.decodingErrorWithPreview(error, preview)
        } catch {
            throw CloudflareAPIError.networkError(error)
        }
    }

    // MARK: - Account

    func getAccounts() async throws -> [Account] {
        try await makeRequest(endpoint: "/accounts")
    }

    func getAccountDetails(accountId: String) async throws -> Account {
        try await makeRequest(endpoint: "/accounts/\(accountId)")
    }

    // MARK: - Workers

    func getWorkers(accountId: String) async throws -> [Worker] {
        try await makeRequest(endpoint: "/accounts/\(accountId)/workers/scripts")
    }

    func getWorkerDetails(accountId: String, scriptName: String) async throws -> WorkerDetails {
        try await makeRequest(endpoint: "/accounts/\(accountId)/workers/scripts/\(scriptName)")
    }

    // MARK: - Pages

    func getPagesProjects(accountId: String) async throws -> [PagesProject] {
        try await makeRequest(endpoint: "/accounts/\(accountId)/pages/projects")
    }

    func getPagesDeployments(accountId: String, projectName: String) async throws -> [PagesDeployment] {
        try await makeRequest(endpoint: "/accounts/\(accountId)/pages/projects/\(projectName)/deployments")
    }

    // MARK: - KV Namespaces

    func getKVNamespaces(accountId: String) async throws -> [KVNamespace] {
        try await makeRequest(endpoint: "/accounts/\(accountId)/storage/kv/namespaces")
    }

    // MARK: - R2 Buckets

    func getR2Buckets(accountId: String) async throws -> [R2Bucket] {
        let response: R2BucketsResponse = try await makeRequest(endpoint: "/accounts/\(accountId)/r2/buckets")
        return response.buckets
    }

    // MARK: - D1 Databases

    func getD1Databases(accountId: String) async throws -> [D1Database] {
        try await makeRequest(endpoint: "/accounts/\(accountId)/d1/database")
    }

    // MARK: - Queues

    func getQueues(accountId: String) async throws -> [Queue] {
        try await makeRequest(endpoint: "/accounts/\(accountId)/queues")
    }
}
