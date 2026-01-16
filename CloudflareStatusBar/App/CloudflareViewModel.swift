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
    private let selectedAccountKey = "selectedAccountId"

    enum Tab: String, CaseIterable {
        case overview = "Overview"
        case workers = "Workers"
        case pages = "Pages"
        case storage = "Storage"
    }

    init() {
        // Load saved account selection
        state.selectedAccountId = UserDefaults.standard.string(forKey: selectedAccountKey)
        checkAuthentication()
    }

    func selectAccount(_ accountId: String) {
        state.selectedAccountId = accountId
        UserDefaults.standard.set(accountId, forKey: selectedAccountKey)

        // Refresh data for the new account
        Task {
            await refresh()
        }
    }

    func checkAuthentication() {
        let credentials = ProfileService.shared.getActiveCredentials()
        state.isAuthenticated = credentials.isAuthenticated
        state.activeProfile = ProfileService.shared.getActiveProfile()

        if state.isAuthenticated {
            Task {
                await refresh()
            }
        }
    }

    func onProfileChanged() {
        // Clear current data and re-authenticate with new profile
        state.accounts = []
        state.workers = []
        state.pagesProjects = []
        state.kvNamespaces = []
        state.r2Buckets = []
        state.d1Databases = []
        state.queues = []
        state.error = nil

        checkAuthentication()
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

            guard !accounts.isEmpty else {
                state.error = "No accounts found"
                state.isLoading = false
                return
            }

            state.accounts = accounts

            // Use selected account or fall back to first
            guard let account = state.selectedAccount else {
                state.error = "No account selected"
                state.isLoading = false
                return
            }

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

    func openWebsite() {
        if let url = URL(string: "https://github.com/sushaantu/CloudflareStatusBar") {
            NSWorkspace.shared.open(url)
        }
    }

    func openWorkersDashboard() {
        guard let accountId = state.selectedAccount?.id else { return }
        if let url = URL(string: "https://dash.cloudflare.com/\(accountId)/workers") {
            NSWorkspace.shared.open(url)
        }
    }

    func openPagesDashboard() {
        guard let accountId = state.selectedAccount?.id else { return }
        if let url = URL(string: "https://dash.cloudflare.com/\(accountId)/pages") {
            NSWorkspace.shared.open(url)
        }
    }

    func openStorageDashboard() {
        guard let accountId = state.selectedAccount?.id else { return }
        if let url = URL(string: "https://dash.cloudflare.com/\(accountId)/r2") {
            NSWorkspace.shared.open(url)
        }
    }

    func quit() {
        NSApplication.shared.terminate(nil)
    }

    func checkForUpdates() {
        Task {
            await UpdateService.shared.checkForUpdates()
            if UpdateService.shared.updateAvailable {
                UpdateService.shared.showUpdateAlert()
            } else {
                // Show "up to date" message
                let alert = NSAlert()
                alert.messageText = "You're Up to Date"
                alert.informativeText = "CloudflareStatusBar \(UpdateService.shared.currentVersion) is the latest version."
                alert.alertStyle = .informational
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        }
    }
}
