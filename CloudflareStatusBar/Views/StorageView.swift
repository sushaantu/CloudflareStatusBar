import SwiftUI
import AppKit

struct StorageView: View {
    let kvNamespaces: [KVNamespace]
    let r2Buckets: [R2Bucket]
    let d1Databases: [D1Database]
    let queues: [Queue]
    let accountId: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // KV Namespaces
            StorageSection(
                title: "KV Namespaces",
                icon: "key",
                color: .orange,
                count: kvNamespaces.count
            ) {
                ForEach(kvNamespaces) { namespace in
                    KVNamespaceRow(namespace: namespace, accountId: accountId)
                }
            }

            // R2 Buckets
            StorageSection(
                title: "R2 Buckets",
                icon: "externaldrive",
                color: .green,
                count: r2Buckets.count
            ) {
                ForEach(r2Buckets) { bucket in
                    R2BucketRow(bucket: bucket, accountId: accountId)
                }
            }

            // D1 Databases
            StorageSection(
                title: "D1 Databases",
                icon: "cylinder",
                color: .indigo,
                count: d1Databases.count
            ) {
                ForEach(d1Databases) { database in
                    D1DatabaseRow(database: database, accountId: accountId)
                }
            }

            // Queues
            StorageSection(
                title: "Queues",
                icon: "list.bullet.rectangle",
                color: .teal,
                count: queues.count
            ) {
                ForEach(queues) { queue in
                    QueueRow(queue: queue, accountId: accountId)
                }
            }
        }
        .padding()
    }
}

struct StorageSection<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    let count: Int
    @ViewBuilder let content: () -> Content

    @State private var isExpanded = true

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            if count == 0 {
                Text("No \(title.lowercased()) found")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.leading, 4)
                    .padding(.vertical, 4)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    content()
                }
                .padding(.top, 4)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 18)

                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)

                Text("(\(count))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .disclosureGroupStyle(CustomDisclosureStyle())
    }
}

struct CustomDisclosureStyle: DisclosureGroupStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                configuration.label
                Spacer()
                Image(systemName: configuration.isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    configuration.isExpanded.toggle()
                }
            }

            if configuration.isExpanded {
                configuration.content
                    .padding(.leading, 26)
            }
        }
    }
}

struct KVNamespaceRow: View {
    let namespace: KVNamespace
    let accountId: String?

    @State private var isHovered = false

    var body: some View {
        Button(action: openInDashboard) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(namespace.title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    Text(namespace.id)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .opacity(isHovered ? 1 : 0)
            }
            .padding(8)
            .background(isHovered ? Color.accentColor.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }

    private func openInDashboard() {
        guard let accountId = accountId else { return }
        if let url = URL(string: "https://dash.cloudflare.com/\(accountId)/workers/kv/namespaces/\(namespace.id)") {
            NSWorkspace.shared.open(url)
        }
    }
}

struct R2BucketRow: View {
    let bucket: R2Bucket
    let accountId: String?

    @State private var isHovered = false

    var body: some View {
        Button(action: openInDashboard) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(bucket.name)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    HStack(spacing: 8) {
                        if let location = bucket.location {
                            Label(location, systemImage: "mappin")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        if let date = bucket.creationDate {
                            Label(date.formatted(.dateTime.month().year()), systemImage: "calendar")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .opacity(isHovered ? 1 : 0)
            }
            .padding(8)
            .background(isHovered ? Color.accentColor.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }

    private func openInDashboard() {
        guard let accountId = accountId else { return }
        if let url = URL(string: "https://dash.cloudflare.com/\(accountId)/r2/default/buckets/\(bucket.name)") {
            NSWorkspace.shared.open(url)
        }
    }
}

struct D1DatabaseRow: View {
    let database: D1Database
    let accountId: String?

    @State private var isHovered = false
    private static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()

    var body: some View {
        Button(action: openInDashboard) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(database.name)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    HStack(spacing: 8) {
                        if let tables = database.numTables {
                            Label("\(tables) tables", systemImage: "tablecells")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        if let size = database.fileSize {
                            Label(formatBytes(size), systemImage: "externaldrive")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                if let version = database.version {
                    Text("v\(version)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Image(systemName: "arrow.up.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .opacity(isHovered ? 1 : 0)
            }
            .padding(8)
            .background(isHovered ? Color.accentColor.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }

    private func formatBytes(_ bytes: Int) -> String {
        Self.byteFormatter.string(fromByteCount: Int64(bytes))
    }

    private func openInDashboard() {
        guard let accountId = accountId else { return }
        if let url = URL(string: "https://dash.cloudflare.com/\(accountId)/d1/database/\(database.uuid)") {
            NSWorkspace.shared.open(url)
        }
    }
}

struct QueueRow: View {
    let queue: Queue
    let accountId: String?

    @State private var isHovered = false

    var body: some View {
        Button(action: openInDashboard) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(queue.queueName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    HStack(spacing: 8) {
                        if let producers = queue.producersTotalCount {
                            Label("\(producers) producers", systemImage: "arrow.up.circle")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        if let consumers = queue.consumersTotalCount {
                            Label("\(consumers) consumers", systemImage: "arrow.down.circle")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .opacity(isHovered ? 1 : 0)
            }
            .padding(8)
            .background(isHovered ? Color.accentColor.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }

    private func openInDashboard() {
        guard let accountId = accountId else { return }
        if let url = URL(string: "https://dash.cloudflare.com/\(accountId)/queues/\(queue.queueId)") {
            NSWorkspace.shared.open(url)
        }
    }
}
