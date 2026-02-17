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
            .background(priority.color.opacity(0.15))
            .foregroundStyle(priority.color)
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}
