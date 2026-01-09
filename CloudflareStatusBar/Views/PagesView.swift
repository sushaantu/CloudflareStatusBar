import SwiftUI
import AppKit

struct PagesView: View {
    let projects: [PagesProject]
    let accountId: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if projects.isEmpty {
                emptyState
            } else {
                ForEach(projects) { project in
                    PagesProjectRow(project: project, accountId: accountId)
                }
            }
        }
        .padding()
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.richtext")
                .font(.largeTitle)
                .foregroundColor(.secondary)

            Text("No Pages Projects")
                .font(.headline)

            Text("You don't have any Pages projects deployed yet.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
    }
}

struct PagesProjectRow: View {
    let project: PagesProject
    let accountId: String?

    @State private var isExpanded = false
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main Row - clickable to open dashboard
            Button(action: openInDashboard) {
                HStack {
                    Image(systemName: "doc.richtext")
                        .foregroundColor(.purple)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(project.name)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)

                        if let subdomain = project.subdomain {
                            Text("\(subdomain).pages.dev")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    if let deployment = project.latestDeployment {
                        DeploymentStatusBadge(status: deployment.status)
                    }

                    Image(systemName: "arrow.up.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .opacity(isHovered ? 1 : 0)
                }
                .padding(10)
                .background(isHovered ? Color.accentColor.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
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

            // Expandable details section
            if let deployment = project.latestDeployment {
                Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
                    HStack {
                        if let trigger = deployment.deploymentTrigger?.metadata {
                            if let branch = trigger.branch {
                                Label(branch, systemImage: "arrow.triangle.branch")
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

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                }
                .buttonStyle(.plain)
            }

            // Expanded Details
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    // Source info
                    if let source = project.source?.config {
                        if let owner = source.owner, let repo = source.repoName {
                            Button(action: { openGitHub(owner: owner, repo: repo) }) {
                                HStack {
                                    Image(systemName: "arrow.triangle.branch")
                                        .font(.caption2)
                                    Text("\(owner)/\(repo)")
                                        .font(.caption2)
                                    Image(systemName: "arrow.up.right")
                                        .font(.caption2)
                                }
                                .foregroundColor(.accentColor)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Latest deployment info
                    if let deployment = project.latestDeployment {
                        if let commitMessage = deployment.deploymentTrigger?.metadata?.commitMessage {
                            Text(commitMessage)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }

                        // Preview URL
                        if let url = deployment.url {
                            Button(action: { openURL(url) }) {
                                HStack {
                                    Image(systemName: "globe")
                                        .font(.caption2)
                                    Text("Open Preview")
                                        .font(.caption2)
                                    Image(systemName: "arrow.up.right")
                                        .font(.caption2)
                                }
                                .foregroundColor(.accentColor)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Custom domains
                    if let domains = project.domains, !domains.isEmpty {
                        Divider()

                        Text("Domains")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)

                        ForEach(domains, id: \.self) { domain in
                            Button(action: { openURL("https://\(domain)") }) {
                                HStack {
                                    Image(systemName: "link")
                                        .font(.caption2)
                                    Text(domain)
                                        .font(.caption2)
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                        .font(.caption2)
                                }
                                .foregroundColor(.accentColor)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(10)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            }
        }
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
        )
    }

    private func openInDashboard() {
        guard let accountId = accountId else { return }
        if let url = URL(string: "https://dash.cloudflare.com/\(accountId)/pages/view/\(project.name)") {
            NSWorkspace.shared.open(url)
        }
    }

    private func openGitHub(owner: String, repo: String) {
        if let url = URL(string: "https://github.com/\(owner)/\(repo)") {
            NSWorkspace.shared.open(url)
        }
    }

    private func openURL(_ urlString: String) {
        var finalURL = urlString
        if !finalURL.hasPrefix("http") {
            finalURL = "https://\(finalURL)"
        }
        if let url = URL(string: finalURL) {
            NSWorkspace.shared.open(url)
        }
    }
}

struct DeploymentStatusBadge: View {
    let status: DeploymentStatus

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)

            Text(status.displayName)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.15))
        .cornerRadius(4)
    }

    private var statusColor: Color {
        switch status {
        case .success: return .green
        case .failure: return .red
        case .active: return .blue
        case .canceled: return .orange
        default: return .gray
        }
    }
}
