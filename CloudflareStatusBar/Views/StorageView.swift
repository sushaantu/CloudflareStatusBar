import SwiftUI

struct StorageView: View {
    let kvNamespaces: [KVNamespace]
    let r2Buckets: [R2Bucket]
    let d1Databases: [D1Database]
    let queues: [Queue]

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
                    KVNamespaceRow(namespace: namespace)
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
                    R2BucketRow(bucket: bucket)
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
                    D1DatabaseRow(database: database)
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
                    QueueRow(queue: queue)
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
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(color)
                        .frame(width: 20)

                    Text(title)
                        .font(.caption)
                        .fontWeight(.semibold)

                    Text("(\(count))")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                if count == 0 {
                    Text("No \(title.lowercased()) found")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.leading, 28)
                } else {
                    content()
                }
            }
        }
    }
}

struct KVNamespaceRow: View {
    let namespace: KVNamespace

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(namespace.title)
                    .font(.caption)
                    .fontWeight(.medium)

                Text(namespace.id)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(6)
    }
}

struct R2BucketRow: View {
    let bucket: R2Bucket

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(bucket.name)
                    .font(.caption)
                    .fontWeight(.medium)

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
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(6)
    }
}

struct D1DatabaseRow: View {
    let database: D1Database

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(database.name)
                    .font(.caption)
                    .fontWeight(.medium)

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
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(6)
    }

    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

struct QueueRow: View {
    let queue: Queue

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(queue.queueName)
                    .font(.caption)
                    .fontWeight(.medium)

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
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(6)
    }
}
