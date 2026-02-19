import Foundation
import GRDB

final class DatabaseReader {
    private let dbQueue: DatabaseQueue

    init(path: String) throws {
        var config = Configuration()
        config.readonly = false
        config.foreignKeysEnabled = false
        dbQueue = try DatabaseQueue(path: path, configuration: config)
    }

    // MARK: - Issues

    func fetchIssues(status: IssueStatus? = nil, search: String? = nil) throws -> [Issue] {
        try dbQueue.read { db in
            var sql = """
                SELECT * FROM issues
                WHERE deleted_at IS NULL AND status != 'tombstone'
                """
            var arguments: [DatabaseValueConvertible] = []

            if let status {
                sql += " AND status = ?"
                arguments.append(status.rawValue)
            }

            if let search, !search.isEmpty {
                sql += " AND (title LIKE ? OR id LIKE ?)"
                let pattern = "%\(search)%"
                arguments.append(pattern)
                arguments.append(pattern)
            }

            sql += " ORDER BY priority ASC, updated_at DESC"

            var issues = try Issue.fetchAll(db, sql: sql, arguments: StatementArguments(arguments))

            // Attach labels to each issue
            let labelRows = try Row.fetchAll(db, sql: "SELECT issue_id, label FROM labels")
            var labelMap: [String: [String]] = [:]
            for row in labelRows {
                let issueId: String = row["issue_id"]
                let label: String = row["label"]
                labelMap[issueId, default: []].append(label)
            }
            for i in issues.indices {
                issues[i].labels = labelMap[issues[i].id] ?? []
            }

            return issues
        }
    }

    func fetchIssue(id: String) throws -> Issue? {
        try dbQueue.read { db in
            guard var issue = try Issue.fetchOne(db, sql: """
                SELECT * FROM issues WHERE id = ?
                """, arguments: [id]) else {
                return nil
            }

            // Labels
            let labelRows = try Row.fetchAll(db, sql: """
                SELECT label FROM labels WHERE issue_id = ?
                """, arguments: [id])
            issue.labels = labelRows.map { $0["label"] }

            // Comments
            issue.comments = try Comment.fetchAll(db, sql: """
                SELECT * FROM comments WHERE issue_id = ? ORDER BY created_at ASC
                """, arguments: [id])

            // Dependencies (outgoing: this issue depends on others)
            issue.dependencies = try Dependency.fetchAll(db, sql: """
                SELECT d.*, i.title as related_title
                FROM dependencies d
                LEFT JOIN issues i ON d.depends_on_id = i.id
                WHERE d.issue_id = ?
                ORDER BY d.type, d.created_at
                """, arguments: [id])

            // Reverse dependencies (incoming: others depend on this issue)
            let reverseDeps = try Dependency.fetchAll(db, sql: """
                SELECT d.issue_id as depends_on_id, d.depends_on_id as issue_id,
                       d.type, d.created_at, d.created_by, d.metadata,
                       i.title as related_title
                FROM dependencies d
                LEFT JOIN issues i ON d.issue_id = i.id
                WHERE d.depends_on_id = ?
                ORDER BY d.type, d.created_at
                """, arguments: [id])
            issue.dependencies += reverseDeps

            return issue
        }
    }

    // MARK: - Status Counts

    func fetchStatusCounts() throws -> [IssueStatus: Int] {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT status, COUNT(*) as count FROM issues
                WHERE deleted_at IS NULL AND status != 'tombstone'
                GROUP BY status
                """)
            var counts: [IssueStatus: Int] = [:]
            for row in rows {
                let statusStr: String = row["status"]
                if let status = IssueStatus(rawValue: statusStr) {
                    counts[status] = row["count"]
                }
            }
            return counts
        }
    }

    // MARK: - Search

    func searchIssues(query: String) throws -> [Issue] {
        try dbQueue.read { db in
            let pattern = "%\(query)%"
            return try Issue.fetchAll(db, sql: """
                SELECT * FROM issues
                WHERE deleted_at IS NULL AND status != 'tombstone'
                AND (title LIKE ? OR id LIKE ? OR description LIKE ?)
                ORDER BY
                    CASE WHEN id LIKE ? THEN 0
                         WHEN title LIKE ? THEN 1
                         ELSE 2 END,
                    updated_at DESC
                LIMIT 50
                """, arguments: [pattern, pattern, pattern, pattern, pattern])
        }
    }

    // MARK: - Config

    func fetchConfig(key: String) throws -> String? {
        try dbQueue.read { db in
            try String.fetchOne(db, sql: "SELECT value FROM config WHERE key = ?", arguments: [key])
        }
    }
}
