import Foundation

struct DoltConnection: Codable, Hashable, Identifiable, Sendable {
    var id: String { "\(host):\(port)/\(database)" }
    var host: String
    var port: Int = 3306
    var user: String = "root"
    var password: String?
    var database: String
    var name: String?
    var localPath: String?

    var displayName: String {
        name ?? "\(database) (\(host))"
    }
}

enum SavedConnections {
    private static let key = "doltConnections"

    static func load() -> [DoltConnection] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let connections = try? JSONDecoder().decode([DoltConnection].self, from: data) else {
            return []
        }
        return connections
    }

    static func save(_ connections: [DoltConnection]) {
        if let data = try? JSONEncoder().encode(connections) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func add(_ connection: DoltConnection) {
        var connections = load()
        connections.removeAll { $0.id == connection.id }
        connections.append(connection)
        save(connections)
    }

    static func remove(_ connection: DoltConnection) {
        var connections = load()
        connections.removeAll { $0.id == connection.id }
        save(connections)
    }
}
