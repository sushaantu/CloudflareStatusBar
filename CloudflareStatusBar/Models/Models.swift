import Foundation

// MARK: - Account

struct Account: Codable, Identifiable {
    let id: String
    let name: String
    let type: String?
    let settings: AccountSettings?

    struct AccountSettings: Codable {
        let enforceTwofactor: Bool?

        enum CodingKeys: String, CodingKey {
            case enforceTwofactor = "enforce_twofactor"
        }
    }
}

// MARK: - Worker

struct Worker: Codable, Identifiable {
    let id: String
    let etag: String?
    let handlers: [String]?
    let modifiedOn: Date?
    let createdOn: Date?
    let usageModel: String?
    let compatibilityDate: String?

    enum CodingKeys: String, CodingKey {
        case id, etag, handlers
        case modifiedOn = "modified_on"
        case createdOn = "created_on"
        case usageModel = "usage_model"
        case compatibilityDate = "compatibility_date"
    }

    var name: String { id }
}

struct WorkerDetails: Codable {
    let id: String
    let etag: String?
    let size: Int?
    let modifiedOn: Date?

    enum CodingKeys: String, CodingKey {
        case id, etag, size
        case modifiedOn = "modified_on"
    }
}

// MARK: - Pages

struct PagesProject: Codable, Identifiable {
    let id: String
    let name: String
    let subdomain: String?
    let domains: [String]?
    let source: PagesSource?
    let buildConfig: PagesBuildConfig?
    let deploymentConfigs: DeploymentConfigs?
    let latestDeployment: PagesDeployment?
    let canonicalDeployment: PagesDeployment?
    let productionBranch: String?
    let createdOn: Date?
    let modifiedOn: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, subdomain, domains, source
        case buildConfig = "build_config"
        case deploymentConfigs = "deployment_configs"
        case latestDeployment = "latest_deployment"
        case canonicalDeployment = "canonical_deployment"
        case productionBranch = "production_branch"
        case createdOn = "created_on"
        case modifiedOn = "modified_on"
    }
}

struct PagesSource: Codable {
    let type: String?
    let config: PagesSourceConfig?
}

struct PagesSourceConfig: Codable {
    let owner: String?
    let repoName: String?
    let productionBranch: String?
    let prCommentsEnabled: Bool?
    let deploymentsEnabled: Bool?

    enum CodingKeys: String, CodingKey {
        case owner
        case repoName = "repo_name"
        case productionBranch = "production_branch"
        case prCommentsEnabled = "pr_comments_enabled"
        case deploymentsEnabled = "deployments_enabled"
    }
}

struct PagesBuildConfig: Codable {
    let buildCommand: String?
    let destinationDir: String?
    let rootDir: String?

    enum CodingKeys: String, CodingKey {
        case buildCommand = "build_command"
        case destinationDir = "destination_dir"
        case rootDir = "root_dir"
    }
}

struct DeploymentConfigs: Codable {
    let preview: DeploymentConfig?
    let production: DeploymentConfig?
}

struct DeploymentConfig: Codable {
    let compatibilityDate: String?
    let compatibilityFlags: [String]?

    enum CodingKeys: String, CodingKey {
        case compatibilityDate = "compatibility_date"
        case compatibilityFlags = "compatibility_flags"
    }
}

struct PagesDeployment: Codable, Identifiable {
    let id: String
    let shortId: String?
    let projectId: String?
    let projectName: String?
    let environment: String?
    let url: String?
    let createdOn: Date?
    let modifiedOn: Date?
    let deploymentTrigger: DeploymentTrigger?
    let latestStage: DeploymentStage?
    let stages: [DeploymentStage]?
    let buildConfig: PagesBuildConfig?
    let source: PagesSource?
    let isSkipped: Bool?
    let productionBranch: String?

    enum CodingKeys: String, CodingKey {
        case id
        case shortId = "short_id"
        case projectId = "project_id"
        case projectName = "project_name"
        case environment, url
        case createdOn = "created_on"
        case modifiedOn = "modified_on"
        case deploymentTrigger = "deployment_trigger"
        case latestStage = "latest_stage"
        case stages
        case buildConfig = "build_config"
        case source
        case isSkipped = "is_skipped"
        case productionBranch = "production_branch"
    }

    var status: DeploymentStatus {
        guard let stage = latestStage else { return .unknown }
        return DeploymentStatus(rawValue: stage.status ?? "") ?? .unknown
    }
}

