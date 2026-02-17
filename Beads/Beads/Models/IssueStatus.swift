import SwiftUI

enum IssueStatus: String, CaseIterable, Codable, Hashable {
    case open
    case inProgress = "in_progress"
    case blocked
    case closed
    case deferred
    case tombstone

    var label: String {
        switch self {
        case .open: "Open"
        case .inProgress: "In Progress"
        case .blocked: "Blocked"
        case .closed: "Closed"
        case .deferred: "Deferred"
        case .tombstone: "Deleted"
        }
    }

    var color: Color {
        switch self {
        case .open: .green
        case .inProgress: .blue
        case .blocked: .red
        case .closed: .secondary
        case .deferred: .orange
        case .tombstone: .gray
        }
    }

    var icon: String {
        switch self {
        case .open: "circle"
        case .inProgress: "circle.lefthalf.filled"
        case .blocked: "xmark.circle"
        case .closed: "checkmark.circle.fill"
        case .deferred: "clock"
        case .tombstone: "trash"
        }
    }

    /// Statuses visible in the sidebar
    static var sidebarStatuses: [IssueStatus] {
        [.open, .inProgress, .blocked, .deferred, .closed]
    }
}
