import SwiftUI

struct ProjectRow: View {
    let project: Project
    let isSelected: Bool

    var body: some View {
        HStack {
            Image(systemName: "circle.hexagongrid")
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 1) {
                Text(project.name)
                    .fontWeight(isSelected ? .semibold : .regular)
                Text(project.prefix)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .contentShape(Rectangle())
    }
}
