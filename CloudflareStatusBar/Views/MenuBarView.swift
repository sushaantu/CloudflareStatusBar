import SwiftUI
import AppKit

struct MenuBarView: View {
    @ObservedObject var viewModel: CloudflareViewModel

    private var accountId: String? {
        viewModel.state.account?.id
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
    }

    private var headerView: some View {
        HStack {
            Image(systemName: "cloud.fill")
                .font(.title2)
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("Cloudflare")
                    .font(.headline)

                if let account = viewModel.state.account {
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
                Button(action: { Task { await viewModel.refresh() } }) {
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

            Text("Run `wrangler login` in your terminal to authenticate with Cloudflare.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Check Again") {
                viewModel.checkAuthentication()
            }
            .buttonStyle(.borderedProminent)
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

            Button("Retry") {
                Task { await viewModel.refresh() }
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

            if recentActivity.isEmpty {
                Text("No recent activity")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ForEach(recentActivity.prefix(8), id: \.id) { item in
                    ActivityRow(item: item, accountId: accountId)
                }
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

    private var recentActivity: [ActivityItem] {
        var items: [ActivityItem] = []

        // Add workers with modification dates
        for worker in viewModel.state.workers {
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

        // Add pages projects with their latest deployment info
        for project in viewModel.state.pagesProjects {
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

        // Sort by most recent
        return items.sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
    }
}

struct ActivityItem {
    let id: String
    let name: String
    let type: ActivityType
    let date: Date?
    let status: DeploymentStatus?
    let subtitle: String?
    let url: String?

    enum ActivityType {
        case worker
        case pages

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
