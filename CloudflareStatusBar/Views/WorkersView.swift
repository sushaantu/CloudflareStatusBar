import SwiftUI

struct WorkersView: View {
    let workers: [Worker]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if workers.isEmpty {
                emptyState
            } else {
                ForEach(workers) { worker in
                    WorkerRow(worker: worker)
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

    @State private var isHovered = false

    var body: some View {
        HStack {
            Image(systemName: "server.rack")
                .foregroundColor(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(worker.name)
                    .font(.caption)
                    .fontWeight(.medium)

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
        }
        .padding(10)
        .background(isHovered ? Color(nsColor: .selectedControlColor).opacity(0.3) : Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
