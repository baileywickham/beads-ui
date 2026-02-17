import SwiftUI

struct IssueMetadataView: View {
    let issue: Issue
    let onStatusChange: (IssueStatus) -> Void
    let onPriorityChange: (IssuePriority) -> Void

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
            GridRow {
                metadataLabel("Status")
                Menu {
                    ForEach(IssueStatus.sidebarStatuses, id: \.self) { status in
                        Button {
                            onStatusChange(status)
                        } label: {
                            Label(status.label, systemImage: status.icon)
                        }
                    }
                } label: {
                    StatusChip(status: issue.status)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }

            GridRow {
                metadataLabel("Priority")
                Menu {
                    ForEach(IssuePriority.allCases, id: \.self) { p in
                        Button {
                            onPriorityChange(p)
                        } label: {
                            Text("\(p.label) — \(p.name)")
                        }
                    }
                } label: {
                    PriorityIndicator(priority: issue.priority)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }

            GridRow {
                metadataLabel("Type")
                HStack(spacing: 4) {
                    TypeIcon(type: issue.issueType)
                    Text(issue.issueType.label)
                        .font(.callout)
                }
            }

            if let assignee = issue.assignee, !assignee.isEmpty {
                GridRow {
                    metadataLabel("Assignee")
                    HStack(spacing: 4) {
                        Image(systemName: "person.circle")
                            .foregroundStyle(.secondary)
                        Text(assignee)
                            .font(.callout)
                    }
                }
            }

            if !issue.labels.isEmpty {
                GridRow {
                    metadataLabel("Labels")
                    FlowLayout(spacing: 4) {
                        ForEach(issue.labels, id: \.self) { label in
                            Text(label)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.quaternary)
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            GridRow {
                metadataLabel("Created")
                Text(issue.createdAt, style: .date)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if let due = issue.dueAt {
                GridRow {
                    metadataLabel("Due")
                    Text(due, style: .date)
                        .font(.callout)
                        .foregroundStyle(due < Date() ? .red : .secondary)
                }
            }
        }
    }

    private func metadataLabel(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(width: 70, alignment: .trailing)
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            let point = CGPoint(
                x: bounds.minX + result.positions[index].x,
                y: bounds.minY + result.positions[index].y
            )
            subview.place(at: point, proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (CGSize(width: maxX, height: y + rowHeight), positions)
    }
}