struct DeploymentTrigger: Codable {
    let type: String?
    let metadata: TriggerMetadata?
}

struct TriggerMetadata: Codable {
    let branch: String?
    let commitHash: String?
    let commitMessage: String?

    enum CodingKeys: String, CodingKey {
        case branch
        case commitHash = "commit_hash"
        case commitMessage = "commit_message"
    }
}

struct DeploymentStage: Codable {
    let name: String?
    let status: String?
    let startedOn: Date?
    let endedOn: Date?

    enum CodingKeys: String, CodingKey {
        case name, status
        case startedOn = "started_on"
        case endedOn = "ended_on"
    }
}

enum DeploymentStatus: String, Codable {
    case idle
    case active
    case success
    case failure
    case canceled
    case unknown

    var displayName: String {
        switch self {
        case .idle: return "Idle"
        case .active: return "Deploying"
        case .success: return "Success"
        case .failure: return "Failed"
        case .canceled: return "Canceled"
        case .unknown: return "Unknown"
        }
    }

    var iconName: String {
        switch self {
        case .idle: return "circle"
        case .active: return "arrow.triangle.2.circlepath"
        case .success: return "checkmark.circle.fill"
        case .failure: return "xmark.circle.fill"
        case .canceled: return "minus.circle.fill"
        case .unknown: return "questionmark.circle"
        }
    }

    var color: String {
        switch self {
        case .idle: return "gray"
        case .active: return "blue"
        case .success: return "green"
        case .failure: return "red"
        case .canceled: return "orange"
        case .unknown: return "gray"
        }
    }
}

// MARK: - KV Namespace

struct KVNamespace: Codable, Identifiable {
    let id: String
    let title: String
    let supportsUrlEncoding: Bool?

    enum CodingKeys: String, CodingKey {
        case id, title
        case supportsUrlEncoding = "supports_url_encoding"
    }

    var name: String { title }
}

// MARK: - R2 Bucket

struct R2Bucket: Codable, Identifiable {
    let name: String
    let creationDate: Date?
    let location: String?

    var id: String { name }

    enum CodingKeys: String, CodingKey {
        case name
        case creationDate = "creation_date"
        case location
    }
}

// MARK: - D1 Database

struct D1Database: Codable, Identifiable {
    let uuid: String
    let name: String
    let version: String?
    let numTables: Int?
    let fileSize: Int?
    let createdAt: Date?

    var id: String { uuid }

    enum CodingKeys: String, CodingKey {
        case uuid, name, version
        case numTables = "num_tables"
        case fileSize = "file_size"
        case createdAt = "created_at"
    }
}

// MARK: - Queue

struct Queue: Codable, Identifiable {
    let queueId: String
    let queueName: String
    let createdOn: Date?
    let modifiedOn: Date?
    let producers: [QueueProducer]?
    let consumers: [QueueConsumer]?
    let producersTotalCount: Int?
    let consumersTotalCount: Int?

    var id: String { queueId }
    var name: String { queueName }

    enum CodingKeys: String, CodingKey {
        case queueId = "queue_id"
        case queueName = "queue_name"
        case createdOn = "created_on"
        case modifiedOn = "modified_on"
        case producers, consumers
        case producersTotalCount = "producers_total_count"
        case consumersTotalCount = "consumers_total_count"
    }
}

struct QueueProducer: Codable {
    let service: String?
    let environment: String?
}

struct QueueConsumer: Codable {
    let service: String?
    let environment: String?
    let deadLetterQueue: String?

    enum CodingKeys: String, CodingKey {
        case service, environment
        case deadLetterQueue = "dead_letter_queue"
    }
}

// MARK: - App State

struct CloudflareState {
    var isAuthenticated: Bool = false
    var isLoading: Bool = false
    var error: String?
    var lastRefresh: Date?

    var accounts: [Account] = []
    var selectedAccountId: String?
    var workers: [Worker] = []
    var pagesProjects: [PagesProject] = []
    var kvNamespaces: [KVNamespace] = []
    var r2Buckets: [R2Bucket] = []
    var d1Databases: [D1Database] = []
    var queues: [Queue] = []

    // Track deployment states for notifications
    var previousDeploymentStates: [String: DeploymentStatus] = [:]

    var selectedAccount: Account? {
        if let selectedId = selectedAccountId {
            return accounts.first { $0.id == selectedId }
        }
        return accounts.first
    }
}
