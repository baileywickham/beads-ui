import Foundation
import GRDB

struct Dependency: FetchableRecord, Identifiable, Decodable, Hashable {
    var issueId: String
    var dependsOnId: String
    var type: DependencyType
    var createdAt: Date
    var createdBy: String
    var metadata: String?

    var id: String { "\(issueId)-\(dependsOnId)-\(type.rawValue)" }

    // Title of the related issue, populated after join query
    var relatedTitle: String?

    enum CodingKeys: String, CodingKey {
        case issueId = "issue_id"
        case dependsOnId = "depends_on_id"
        case type
        case createdAt = "created_at"
        case createdBy = "created_by"
        case metadata
        case relatedTitle = "related_title"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        issueId = try container.decode(String.self, forKey: .issueId)
        dependsOnId = try container.decode(String.self, forKey: .dependsOnId)
        let typeStr = try container.decode(String.self, forKey: .type)
        type = DependencyType(rawValue: typeStr) ?? .blocks
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        createdBy = try container.decode(String.self, forKey: .createdBy)
        metadata = try container.decodeIfPresent(String.self, forKey: .metadata)
        relatedTitle = try container.decodeIfPresent(String.self, forKey: .relatedTitle)
    }
}
