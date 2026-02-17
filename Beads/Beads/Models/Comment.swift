import Foundation
import GRDB

struct Comment: FetchableRecord, Identifiable, Decodable, Hashable {
    var id: Int64
    var issueId: String
    var author: String
    var text: String
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case issueId = "issue_id"
        case author, text
        case createdAt = "created_at"
    }
}
