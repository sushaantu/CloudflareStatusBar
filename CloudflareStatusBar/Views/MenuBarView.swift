import SwiftUI
import AppKit

struct MenuBarView: View {
    @ObservedObject var viewModel: CloudflareViewModel
    @State private var showingProfiles = false
    @AppStorage(CloudflareAPIClient.diagnosticsEnabledKey) private var diagnosticsEnabled = false

    private var accountId: String? {
        viewModel.state.selectedAccount?.id
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            if !viewModel.state.isAuthenticated {
                notAuthenticatedView
            } else if let error = viewModel.state.error {
                errorView(error: error)
            } else {
                // Tab selector
                tabSelector

                Divider()

                // Content based on selected tab
                ScrollView {
                    switch viewModel.selectedTab {
                    case .overview:
                        OverviewView(viewModel: viewModel, accountId: accountId)
                    case .workers:
                        WorkersView(workers: viewModel.state.workers, accountId: accountId)
                    case .pages:
                        PagesView(projects: viewModel.state.pagesProjects, accountId: accountId)
                    case .storage:
                        StorageView(
                            kvNamespaces: viewModel.state.kvNamespaces,
                            r2Buckets: viewModel.state.r2Buckets,
                            d1Databases: viewModel.state.d1Databases,
                            queues: viewModel.state.queues,
                            accountId: accountId
                        )
                    }
                }
                .frame(maxHeight: 320)
            }

            Divider()

            // Footer
            footerView
        }
        .frame(width: 360)
        .sheet(isPresented: $showingProfiles) {
            ProfilesView(onProfileChanged: {
                viewModel.onProfileChanged()
            })
        }
    }

    private var headerView: some View {
        HStack {
            Image(systemName: "cloud.fill")
                .font(.title2)
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Cloudflare")
                        .font(.headline)

                    // Profile indicator
                    if let profile = viewModel.state.activeProfile {
                        Button(action: { showingProfiles = true }) {
                            Text(profile.name)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.2))
                                .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                        .help("Switch Profile")
                    }
                }

                if viewModel.state.accounts.count > 1 {
                    // Show account picker when multiple accounts
                    Menu {
                        ForEach(viewModel.state.accounts) { account in
                            Button(action: { viewModel.selectAccount(account.id) }) {
                                HStack {
                                    Text(account.name)
                                    if account.id == viewModel.state.selectedAccount?.id {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(viewModel.state.selectedAccount?.name ?? "Select Account")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                } else if let account = viewModel.state.selectedAccount {
                    Text(account.name)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if viewModel.state.isLoading {
                ProgressView()
                    .scaleEffect(0.7)
            } else {
                Button(action: { viewModel.requestRefresh() }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .help("Refresh")
            }
        }
        .padding()
    }

    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(CloudflareViewModel.Tab.allCases, id: \.self) { tab in
                Button(action: { viewModel.selectedTab = tab }) {
                    Text(tab.rawValue)
                        .font(.caption)
                        .fontWeight(viewModel.selectedTab == tab ? .semibold : .regular)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            viewModel.selectedTab == tab ?
                            Color.accentColor.opacity(0.15) :
                            Color.clear
                        )
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private var notAuthenticatedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.largeTitle)
                .foregroundColor(.secondary)

            Text("Not Authenticated")
                .font(.headline)

            Text("Run `wrangler login` in your terminal\nor add a profile with an API token.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button("Add Profile") {
                    showingProfiles = true
                }
                .buttonStyle(.borderedProminent)

                Button("Check Again") {
                    viewModel.checkAuthentication()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(32)
    }

    private func errorView(error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)

            Text("Error")
                .font(.headline)

            Text(error)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            if diagnosticsEnabled, let logURL = CloudflareAPIClient.diagnosticsLogURL() {
                Button("Reveal Diagnostics Log") {
                    NSWorkspace.shared.activateFileViewerSelecting([logURL])
                }
                .buttonStyle(.bordered)

                Text(logURL.path)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
            }

            Button("Retry") {
                viewModel.requestRefresh()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(32)
    }

    private var footerView: some View {
        HStack {
            if let lastRefresh = viewModel.state.lastRefresh {
                Text("Updated \(lastRefresh.formatted(.relative(presentation: .named)))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: { showingProfiles = true }) {
                Image(systemName: "person.2")
            }
            .buttonStyle(.plain)
            .help("Manage Profiles")

            Button(action: viewModel.checkForUpdates) {
                Image(systemName: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(.plain)
            .help("Check for Updates")

            Button(action: { diagnosticsEnabled.toggle() }) {
                Image(systemName: diagnosticsEnabled ? "ladybug.fill" : "ladybug")
            }
            .buttonStyle(.plain)
            .help(diagnosticsEnabled ? "Diagnostics Logging On" : "Diagnostics Logging Off")

            Button(action: viewModel.openWebsite) {
                Image(systemName: "link")
            }
            .buttonStyle(.plain)
            .help("View on GitHub")

            Button(action: viewModel.openDashboard) {
                Image(systemName: "globe")
            }
            .buttonStyle(.plain)
            .help("Open Cloudflare Dashboard")

            Button(action: viewModel.quit) {
                Image(systemName: "power")
            }
            .buttonStyle(.plain)
            .help("Quit")
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

struct OverviewView: View {
    @ObservedObject var viewModel: CloudflareViewModel
    let accountId: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Recent Activity
            Text("Recent Activity")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            if viewModel.state.recentActivity.isEmpty {
                Text("No recent activity")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ForEach(viewModel.state.recentActivity.prefix(8), id: \.id) { item in
                    ActivityRow(item: item, accountId: accountId)
                }
            }

            Text(usageHeaderLine)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            if let usage = viewModel.state.usageMetrics, usage.hasAnyMetric {
                UsageMetricsView(usage: usage)
            }

            // Compact summary at bottom
            HStack(spacing: 16) {
                SummaryBadge(count: viewModel.state.workers.count, label: "Workers", icon: "server.rack")
                SummaryBadge(count: viewModel.state.pagesProjects.count, label: "Pages", icon: "doc.richtext")
                SummaryBadge(count: viewModel.state.kvNamespaces.count + viewModel.state.r2Buckets.count + viewModel.state.d1Databases.count, label: "Storage", icon: "externaldrive")
            }
            .padding(.top, 8)
        }
        .padding()
    }

    private var usageHeaderLine: String {
        var parts = ["Usage (UTC)"]

        if let usage = viewModel.state.usageMetrics, usage.hasAnyMetric {
            return parts.joined(separator: " · ")
        }

        if viewModel.state.isLoading {
            parts.append("Loading…")
            return parts.joined(separator: " · ")
        }

        if let usageError = viewModel.state.usageError {
            parts.append(compactUsageError(usageError))
            return parts.joined(separator: " · ")
        }

        parts.append("Unavailable")
        return parts.joined(separator: " · ")
    }

    private func compactUsageError(_ message: String) -> String {
        let lowercased = message.lowercased()

        if lowercased.contains("permission") {
            return "No analytics permission"
        }
        if lowercased.contains("session") || lowercased.contains("auth") {
            return "Not authenticated"
        }
        if lowercased.contains("unavailable") {
            return "Unavailable"
        }
        return message
    }

}

struct UsageMetricsView: View {
    let usage: UsageMetrics
    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            UsageMetricRow(
                icon: "server.rack",
                title: "Workers Requests",
                value: formatCount(usage.workersRequests),
                detail: nil
            )

            UsageMetricRow(
                icon: "key",
                title: "KV Reads / Writes",
                value: formatPair(usage.kvReads, usage.kvWrites),
                detail: kvExtras
            )

            UsageMetricRow(
                icon: "cylinder",
                title: "D1 Rows Read / Written",
                value: formatPair(usage.d1RowsRead, usage.d1RowsWritten),
                detail: nil
            )
        }
    }

    private var kvExtras: String? {
        var parts: [String] = []
        if let deletes = usage.kvDeletes, deletes > 0 {
            parts.append("Del \(formatCount(deletes))")
        }
        if let lists = usage.kvLists, lists > 0 {
            parts.append("List \(formatCount(lists))")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func formatPair(_ first: Int64?, _ second: Int64?) -> String {
        if first == nil && second == nil {
            return "—"
        }
        return "\(formatCount(first)) / \(formatCount(second))"
    }

    private func formatCount(_ value: Int64?) -> String {
        guard let value = value else { return "—" }
        return formatCompact(value)
    }

    private func formatCompact(_ value: Int64) -> String {
        let absValue = Double(abs(value))
        let sign = value < 0 ? "-" : ""

        switch absValue {
        case 1_000_000_000...:
            return sign + compact(absValue, divisor: 1_000_000_000, suffix: "B")
        case 1_000_000...:
            return sign + compact(absValue, divisor: 1_000_000, suffix: "M")
        case 1_000...:
            return sign + compact(absValue, divisor: 1_000, suffix: "k")
        default:
            return sign + formatNumber(absValue)
        }
    }

    private func compact(_ value: Double, divisor: Double, suffix: String) -> String {
        let scaled = value / divisor
        let format = scaled >= 10 ? "%.0f" : "%.1f"
        var text = String(format: format, scaled)
        if text.hasSuffix(".0") {
            text.removeLast(2)
        }
        return text + suffix
    }

    private func formatNumber(_ value: Double) -> String {
        Self.numberFormatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }

}

struct UsageMetricRow: View {
    let icon: String
    let title: String
    let value: String
    let detail: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                if let detail = detail {
                    Text(detail)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(6)
    }
}

extension ActivityType {
    var icon: String {
        switch self {
        case .worker: return "server.rack"
        case .pages: return "doc.richtext"
        }
    }

    var color: Color {
        switch self {
        case .worker: return .blue
        case .pages: return .purple
        }
    }
}

struct ActivityRow: View {
    let item: ActivityItem
    let accountId: String?

    @State private var isHovered = false

    var body: some View {
        Button(action: openInDashboard) {
            HStack(spacing: 10) {
                Image(systemName: item.type.icon)
                    .font(.caption)
                    .foregroundColor(item.type.color)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 1) {
                    Text(item.name)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    if let subtitle = item.subtitle {
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                if let status = item.status {
                    Image(systemName: status.iconName)
                        .font(.caption2)
                        .foregroundColor(statusColor(status))
                }

                if let date = item.date {
                    Text(date.formatted(.relative(presentation: .named)))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Image(systemName: "arrow.up.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .opacity(isHovered ? 1 : 0)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(isHovered ? Color.accentColor.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }

    private func openInDashboard() {
        guard let accountId = accountId else { return }
        let urlString: String
        switch item.type {
        case .worker:
            urlString = "https://dash.cloudflare.com/\(accountId)/workers/services/view/\(item.name)/production"
        case .pages:
            urlString = "https://dash.cloudflare.com/\(accountId)/pages/view/\(item.name)"
        }
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }

    private func statusColor(_ status: DeploymentStatus) -> Color {
        switch status {
        case .success: return .green
        case .failure: return .red
        case .active: return .blue
        case .canceled: return .orange
        default: return .gray
        }
    }
}

struct SummaryBadge: View {
    let count: Int
    let label: String
    let icon: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text("\(count)")
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

struct StatCard: View {
    let title: String
    let count: Int
    let icon: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(count)")
                    .font(.headline)

                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct DeploymentRow: View {
    let deployment: PagesDeployment

    var body: some View {
        HStack {
            Image(systemName: deployment.status.iconName)
                .foregroundColor(statusColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(deployment.projectName ?? "Unknown")
                    .font(.caption)
                    .fontWeight(.medium)

                if let branch = deployment.deploymentTrigger?.metadata?.branch {
                    Text(branch)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if let date = deployment.createdOn {
                Text(date.formatted(.relative(presentation: .named)))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(6)
    }

    private var statusColor: Color {
        switch deployment.status {
        case .success: return .green
        case .failure: return .red
        case .active: return .blue
        case .canceled: return .orange
        default: return .gray
        }
    }
}
