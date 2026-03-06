import Foundation

actor SQLiteDataSource: DataSource {
    private let reader: DatabaseReader

    init(path: String) throws {
        self.reader = try DatabaseReader(path: path)
    }

    func fetchIssues(status: IssueStatus? = nil, search: String? = nil) async throws -> [Issue] {
        try reader.fetchIssues(status: status, search: search)
    }

    func fetchIssue(id: String) async throws -> Issue? {
        try reader.fetchIssue(id: id)
    }

    func fetchStatusCounts() async throws -> [IssueStatus: Int] {
        try reader.fetchStatusCounts()
    }

    func searchIssues(query: String) async throws -> [Issue] {
        try reader.searchIssues(query: query)
    }

    func fetchConfig(key: String) async throws -> String? {
        try reader.fetchConfig(key: key)
    }
}
