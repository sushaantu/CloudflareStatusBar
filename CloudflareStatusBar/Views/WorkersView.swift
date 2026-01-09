import SwiftUI
import AppKit

struct WorkersView: View {
    let workers: [Worker]
    let accountId: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if workers.isEmpty {
                emptyState
            } else {
                ForEach(workers) { worker in
                    WorkerRow(worker: worker, accountId: accountId)
                }
            }
        }
        .padding()
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "server.rack")
                .font(.largeTitle)
                .foregroundColor(.secondary)

            Text("No Workers")
                .font(.headline)

            Text("You don't have any Workers deployed yet.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
    }
}

struct WorkerRow: View {
    let worker: Worker
    let accountId: String?

    @State private var isHovered = false

    var body: some View {
        Button(action: openInDashboard) {
            HStack {
                Image(systemName: "server.rack")
                    .foregroundColor(.blue)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(worker.name)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    HStack(spacing: 8) {
                        if let usageModel = worker.usageModel {
                            Label(usageModel.capitalized, systemImage: "gauge")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        if let compatDate = worker.compatibilityDate {
                            Label(compatDate, systemImage: "calendar")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                if let modifiedOn = worker.modifiedOn {
                    Text(modifiedOn.formatted(.relative(presentation: .named)))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Image(systemName: "arrow.up.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .opacity(isHovered ? 1 : 0)
            }
            .padding(10)
            .background(isHovered ? Color.accentColor.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
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
        if let url = URL(string: "https://dash.cloudflare.com/\(accountId)/workers/services/view/\(worker.name)/production") {
            NSWorkspace.shared.open(url)
        }
    }
}
