import Foundation

protocol DataSource: Sendable {
    func fetchIssues(status: IssueStatus?, search: String?) async throws -> [Issue]
    func fetchIssue(id: String) async throws -> Issue?
    func fetchStatusCounts() async throws -> [IssueStatus: Int]
    func searchIssues(query: String) async throws -> [Issue]
    func fetchConfig(key: String) async throws -> String?
}
