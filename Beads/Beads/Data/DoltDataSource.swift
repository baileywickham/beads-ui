import Foundation
import MySQLNIO
import NIOCore
import NIOPosix

actor DoltDataSource: DataSource {
    private let config: DoltConnection
    private let eventLoopGroup: MultiThreadedEventLoopGroup
    private var connection: MySQLConnection?

    init(connection: DoltConnection) {
        self.config = connection
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    }

    func close() async {
        if let conn = connection {
            try? await conn.close().get()
            connection = nil
        }
        try? await eventLoopGroup.shutdownGracefully()
    }

    private func ensureConnection() async throws -> MySQLConnection {
        if let conn = connection, conn.channel.isActive {
            return conn
        }
        let addr = try SocketAddress.makeAddressResolvingHost(config.host, port: config.port)
        let conn = try await MySQLConnection.connect(
            to: addr,
            username: config.user,
            database: config.database,
            password: config.password ?? "",
            tlsConfiguration: nil,
            on: eventLoopGroup.any()
        ).get()
        self.connection = conn
        return conn
    }

    private func query(_ sql: String, _ binds: [MySQLData] = []) async throws -> [MySQLRow] {
        do {
            let conn = try await ensureConnection()
            return try await conn.query(sql, binds).get()
        } catch {
            // Connection might be stale — reconnect once
            connection = nil
            let conn = try await ensureConnection()
            return try await conn.query(sql, binds).get()
        }
    }

    // MARK: - DataSource

    func fetchIssues(status: IssueStatus? = nil, search: String? = nil) async throws -> [Issue] {
        var sql = """
            SELECT * FROM issues
            WHERE deleted_at IS NULL AND status != 'tombstone'
            """
        var binds: [MySQLData] = []

        if let status {
            sql += " AND status = ?"
            binds.append(MySQLData(string: status.rawValue))
        }

        if let search, !search.isEmpty {
            sql += " AND (title LIKE ? OR id LIKE ?)"
            let pattern = "%\(search)%"
            binds.append(MySQLData(string: pattern))
            binds.append(MySQLData(string: pattern))
        }

        sql += " ORDER BY priority ASC, updated_at DESC"

        let rows = try await query(sql, binds)
        var issues = rows.map { issueFromRow($0) }

        // Attach labels
        let labelRows = try await query("SELECT issue_id, label FROM labels")
        var labelMap: [String: [String]] = [:]
        for row in labelRows {
            if let issueId = row.column("issue_id")?.string,
               let label = row.column("label")?.string {
                labelMap[issueId, default: []].append(label)
            }
        }
        for i in issues.indices {
            issues[i].labels = labelMap[issues[i].id] ?? []
        }

        return issues
    }

    func fetchIssue(id: String) async throws -> Issue? {
        let rows = try await query("SELECT * FROM issues WHERE id = ?", [MySQLData(string: id)])
        guard let row = rows.first else { return nil }
        var issue = issueFromRow(row)

        // Labels
        let labelRows = try await query(
            "SELECT label FROM labels WHERE issue_id = ?", [MySQLData(string: id)])
        issue.labels = labelRows.compactMap { $0.column("label")?.string }

        // Comments
        let commentRows = try await query(
            "SELECT * FROM comments WHERE issue_id = ? ORDER BY created_at ASC",
            [MySQLData(string: id)])
        issue.comments = commentRows.map { commentFromRow($0) }

        // Dependencies (outgoing)
        let depRows = try await query("""
            SELECT d.*, i.title as related_title
            FROM dependencies d
            LEFT JOIN issues i ON d.depends_on_id = i.id
            WHERE d.issue_id = ?
            ORDER BY d.type, d.created_at
            """, [MySQLData(string: id)])
        issue.dependencies = depRows.map { dependencyFromRow($0) }

        // Reverse dependencies (incoming)
        let revDepRows = try await query("""
            SELECT d.issue_id as depends_on_id, d.depends_on_id as issue_id,
                   d.type, d.created_at, d.created_by, d.metadata,
                   i.title as related_title
            FROM dependencies d
            LEFT JOIN issues i ON d.issue_id = i.id
            WHERE d.depends_on_id = ?
            ORDER BY d.type, d.created_at
            """, [MySQLData(string: id)])
        issue.dependencies += revDepRows.map { dependencyFromRow($0) }

        return issue
    }

    func fetchStatusCounts() async throws -> [IssueStatus: Int] {
        let rows = try await query("""
            SELECT status, COUNT(*) as count FROM issues
            WHERE deleted_at IS NULL AND status != 'tombstone'
            GROUP BY status
            """)
        var counts: [IssueStatus: Int] = [:]
        for row in rows {
            if let statusStr = row.column("status")?.string,
               let status = IssueStatus(rawValue: statusStr),
               let count = row.column("count")?.int {
                counts[status] = count
            }
        }
        return counts
    }

    func searchIssues(query searchQuery: String) async throws -> [Issue] {
        let pattern = "%\(searchQuery)%"
        let bind = MySQLData(string: pattern)
        let rows = try await query("""
            SELECT * FROM issues
            WHERE deleted_at IS NULL AND status != 'tombstone'
            AND (title LIKE ? OR id LIKE ? OR description LIKE ?)
            ORDER BY
                CASE WHEN id LIKE ? THEN 0
                     WHEN title LIKE ? THEN 1
                     ELSE 2 END,
                updated_at DESC
            LIMIT 50
            """, [bind, bind, bind, bind, bind])
        return rows.map { issueFromRow($0) }
    }

    func fetchConfig(key: String) async throws -> String? {
        let rows = try await query(
            "SELECT value FROM config WHERE `key` = ?", [MySQLData(string: key)])
        return rows.first?.column("value")?.string
    }

    // MARK: - Connection Test

    nonisolated func testConnection() async throws {
        _ = try await self.query("SELECT 1")
    }

    // MARK: - Database Discovery

    nonisolated func discoverDatabases() async throws -> [String] {
        let rows = try await self.query("SHOW DATABASES")
        return rows.compactMap { row in
            // Dolt returns database name in the first column
            row.column("Database")?.string ?? row.column("database")?.string
        }.filter { name in
            // Filter out system databases
            !["information_schema", "mysql", "performance_schema", "sys"].contains(name)
        }
    }

    // MARK: - Row Mapping

    private func issueFromRow(_ row: MySQLRow) -> Issue {
        Issue(
            id: row.column("id")?.string ?? "",
            title: row.column("title")?.string ?? "",
            description: row.column("description")?.string ?? "",
            design: row.column("design")?.string ?? "",
            acceptanceCriteria: row.column("acceptance_criteria")?.string ?? "",
            notes: row.column("notes")?.string ?? "",
            status: IssueStatus(rawValue: row.column("status")?.string ?? "") ?? .open,
            priority: IssuePriority(rawValue: row.column("priority")?.int ?? 2) ?? .p2,
            issueType: IssueType(rawValue: row.column("issue_type")?.string ?? "") ?? .task,
            assignee: row.column("assignee")?.string,
            estimatedMinutes: row.column("estimated_minutes")?.int,
            createdAt: parseDate(row.column("created_at")) ?? Date(),
            createdBy: row.column("created_by")?.string ?? "",
            owner: row.column("owner")?.string ?? "",
            updatedAt: parseDate(row.column("updated_at")) ?? Date(),
            closedAt: parseDate(row.column("closed_at")),
            externalRef: row.column("external_ref")?.string,
            pinned: row.column("pinned")?.int == 1,
            sourceRepo: row.column("source_repo")?.string ?? ".",
            dueAt: parseDate(row.column("due_at")),
            deferUntil: parseDate(row.column("defer_until"))
        )
    }

    private func commentFromRow(_ row: MySQLRow) -> Comment {
        Comment(
            id: Int64(row.column("id")?.int ?? 0),
            issueId: row.column("issue_id")?.string ?? "",
            author: row.column("author")?.string ?? "",
            text: row.column("text")?.string ?? "",
            createdAt: parseDate(row.column("created_at")) ?? Date()
        )
    }

    private func dependencyFromRow(_ row: MySQLRow) -> Dependency {
        Dependency(
            issueId: row.column("issue_id")?.string ?? "",
            dependsOnId: row.column("depends_on_id")?.string ?? "",
            type: DependencyType(rawValue: row.column("type")?.string ?? "") ?? .blocks,
            createdAt: parseDate(row.column("created_at")) ?? Date(),
            createdBy: row.column("created_by")?.string ?? "",
            metadata: row.column("metadata")?.string,
            relatedTitle: row.column("related_title")?.string
        )
    }

    private func parseDate(_ data: MySQLData?) -> Date? {
        guard let data else { return nil }
        // Try native MySQL date first
        if let time = data.time {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "UTC")!
            return calendar.date(from: DateComponents(
                year: time.year.map(Int.init), month: time.month.map(Int.init), day: time.day.map(Int.init),
                hour: time.hour.map(Int.init), minute: time.minute.map(Int.init), second: time.second.map(Int.init)
            ))
        }
        // Fall back to text parsing
        guard let str = data.string, !str.isEmpty else { return nil }
        return Self.dateFormatter.date(from: str)
            ?? Self.dateFormatterNoFrac.date(from: str)
            ?? Self.sqlDateFormatter.date(from: str)
    }

    private nonisolated(unsafe) static let dateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private nonisolated(unsafe) static let dateFormatterNoFrac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private nonisolated(unsafe) static let sqlDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()
}
