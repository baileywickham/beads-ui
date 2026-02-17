import SwiftUI

struct PriorityIndicator: View {
    let priority: IssuePriority

    var body: some View {
        Text(priority.label)
            .font(.caption2)
            .fontWeight(.bold)
            .monospacedDigit()
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .foregroundStyle(priority.color)
            .glassEffect(.regular.tint(priority.color.opacity(0.3)), in: RoundedRectangle(cornerRadius: 4))
    }
}
