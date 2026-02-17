import Foundation

struct Project: Identifiable, Hashable {
    var id: String { path }
    var name: String
    var path: String
    var dbPath: String
    var prefix: String

    var beadsDir: String {
        (path as NSString).appendingPathComponent(".beads")
    }
}
