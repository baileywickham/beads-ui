import Foundation

@Observable
final class CommandPaletteState {
    var isVisible: Bool = false
    var query: String = ""
    var results: [Issue] = []
    var selectedIndex: Int = 0

    private var dbReader: DatabaseReader?

    func configure(dbPath: String) {
        self.dbReader = try? DatabaseReader(path: dbPath)
    }

    func search() {
        guard !query.isEmpty, let reader = dbReader else {
            results = []
            return
        }
        do {
            results = try reader.searchIssues(query: query)
            selectedIndex = 0
        } catch {
            results = []
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
