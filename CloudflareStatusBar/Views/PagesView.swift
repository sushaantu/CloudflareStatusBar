import SwiftUI

struct PagesView: View {
    let projects: [PagesProject]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if projects.isEmpty {
                emptyState
            } else {
                ForEach(projects) { project in
                    PagesProjectRow(project: project)
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

    @State private var isExpanded = false
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main Row
            HStack {
                Image(systemName: "doc.richtext")
                    .foregroundColor(.purple)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(project.name)
                        .font(.caption)
                        .fontWeight(.medium)

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

                Button(action: { withAnimation { isExpanded.toggle() } }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(10)
            .background(isHovered ? Color(nsColor: .selectedControlColor).opacity(0.3) : Color(nsColor: .controlBackgroundColor))
            .onHover { hovering in
                isHovered = hovering
            }

            // Expanded Details
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    // Source info
                    if let source = project.source?.config {
                        HStack {
                            Image(systemName: "arrow.triangle.branch")
                                .font(.caption2)

                            if let owner = source.owner, let repo = source.repoName {
                                Text("\(owner)/\(repo)")
                                    .font(.caption2)
                            }

                            if let branch = source.productionBranch {
                                Text("(\(branch))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    // Latest deployment info
                    if let deployment = project.latestDeployment {
                        Divider()

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Latest Deployment")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)

                            HStack {
                                if let env = deployment.environment {
                                    Label(env, systemImage: "globe")
                                        .font(.caption2)
                                }

                                if let trigger = deployment.deploymentTrigger?.metadata {
                                    if let branch = trigger.branch {
                                        Label(branch, systemImage: "arrow.triangle.branch")
                                            .font(.caption2)
                                    }
                                }
                            }

                            if let commitMessage = deployment.deploymentTrigger?.metadata?.commitMessage {
                                Text(commitMessage)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }

                            if let date = deployment.createdOn {
                                Text(date.formatted(.dateTime))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    // Custom domains
                    if let domains = project.domains, !domains.isEmpty {
                        Divider()

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Domains")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)

                            ForEach(domains, id: \.self) { domain in
                                HStack {
                                    Image(systemName: "link")
                                        .font(.caption2)
                                    Text(domain)
                                        .font(.caption2)
                                }
                            }
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
