import Foundation
import GRDB

struct Issue: FetchableRecord, Identifiable, Hashable, Decodable {
    var id: String
    var title: String
    var description: String
    var design: String
    var acceptanceCriteria: String
    var notes: String
    var status: IssueStatus
    var priority: IssuePriority
    var issueType: IssueType
    var assignee: String?
    var estimatedMinutes: Int?
    var createdAt: Date
    var createdBy: String
    var owner: String
    var updatedAt: Date
    var closedAt: Date?
    var externalRef: String?
    var pinned: Bool
    var sourceRepo: String
    var dueAt: Date?
    var deferUntil: Date?

    // Populated after fetch
    var labels: [String] = []
    var comments: [Comment] = []
    var dependencies: [Dependency] = []

    static func == (lhs: Issue, rhs: Issue) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    enum CodingKeys: String, CodingKey {
        case id, title, description, design
        case acceptanceCriteria = "acceptance_criteria"
        case notes, status, priority
        case issueType = "issue_type"
        case assignee
        case estimatedMinutes = "estimated_minutes"
        case createdAt = "created_at"
        case createdBy = "created_by"
        case owner
        case updatedAt = "updated_at"
        case closedAt = "closed_at"
        case externalRef = "external_ref"
        case pinned
        case sourceRepo = "source_repo"
        case dueAt = "due_at"
        case deferUntil = "defer_until"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        design = try container.decode(String.self, forKey: .design)
        acceptanceCriteria = try container.decode(String.self, forKey: .acceptanceCriteria)
        notes = try container.decode(String.self, forKey: .notes)

        let statusStr = try container.decode(String.self, forKey: .status)
        status = IssueStatus(rawValue: statusStr) ?? .open

        let priorityInt = try container.decode(Int.self, forKey: .priority)
        priority = IssuePriority(rawValue: priorityInt) ?? .p2

        let typeStr = try container.decode(String.self, forKey: .issueType)
        issueType = IssueType(rawValue: typeStr) ?? .task

        assignee = try container.decodeIfPresent(String.self, forKey: .assignee)
        estimatedMinutes = try container.decodeIfPresent(Int.self, forKey: .estimatedMinutes)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        createdBy = try container.decode(String.self, forKey: .createdBy)
        owner = try container.decode(String.self, forKey: .owner)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        closedAt = try container.decodeIfPresent(Date.self, forKey: .closedAt)
        externalRef = try container.decodeIfPresent(String.self, forKey: .externalRef)
        pinned = try container.decode(Bool.self, forKey: .pinned)
        sourceRepo = try container.decode(String.self, forKey: .sourceRepo)
        dueAt = try container.decodeIfPresent(Date.self, forKey: .dueAt)
        deferUntil = try container.decodeIfPresent(Date.self, forKey: .deferUntil)
    }

    init(
        id: String, title: String, description: String = "", design: String = "",
        acceptanceCriteria: String = "", notes: String = "",
        status: IssueStatus = .open, priority: IssuePriority = .p2,
        issueType: IssueType = .task, assignee: String? = nil,
        estimatedMinutes: Int? = nil, createdAt: Date = Date(),
        createdBy: String = "", owner: String = "", updatedAt: Date = Date(),
        closedAt: Date? = nil, externalRef: String? = nil, pinned: Bool = false,
        sourceRepo: String = ".", dueAt: Date? = nil, deferUntil: Date? = nil,
        labels: [String] = [], comments: [Comment] = [], dependencies: [Dependency] = []
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.design = design
        self.acceptanceCriteria = acceptanceCriteria
        self.notes = notes
        self.status = status
        self.priority = priority
        self.issueType = issueType
        self.assignee = assignee
        self.estimatedMinutes = estimatedMinutes
        self.createdAt = createdAt
        self.createdBy = createdBy
        self.owner = owner
        self.updatedAt = updatedAt
        self.closedAt = closedAt
        self.externalRef = externalRef
        self.pinned = pinned
        self.sourceRepo = sourceRepo
        self.dueAt = dueAt
        self.deferUntil = deferUntil
        self.labels = labels
        self.comments = comments
        self.dependencies = dependencies
    }
}
