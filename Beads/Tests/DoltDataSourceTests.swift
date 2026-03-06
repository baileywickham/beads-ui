import Testing
import Foundation
@testable import BeadsLib

@Suite("DoltConnection")
struct DoltConnectionTests {
    @Test func idIncludesHostPortDatabase() {
        let conn = DoltConnection(host: "10.0.1.50", port: 3306, database: "myproject")
        #expect(conn.id == "10.0.1.50:3306/myproject")
    }

    @Test func displayNameFallsBackToHostAndDB() {
        let conn = DoltConnection(host: "10.0.1.50", database: "beads")
        #expect(conn.displayName == "beads (10.0.1.50)")
    }

    @Test func displayNameUsesCustomName() {
        let conn = DoltConnection(host: "10.0.1.50", database: "beads", name: "Prod Server")
        #expect(conn.displayName == "Prod Server")
    }

    @Test func savedConnectionsRoundTrip() {
        let conn = DoltConnection(
            host: "test.example.com", port: 3307, user: "testuser",
            password: "secret", database: "testdb", name: "Test",
            localPath: "/tmp/test"
        )
        SavedConnections.add(conn)
        let loaded = SavedConnections.load()
        #expect(loaded.contains(where: { $0.id == conn.id }))

        SavedConnections.remove(conn)
        let afterRemove = SavedConnections.load()
        #expect(!afterRemove.contains(where: { $0.id == conn.id }))
    }
}

@Suite("ProjectSource")
struct ProjectSourceTests {
    @Test func sqliteProjectHasPath() {
        let project = Project(
            name: "Test",
            source: .sqlite(path: "/tmp/project", dbPath: "/tmp/project/.beads/beads.db"),
            prefix: "test"
        )
        #expect(project.path == "/tmp/project")
        #expect(project.dbPath == "/tmp/project/.beads/beads.db")
        #expect(project.isDolt == false)
        #expect(project.beadsDir == "/tmp/project/.beads")
    }

    @Test func doltProjectUsesLocalPath() {
        let conn = DoltConnection(
            host: "10.0.1.50", database: "beads",
            localPath: "/Users/me/workspace/myproject"
        )
        let project = Project(name: "Test", source: .dolt(connection: conn), prefix: "test")
        #expect(project.path == "/Users/me/workspace/myproject")
        #expect(project.dbPath == nil)
        #expect(project.isDolt == true)
    }

    @Test func doltProjectWithoutLocalPath() {
        let conn = DoltConnection(host: "10.0.1.50", database: "beads")
        let project = Project(name: "Test", source: .dolt(connection: conn), prefix: "test")
        #expect(project.path == nil)
        #expect(project.beadsDir == nil)
    }
}

@Suite("SQLiteDataSource")
struct SQLiteDataSourceTests {
    @Test func initializesWithBeadsDB() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("beads-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let bdPath = ("~/.local/bin/bd" as NSString).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: bdPath) else { return }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: bdPath)
        process.arguments = ["init", "--prefix", "test", "--skip-hooks", "--skip-merge-driver"]
        process.currentDirectoryURL = tmp
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()

        let dbPath = tmp.appendingPathComponent(".beads/beads.db").path
        guard FileManager.default.fileExists(atPath: dbPath) else { return }

        let ds = try SQLiteDataSource(path: dbPath)
        let issues = try await ds.fetchIssues(status: nil, search: nil)
        #expect(issues.isEmpty)
    }
}

// MARK: - Dolt Integration Tests
// Requires: dolt sql-server running on 127.0.0.1:3307 with beads_test database
// Setup:
//   1. brew install dolt
//   2. mkdir /tmp/beads_test && cd /tmp/beads_test && dolt init
//   3. dolt sql < schema_and_seed.sql
//   4. dolt sql-server -P 3307 -H 127.0.0.1

private let doltTestConnection = DoltConnection(
    host: "127.0.0.1", port: 3307, user: "root", database: "beads_test"
)

private func doltServerAvailable() async -> Bool {
    let ds = DoltDataSource(connection: doltTestConnection)
    defer { Task { await ds.close() } }
    do {
        try await ds.testConnection()
        return true
    } catch {
        return false
    }
}

/// Helper that creates a DoltDataSource, runs a closure, then closes it.
private func withDolt(_ body: (DoltDataSource) async throws -> Void) async throws {
    let ds = DoltDataSource(connection: doltTestConnection)
    defer { Task { await ds.close() } }
    try await body(ds)
}

@Suite("Dolt Integration", .serialized)
struct DoltIntegrationTests {

    @Test func connectToServer() async throws {
        guard await doltServerAvailable() else {
            print("Skipping: Dolt server not running on 127.0.0.1:3307")
            return
        }
        try await withDolt { ds in
            try await ds.testConnection()
        }
    }

    @Test func fetchAllIssues() async throws {
        guard await doltServerAvailable() else { return }
        try await withDolt { ds in
            let issues = try await ds.fetchIssues(status: nil, search: nil)
            #expect(issues.count == 3)
            // Ordered by priority ASC, updated_at DESC
            #expect(issues[0].id == "test-3") // P0
            #expect(issues[1].id == "test-1") // P1
            #expect(issues[2].id == "test-2") // P2
        }
    }

    @Test func fetchIssuesFilterByStatus() async throws {
        guard await doltServerAvailable() else { return }
        try await withDolt { ds in
            let open = try await ds.fetchIssues(status: .open, search: nil)
            #expect(open.count == 1)
            #expect(open[0].id == "test-1")

            let closed = try await ds.fetchIssues(status: .closed, search: nil)
            #expect(closed.count == 1)
            #expect(closed[0].id == "test-2")

            let inProgress = try await ds.fetchIssues(status: .inProgress, search: nil)
            #expect(inProgress.count == 1)
            #expect(inProgress[0].id == "test-3")
        }
    }

