enum DependencyType: String, CaseIterable, Codable, Hashable {
    case blocks
    case parentChild = "parent-child"
    case tracks
    case relatesTo = "relates-to"
    case discoveredFrom = "discovered-from"
    case duplicateOf = "duplicate-of"
    case supersededBy = "superseded-by"

    var label: String {
        switch self {
        case .blocks: "Blocks"
        case .parentChild: "Parent/Child"
        case .tracks: "Tracks"
        case .relatesTo: "Relates To"
        case .discoveredFrom: "Discovered From"
        case .duplicateOf: "Duplicate Of"
        case .supersededBy: "Superseded By"
        }
    }

    var icon: String {
        switch self {
        case .blocks: "hand.raised"
        case .parentChild: "arrow.up.arrow.down"
        case .tracks: "link"
        case .relatesTo: "arrow.left.arrow.right"
        case .discoveredFrom: "magnifyingglass"
        case .duplicateOf: "doc.on.doc"
        case .supersededBy: "arrow.uturn.forward"
        }
    }
}
