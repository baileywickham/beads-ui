import SwiftUI

enum IssueType: String, CaseIterable, Codable, Hashable {
    case bug
    case feature
    case task
    case epic
    case chore

    var label: String {
        rawValue.capitalized
    }

    var icon: String {
        switch self {
        case .bug: "ladybug"
        case .feature: "star"
        case .task: "checklist"
        case .epic: "bolt.shield"
        case .chore: "wrench"
        }
    }

    var color: Color {
        switch self {
        case .bug: .red
        case .feature: .purple
        case .task: .blue
        case .epic: .orange
        case .chore: .secondary
        }
    }
}
