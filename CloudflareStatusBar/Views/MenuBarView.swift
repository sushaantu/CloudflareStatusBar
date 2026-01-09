import SwiftUI

struct MenuBarView: View {
    @ObservedObject var viewModel: CloudflareViewModel

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
                        OverviewView(viewModel: viewModel)
                    case .workers:
                        WorkersView(workers: viewModel.state.workers)
                    case .pages:
                        PagesView(projects: viewModel.state.pagesProjects)
                    case .storage:
                        StorageView(
                            kvNamespaces: viewModel.state.kvNamespaces,
                            r2Buckets: viewModel.state.r2Buckets,
                            d1Databases: viewModel.state.d1Databases,
                            queues: viewModel.state.queues
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Stats Grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                StatCard(
                    title: "Workers",
                    count: viewModel.state.workers.count,
                    icon: "server.rack",
                    color: .blue
                )

                StatCard(
                    title: "Pages",
                    count: viewModel.state.pagesProjects.count,
                    icon: "doc.richtext",
                    color: .purple
                )

                StatCard(
                    title: "KV Namespaces",
                    count: viewModel.state.kvNamespaces.count,
                    icon: "key",
                    color: .orange
                )

                StatCard(
                    title: "R2 Buckets",
                    count: viewModel.state.r2Buckets.count,
                    icon: "externaldrive",
                    color: .green
                )

                StatCard(
                    title: "D1 Databases",
                    count: viewModel.state.d1Databases.count,
                    icon: "cylinder",
                    color: .indigo
                )

                StatCard(
                    title: "Queues",
                    count: viewModel.state.queues.count,
                    icon: "list.bullet.rectangle",
                    color: .teal
                )
            }

            // Recent Deployments
            if !viewModel.state.pagesProjects.isEmpty {
                Text("Recent Deployments")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)

                ForEach(recentDeployments.prefix(3)) { deployment in
                    DeploymentRow(deployment: deployment)
                }
            }
        }
        .padding()
    }

    private var recentDeployments: [PagesDeployment] {
        viewModel.state.pagesProjects
            .compactMap { $0.latestDeployment }
            .sorted { ($0.createdOn ?? .distantPast) > ($1.createdOn ?? .distantPast) }
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
