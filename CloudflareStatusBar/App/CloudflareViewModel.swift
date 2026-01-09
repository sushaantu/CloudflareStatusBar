import Foundation
import Combine
import AppKit

@MainActor
class CloudflareViewModel: ObservableObject {
    @Published var state = CloudflareState()
    @Published var selectedTab: Tab = .overview

    private var refreshTimer: Timer?
    private let refreshInterval: TimeInterval = 300 // 5 minutes
    private let api = CloudflareAPIClient.shared

    enum Tab: String, CaseIterable {
        case overview = "Overview"
        case workers = "Workers"
        case pages = "Pages"
        case storage = "Storage"
    }

    init() {
        checkAuthentication()
    }

    func checkAuthentication() {
        let credentials = WranglerAuthService.shared.loadCredentials()
        state.isAuthenticated = credentials.isAuthenticated

        if state.isAuthenticated {
            Task {
                await refresh()
            }
        }
    }

    func startAutoRefresh() {
        stopAutoRefresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refresh()
            }
        }
    }

    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    func refresh() async {
        guard state.isAuthenticated else { return }

        state.isLoading = true
        state.error = nil

        do {
            // First, get account info
            let accounts: [Account] = try await api.getAccounts()

            guard let account = accounts.first else {
                state.error = "No accounts found"
                state.isLoading = false
                return
            }

            state.account = account

            // Update notification service with accountId for deep links
            NotificationService.shared.accountId = account.id

            // Fetch all resources in parallel
            async let workersTask = api.getWorkers(accountId: account.id)
            async let pagesTask = api.getPagesProjects(accountId: account.id)
            async let kvTask = api.getKVNamespaces(accountId: account.id)
            async let r2Task = fetchR2Buckets(accountId: account.id)
            async let d1Task = fetchD1Databases(accountId: account.id)
            async let queuesTask = fetchQueues(accountId: account.id)

            let (workers, pages, kv, r2, d1, queues) = try await (
                workersTask,
                pagesTask,
                kvTask,
                r2Task,
                d1Task,
                queuesTask
            )

            state.workers = workers
            state.pagesProjects = pages
            state.kvNamespaces = kv
            state.r2Buckets = r2
            state.d1Databases = d1
            state.queues = queues

            // Check for deployment status changes and send notifications
            checkDeploymentChanges(pages: pages)

            state.lastRefresh = Date()
        } catch let error as CloudflareAPIError {
            state.error = error.errorDescription
        } catch {
            state.error = error.localizedDescription
        }

        state.isLoading = false
    }

    // Wrapper functions that return empty arrays on error (for optional resources)
    private func fetchR2Buckets(accountId: String) async -> [R2Bucket] {
        do {
            return try await api.getR2Buckets(accountId: accountId)
        } catch {
            return []
        }
    }

    private func fetchD1Databases(accountId: String) async -> [D1Database] {
        do {
            return try await api.getD1Databases(accountId: accountId)
        } catch {
            return []
        }
    }

    private func fetchQueues(accountId: String) async -> [Queue] {
        do {
            return try await api.getQueues(accountId: accountId)
        } catch {
            return []
        }
    }

    private func checkDeploymentChanges(pages: [PagesProject]) {
        for project in pages {
            guard let deployment = project.latestDeployment else { continue }

            let currentStatus = deployment.status
            let previousStatus = state.previousDeploymentStates[deployment.id]

            // Only notify if status changed and it's a meaningful change
            if previousStatus != nil && previousStatus != currentStatus {
                if currentStatus == .success || currentStatus == .failure {
                    NotificationService.shared.sendDeploymentNotification(
                        projectName: project.name,
                        status: currentStatus,
                        environment: deployment.environment
                    )
                }
            }

            state.previousDeploymentStates[deployment.id] = currentStatus
        }
    }

    func openDashboard() {
        if let url = URL(string: "https://dash.cloudflare.com") {
            NSWorkspace.shared.open(url)
        }
    }

    func openWorkersDashboard() {
        guard let accountId = state.account?.id else { return }
        if let url = URL(string: "https://dash.cloudflare.com/\(accountId)/workers") {
            NSWorkspace.shared.open(url)
        }
    }

    func openPagesDashboard() {
        guard let accountId = state.account?.id else { return }
        if let url = URL(string: "https://dash.cloudflare.com/\(accountId)/pages") {
            NSWorkspace.shared.open(url)
        }
    }

    func openStorageDashboard() {
        guard let accountId = state.account?.id else { return }
        if let url = URL(string: "https://dash.cloudflare.com/\(accountId)/r2") {
            NSWorkspace.shared.open(url)
        }
    }

    func quit() {
        NSApplication.shared.terminate(nil)
    }
}
