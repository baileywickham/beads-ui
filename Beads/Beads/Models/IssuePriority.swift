import SwiftUI

enum IssuePriority: Int, CaseIterable, Codable, Hashable {
    case p0 = 0
    case p1 = 1
    case p2 = 2
    case p3 = 3
    case p4 = 4

    var label: String {
        "P\(rawValue)"
    }

    var color: Color {
        switch self {
        case .p0: .red
        case .p1: .orange
        case .p2: Color(.sRGB, red: 0.8, green: 0.6, blue: 0.0)
        case .p3: .blue
        case .p4: .secondary
        }
    }

    var name: String {
        switch self {
        case .p0: "Critical"
        case .p1: "High"
        case .p2: "Medium"
        case .p3: "Low"
        case .p4: "Minimal"
        }
    }
}
