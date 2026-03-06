import Foundation
import GRDB

struct ProjectDiscovery {
    static let defaultRoots = [
        NSHomeDirectory() + "/workspace"
    ]

    static func discoverProjects(in roots: [String]? = nil) -> [Project] {
        let searchRoots = roots ?? defaultRoots
        var projects: [Project] = []

        let fm = FileManager.default
        for root in searchRoots {
            guard let entries = try? fm.contentsOfDirectory(atPath: root) else { continue }
            for entry in entries {
                let projectPath = (root as NSString).appendingPathComponent(entry)
                let dbPath = (projectPath as NSString)
                    .appendingPathComponent(".beads/beads.db")

                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: dbPath, isDirectory: &isDir), !isDir.boolValue else {
                    continue
                }

                let prefix = readPrefix(dbPath: dbPath) ?? entry
                let name = entry.replacingOccurrences(of: "-", with: " ").capitalized

                projects.append(Project(
                    name: name,
                    source: .sqlite(path: projectPath, dbPath: dbPath),
                    prefix: prefix
                ))
            }
        }

        return projects.sorted { $0.name < $1.name }
    }

    static func discoverDoltProjects(connections: [DoltConnection]) async -> [Project] {
        var projects: [Project] = []

        for conn in connections {
            let ds = DoltDataSource(connection: conn)
            do {
                let databases = try await ds.discoverDatabases()
                for db in databases {
                    var dbConn = conn
                    dbConn.database = db
                    let prefix = db
                    let name = conn.name.map { "\($0)/\(db)" }
                        ?? "\(db) (\(conn.host))"
                    projects.append(Project(
                        name: name,
                        source: .dolt(connection: dbConn),
                        prefix: prefix
                    ))
                }
            } catch {
                // Connection failed — skip this server
                continue
            }
        }

        return projects.sorted { $0.name < $1.name }
    }

    private static func readPrefix(dbPath: String) -> String? {
        var config = Configuration()
        config.readonly = true
        guard let db = try? DatabaseQueue(path: dbPath, configuration: config) else { return nil }
        return try? db.read { db in
            try String.fetchOne(db, sql: "SELECT value FROM config WHERE key = 'issue_prefix'")
        }
    }
}
