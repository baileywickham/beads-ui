import SwiftUI

struct IssueRow: View {
    let issue: Issue
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                PriorityIndicator(priority: issue.priority)
                StatusChip(status: issue.status)
                Spacer()
                Text(issue.id)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .monospaced()
            }

            Text(issue.title)
                .font(.body)
                .fontWeight(isSelected ? .semibold : .regular)
                .lineLimit(2)

            HStack(spacing: 8) {
                TypeIcon(type: issue.issueType)

                if let assignee = issue.assignee, !assignee.isEmpty {
                    HStack(spacing: 2) {
                        Image(systemName: "person")
                            .font(.system(size: 9))
                        Text(assignee)
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                }

                if !issue.labels.isEmpty {
                    HStack(spacing: 2) {
                        Image(systemName: "tag")
                            .font(.system(size: 9))
                        Text(issue.labels.prefix(2).joined(separator: ", "))
                            .font(.caption2)
                            .lineLimit(1)
                    }
                    .foregroundStyle(.secondary)
                }

                Spacer()
                RelativeTimeText(date: issue.updatedAt)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
