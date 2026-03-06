import Foundation

@MainActor @Observable
final class CommandPaletteState {
    var isVisible: Bool = false
    var query: String = ""
    var results: [Issue] = []
    var selectedIndex: Int = 0

    private var dataSource: (any DataSource)?

    func configure(source: ProjectSource) {
        switch source {
        case .sqlite(_, let dbPath):
            self.dataSource = try? SQLiteDataSource(path: dbPath)
        case .dolt(let connection):
            self.dataSource = DoltDataSource(connection: connection)
        }
    }

    func search() {
        guard !query.isEmpty, let ds = dataSource else {
            results = []
            return
        }
        Task {
            do {
                results = try await ds.searchIssues(query: query)
                selectedIndex = 0
            } catch {
                results = []
            }
        }
    }

    func toggle() {
        isVisible.toggle()
        if !isVisible {
            query = ""
            results = []
            selectedIndex = 0
        }
    }

    func moveUp() {
        if selectedIndex > 0 { selectedIndex -= 1 }
    }

    func moveDown() {
        if selectedIndex < results.count - 1 { selectedIndex += 1 }
    }

    var selectedIssue: Issue? {
        guard results.indices.contains(selectedIndex) else { return nil }
        return results[selectedIndex]
    }
}
