import SwiftUI

struct StatusChip: View {
    let status: IssueStatus

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: status.icon)
                .font(.system(size: 9))
            Text(status.label)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .foregroundStyle(status.color)
        .glassEffect(.regular.tint(status.color.opacity(0.3)), in: .capsule)
    }
}
