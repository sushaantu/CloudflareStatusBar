import Foundation
import Combine
import AppKit

@MainActor
class CloudflareViewModel: ObservableObject {
    @Published var state = CloudflareState()
    @Published var selectedTab: Tab = .overview

    private var refreshTimer: Timer?
    private var refreshTask: Task<Void, Never>?
    private let refreshInterval: TimeInterval = 300 // 5 minutes
    private let usageRefreshInterval: TimeInterval = 900 // 15 minutes
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
        state.usageMetrics = nil
        state.usageError = nil
        state.recentActivity = []

        // Refresh data for the new account
        requestRefresh()
    }

    func checkAuthentication() {
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let credentials = await ProfileService.shared.getActiveCredentialsAsync()
            let activeProfile = await ProfileService.shared.getActiveProfileAsync()
            let isAuthenticated = credentials.isAuthenticated

            await MainActor.run {
                self.state.isAuthenticated = isAuthenticated
                self.state.activeProfile = activeProfile
            }

            if isAuthenticated {
                await MainActor.run {
                    self.requestRefresh()
                }
            }
        }
    }

    func onProfileChanged() {
        // Clear current data and re-authenticate with new profile
        refreshTask?.cancel()
        state.accounts = []
        state.workers = []
        state.pagesProjects = []
        state.kvNamespaces = []
        state.r2Buckets = []
        state.d1Databases = []
        state.queues = []
        state.usageMetrics = nil
        state.usageError = nil
        state.recentActivity = []
        state.error = nil

        checkAuthentication()
    }

    func startAutoRefresh() {
        stopAutoRefresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.requestRefresh()
            }
        }
    }

    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        refreshTask?.cancel()
    }

    func requestRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            await self?.refresh()
        }
    }

    func refresh() async {
        guard state.isAuthenticated else { return }

        state.isLoading = true
        state.error = nil
        defer { state.isLoading = false }

        do {
            // First, get account info
            let accounts: [Account] = try await api.getAccounts()
            if Task.isCancelled { return }

            guard !accounts.isEmpty else {
                state.error = "No accounts found"
                return
            }

            state.accounts = accounts

            // Use selected account or fall back to first
            guard let account = state.selectedAccount else {
                state.error = "No account selected"
                return
            }

            // Update notification service with accountId for deep links
            NotificationService.shared.accountId = account.id

            var loadedWorkers = false
            var loadedPages = false
            var loadedStorage = false
            var loadedUsage = false

            switch selectedTab {
            case .overview:
                async let workersTask = api.getWorkers(accountId: account.id)
                async let pagesTask = api.getPagesProjects(accountId: account.id)
                async let usageTask = fetchUsageMetrics(accountId: account.id)

                let (workers, pages, usage) = try await (workersTask, pagesTask, usageTask)
                if Task.isCancelled { return }

                state.workers = workers
                state.pagesProjects = pages
                state.usageMetrics = usage
                loadedWorkers = true
                loadedPages = true
                loadedUsage = true

                checkDeploymentChanges(pages: pages)
                updateRecentActivity()
            case .workers:
                let workers = try await api.getWorkers(accountId: account.id)
                if Task.isCancelled { return }
                state.workers = workers
                loadedWorkers = true
                updateRecentActivity()
            case .pages:
                let pages = try await api.getPagesProjects(accountId: account.id)
                if Task.isCancelled { return }
                state.pagesProjects = pages
                loadedPages = true
                checkDeploymentChanges(pages: pages)
                updateRecentActivity()
            case .storage:
                async let kvTask = api.getKVNamespaces(accountId: account.id)
                async let r2Task = fetchR2Buckets(accountId: account.id)
                async let d1Task = fetchD1Databases(accountId: account.id)
                async let queuesTask = fetchQueues(accountId: account.id)

                let (kv, r2, d1, queues) = try await (kvTask, r2Task, d1Task, queuesTask)
                if Task.isCancelled { return }
                state.kvNamespaces = kv
                state.r2Buckets = r2
                state.d1Databases = d1
                state.queues = queues
                loadedStorage = true
            }

            if Task.isCancelled { return }
            state.isLoading = false

            if !loadedWorkers {
                let workers = await fetchWorkersSafe(accountId: account.id)
                if Task.isCancelled { return }
                state.workers = workers
                updateRecentActivity()
            }

            if !loadedPages {
                let pages = await fetchPagesSafe(accountId: account.id)
                if Task.isCancelled { return }
                state.pagesProjects = pages
                checkDeploymentChanges(pages: pages)
                updateRecentActivity()
            }

            if !loadedStorage {
                async let kvTask = fetchKVNamespacesSafe(accountId: account.id)
                async let r2Task = fetchR2Buckets(accountId: account.id)
                async let d1Task = fetchD1Databases(accountId: account.id)
                async let queuesTask = fetchQueues(accountId: account.id)

                let (kv, r2, d1, queues) = await (kvTask, r2Task, d1Task, queuesTask)
                if Task.isCancelled { return }
                state.kvNamespaces = kv
                state.r2Buckets = r2
                state.d1Databases = d1
                state.queues = queues
            }

            if !loadedUsage {
                state.usageMetrics = await fetchUsageMetrics(accountId: account.id)
            }

            state.lastRefresh = Date()
        } catch is CancellationError {
            return
        } catch let error as CloudflareAPIError {
            state.error = error.errorDescription
        } catch {
            state.error = error.localizedDescription
        }
    }

    // Wrapper functions that keep existing data on error (for optional resources)
    private func fetchWorkersSafe(accountId: String) async -> [Worker] {
        do {
            return try await api.getWorkers(accountId: accountId)
        } catch {
            return state.workers
        }
    }

    private func fetchPagesSafe(accountId: String) async -> [PagesProject] {
        do {
            return try await api.getPagesProjects(accountId: accountId)
        } catch {
            return state.pagesProjects
        }
    }

    private func fetchKVNamespacesSafe(accountId: String) async -> [KVNamespace] {
        do {
            return try await api.getKVNamespaces(accountId: accountId)
        } catch {
            return state.kvNamespaces
        }
    }

    private func fetchR2Buckets(accountId: String) async -> [R2Bucket] {
        do {
            return try await api.getR2Buckets(accountId: accountId)
        } catch {
            return state.r2Buckets
        }
    }

    private func fetchD1Databases(accountId: String) async -> [D1Database] {
        do {
            return try await api.getD1Databases(accountId: accountId)
        } catch {
            return state.d1Databases
        }
    }

    private func fetchQueues(accountId: String) async -> [Queue] {
        do {
            return try await api.getQueues(accountId: accountId)
        } catch {
            return state.queues
        }
    }

    private func fetchUsageMetrics(accountId: String) async -> UsageMetrics? {
        guard isUsageRefreshDue() else { return state.usageMetrics }
        do {
            let metrics = try await api.getUsageMetrics(accountId: accountId)
            state.usageError = nil
            return metrics
        } catch is CancellationError {
            return state.usageMetrics
        } catch let error as CloudflareAPIError {
            switch error {
            case .apiError(let message):
                let lowercased = message.lowercased()
                if lowercased.contains("permission") || lowercased.contains("unauthorized") {
                    state.usageError = "Analytics permission missing for this token."
                } else {
                    state.usageError = message
                }
            case .notAuthenticated, .tokenExpired:
                state.usageError = "Usage metrics require a valid session."
            default:
                state.usageError = "Usage data unavailable."
            }
            return state.usageMetrics
        } catch {
            state.usageError = "Usage data unavailable."
            return state.usageMetrics
        }
    }

    private func isUsageRefreshDue() -> Bool {
        guard let metrics = state.usageMetrics else { return true }

        let now = Date()
        let startOfTodayUTC = startOfDayUTC(for: now)

        if let periodStart = metrics.periodStart {
            if abs(periodStart.timeIntervalSince(startOfTodayUTC)) > 1 {
                return true
            }
        } else {
            return true
        }

        guard let lastUpdated = metrics.lastUpdated else { return true }
        return now.timeIntervalSince(lastUpdated) >= usageRefreshInterval
    }

    private func startOfDayUTC(for date: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        let utc = TimeZone(secondsFromGMT: 0) ?? TimeZone(abbreviation: "GMT")!
        calendar.timeZone = utc
        return calendar.startOfDay(for: date)
    }

    private func updateRecentActivity() {
        var items: [ActivityItem] = []

        for worker in state.workers {
            items.append(ActivityItem(
                id: "worker-\(worker.id)",
                name: worker.name,
                type: .worker,
                date: worker.modifiedOn ?? worker.createdOn,
                status: nil,
                subtitle: nil,
                url: nil
            ))
        }

        for project in state.pagesProjects {
            let deployment = project.latestDeployment
            items.append(ActivityItem(
                id: "pages-\(project.id)",
                name: project.name,
                type: .pages,
                date: deployment?.createdOn ?? project.modifiedOn,
                status: deployment?.status,
                subtitle: deployment?.deploymentTrigger?.metadata?.branch,
                url: deployment?.url
            ))
        }

        state.recentActivity = items.sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
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
