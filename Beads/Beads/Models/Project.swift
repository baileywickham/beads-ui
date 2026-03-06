import Foundation

enum ProjectSource: Hashable, Codable {
    case sqlite(path: String, dbPath: String)
    case dolt(connection: DoltConnection)
}

struct Project: Identifiable, Hashable {
    var id: String {
        switch source {
        case .sqlite(_, let dbPath): return dbPath
        case .dolt(let conn): return "dolt://\(conn.id)"
        }
    }
    var name: String
    var source: ProjectSource
    var prefix: String

    var path: String? {
        switch source {
        case .sqlite(let path, _): return path
        case .dolt(let conn): return conn.localPath
        }
    }

    var dbPath: String? {
        switch source {
        case .sqlite(_, let dbPath): return dbPath
        case .dolt: return nil
        }
    }

    var beadsDir: String? {
        guard let path else { return nil }
        return (path as NSString).appendingPathComponent(".beads")
    }

    var isDolt: Bool {
        if case .dolt = source { return true }
        return false
    }
}