    @Test func fetchIssuesWithLabels() async throws {
        guard await doltServerAvailable() else { return }
        try await withDolt { ds in
            let issues = try await ds.fetchIssues(status: nil, search: nil)

            let test1 = issues.first(where: { $0.id == "test-1" })!
            #expect(test1.labels.sorted() == ["backend", "urgent"])

            let test3 = issues.first(where: { $0.id == "test-3" })!
            #expect(test3.labels == ["frontend"])

            let test2 = issues.first(where: { $0.id == "test-2" })!
            #expect(test2.labels.isEmpty)
        }
    }

    @Test func fetchSingleIssueWithCommentsAndDeps() async throws {
        guard await doltServerAvailable() else { return }
        try await withDolt { ds in
            let issue = try await ds.fetchIssue(id: "test-1")
            #expect(issue != nil)
            #expect(issue!.title == "First test issue")
            #expect(issue!.description == "A description")
            #expect(issue!.status == .open)
            #expect(issue!.priority == .p1)
            #expect(issue!.issueType == .task)
            #expect(issue!.labels.sorted() == ["backend", "urgent"])

            // Comments
            #expect(issue!.comments.count == 2)
            #expect(issue!.comments[0].author == "alice")
            #expect(issue!.comments[0].text == "Looking into this")
            #expect(issue!.comments[1].author == "bob")

            // Reverse dependency: test-3 depends on test-1
            #expect(issue!.dependencies.count == 1)
            #expect(issue!.dependencies[0].dependsOnId == "test-3")
        }
    }

    @Test func fetchSingleIssueWithOutgoingDep() async throws {
        guard await doltServerAvailable() else { return }
        try await withDolt { ds in
            let issue = try await ds.fetchIssue(id: "test-3")
            #expect(issue != nil)
            #expect(issue!.pinned == true)
            #expect(issue!.issueType == .feature)

            // Outgoing dependency: test-3 depends on test-1
            let outgoing = issue!.dependencies.filter { $0.issueId == "test-3" }
            #expect(outgoing.count == 1)
            #expect(outgoing[0].dependsOnId == "test-1")
            #expect(outgoing[0].type == .blocks)
        }
    }

    @Test func fetchNonexistentIssue() async throws {
        guard await doltServerAvailable() else { return }
        try await withDolt { ds in
            let issue = try await ds.fetchIssue(id: "test-999")
            #expect(issue == nil)
        }
    }

    @Test func fetchStatusCounts() async throws {
        guard await doltServerAvailable() else { return }
        try await withDolt { ds in
            let counts = try await ds.fetchStatusCounts()
            #expect(counts[.open] == 1)
            #expect(counts[.closed] == 1)
            #expect(counts[.inProgress] == 1)
            #expect(counts[.blocked] == nil)
        }
    }

    @Test func searchIssuesByTitle() async throws {
        guard await doltServerAvailable() else { return }
        try await withDolt { ds in
            let results = try await ds.searchIssues(query: "progress")
            #expect(results.count == 1)
            #expect(results[0].id == "test-3")
        }
    }

    @Test func searchIssuesById() async throws {
        guard await doltServerAvailable() else { return }
        try await withDolt { ds in
            let results = try await ds.searchIssues(query: "test-2")
            #expect(results.count == 1)
            #expect(results[0].id == "test-2")
        }
    }

    @Test func searchIssuesByDescription() async throws {
        guard await doltServerAvailable() else { return }
        try await withDolt { ds in
            let results = try await ds.searchIssues(query: "Working on")
            #expect(results.count == 1)
            #expect(results[0].id == "test-3")
        }
    }

    @Test func searchNoResults() async throws {
        guard await doltServerAvailable() else { return }
        try await withDolt { ds in
            let results = try await ds.searchIssues(query: "nonexistent_xyz_query")
            #expect(results.isEmpty)
        }
    }

    @Test func fetchConfig() async throws {
        guard await doltServerAvailable() else { return }
        try await withDolt { ds in
            let prefix = try await ds.fetchConfig(key: "issue_prefix")
            #expect(prefix == "test")

            let missing = try await ds.fetchConfig(key: "nonexistent_key")
            #expect(missing == nil)
        }
    }

    @Test func discoverDatabases() async throws {
        guard await doltServerAvailable() else { return }
        try await withDolt { ds in
            let databases = try await ds.discoverDatabases()
            #expect(databases.contains("beads_test"))
            #expect(!databases.contains("information_schema"))
        }
    }

    @Test func datesParsedCorrectly() async throws {
        guard await doltServerAvailable() else { return }
        try await withDolt { ds in
            let issue = try await ds.fetchIssue(id: "test-1")
            #expect(issue != nil)

            let calendar = Calendar(identifier: .gregorian)
            let components = calendar.dateComponents(in: TimeZone(identifier: "UTC")!, from: issue!.createdAt)
            #expect(components.year == 2025)
            #expect(components.month == 1)
            #expect(components.day == 1)
        }
    }

    @Test func issueFieldMapping() async throws {
        guard await doltServerAvailable() else { return }
        try await withDolt { ds in
            let issue = try await ds.fetchIssue(id: "test-1")!
            #expect(issue.createdBy == "tester")
            #expect(issue.owner == "tester")
            #expect(issue.sourceRepo == ".")
            #expect(issue.pinned == false)
            #expect(issue.assignee == nil)
            #expect(issue.closedAt == nil)
            #expect(issue.externalRef == nil)
        }
    }
}
