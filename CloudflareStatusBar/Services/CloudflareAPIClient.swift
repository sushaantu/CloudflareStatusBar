import Foundation

enum CloudflareAPIError: Error, LocalizedError {
    case notAuthenticated
    case networkError(Error)
    case invalidResponse
    case apiError(String)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated. Please run 'wrangler login' first."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from Cloudflare API"
        case .apiError(let message):
            return "API error: \(message)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        }
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
    let page: Int
    let perPage: Int
    let totalCount: Int
    let totalPages: Int

    enum CodingKeys: String, CodingKey {
        case page
        case perPage = "per_page"
        case totalCount = "total_count"
        case totalPages = "total_pages"
    }
}

class CloudflareAPIClient {
    static let shared = CloudflareAPIClient()

    private let baseURL = "https://api.cloudflare.com/client/v4"
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        session = URLSession(configuration: config)
    }

    private func makeRequest<T: Decodable>(endpoint: String, method: String = "GET") async throws -> T {
        let credentials = WranglerAuthService.shared.loadCredentials()

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

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw CloudflareAPIError.invalidResponse
            }

            if httpResponse.statusCode == 401 {
                throw CloudflareAPIError.notAuthenticated
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let apiResponse = try decoder.decode(CloudflareAPIResponse<T>.self, from: data)

            if !apiResponse.success {
                let errorMessage = apiResponse.errors.map { $0.message }.joined(separator: ", ")
                throw CloudflareAPIError.apiError(errorMessage.isEmpty ? "Unknown error" : errorMessage)
            }

            guard let result = apiResponse.result else {
                throw CloudflareAPIError.invalidResponse
            }

            return result
        } catch let error as CloudflareAPIError {
            throw error
        } catch let error as DecodingError {
            throw CloudflareAPIError.decodingError(error)
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
        try await makeRequest(endpoint: "/accounts/\(accountId)/r2/buckets")
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
