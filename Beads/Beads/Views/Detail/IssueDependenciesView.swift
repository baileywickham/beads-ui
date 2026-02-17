import SwiftUI

struct IssueDependenciesView: View {
    let dependencies: [Dependency]
    let onSelect: (String) -> Void

    var body: some View {
        let grouped = Dictionary(grouping: dependencies, by: \.type)

        VStack(alignment: .leading, spacing: 6) {
            Text("Dependencies")
                .font(.headline)

            ForEach(Array(grouped.keys.sorted(by: { $0.rawValue < $1.rawValue })), id: \.self) { type in
                if let deps = grouped[type] {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: type.icon)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(type.label)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        ForEach(deps) { dep in
                            Button {
                                onSelect(dep.dependsOnId)
                            } label: {
                                HStack(spacing: 6) {
                                    Text(dep.dependsOnId)
                                        .font(.caption)
                                        .monospaced()
                                        .foregroundStyle(.blue)
                                    if let title = dep.relatedTitle {
                                        Text(title)
                                            .font(.callout)
                                            .lineLimit(1)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.leading, 4)
                }
            }
        }
    }
}
