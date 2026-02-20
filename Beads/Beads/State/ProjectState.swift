import Foundation
import SwiftUI

@MainActor @Observable
final class ProjectState {
    let project: Project
    let cliExecutor: CLIExecutor

    var issues: [Issue] = []
    var selectedIssueId: String?
    var selectedIssue: Issue?
    var statusFilter: IssueStatus? = .open
    var searchText: String = ""
    var errorMessage: String?
    var isLoading: Bool = false
    var showCreateSheet: Bool = false

    private var dbReader: DatabaseReader?
    private var watcher: DatabaseWatcher?
    private var lastLaunchTime: ContinuousClock.Instant = .now - .seconds(10)

    init(project: Project, cliExecutor: CLIExecutor) {
        self.project = project
        self.cliExecutor = cliExecutor
        do {
            self.dbReader = try DatabaseReader(path: project.dbPath)
        } catch {
            self.errorMessage = "Failed to open database: \(error.localizedDescription)"
        }
    }

    var statusCounts: [IssueStatus: Int] {
        var counts: [IssueStatus: Int] = [:]
        for issue in issues {
            counts[issue.status, default: 0] += 1
        }
        return counts
    }

    var filteredIssues: [Issue] {
        issues.filter { issue in
            if let filter = statusFilter, issue.status != filter {
                return false
            }
            if !searchText.isEmpty {
                let q = searchText.lowercased()
                return issue.title.lowercased().contains(q) ||
                    issue.id.lowercased().contains(q) ||
                    issue.labels.contains(where: { $0.lowercased().contains(q) })
            }
            return true
        }
    }

    // MARK: - Data Loading

    func loadIssues() {
        guard let reader = dbReader else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            issues = try reader.fetchIssues()
            // Refresh selected issue detail
            if let id = selectedIssueId {
                selectedIssue = try reader.fetchIssue(id: id)
            }
        } catch {
            errorMessage = "Failed to load issues: \(error.localizedDescription)"
        }
    }

    func selectIssue(_ issue: Issue) {
        selectedIssueId = issue.id
        loadIssueDetail(id: issue.id)
    }

    func loadIssueDetail(id: String) {
        guard let reader = dbReader else { return }
        do {
            selectedIssue = try reader.fetchIssue(id: id)
        } catch {
            errorMessage = "Failed to load issue: \(error.localizedDescription)"
        }
    }

    // MARK: - File Watching

    func startWatching() {
        watcher = DatabaseWatcher(directory: project.beadsDir) { [weak self] in
            self?.loadIssues()
        }
    }

    func stopWatching() {
        watcher?.stop()
        watcher = nil
    }

    // MARK: - Navigation

    func selectNextIssue() {
        let list = filteredIssues
        guard !list.isEmpty else { return }
        if let current = selectedIssueId,
           let idx = list.firstIndex(where: { $0.id == current }),
           idx + 1 < list.count {
            selectIssue(list[idx + 1])
        } else if let first = list.first {
            selectIssue(first)
        }
    }

    func selectPreviousIssue() {
        let list = filteredIssues
        guard !list.isEmpty else { return }
        if let current = selectedIssueId,
           let idx = list.firstIndex(where: { $0.id == current }),
           idx > 0 {
            selectIssue(list[idx - 1])
        } else if let last = list.last {
            selectIssue(last)
        }
    }

    func closeAndAdvance(_ id: String) {
        // Compute next issue before the optimistic update changes filteredIssues
        let list = filteredIssues
        let nextIssue: Issue? = {
            guard let idx = list.firstIndex(where: { $0.id == id }) else { return nil }
            if idx + 1 < list.count { return list[idx + 1] }
            if idx > 0 { return list[idx - 1] }
            return nil
        }()

        updateStatus(id, to: .closed)

        if let next = nextIssue {
            selectIssue(next)
        }
    }

    // MARK: - Write Operations (Optimistic)

    func updateStatus(_ id: String, to status: IssueStatus) {
        let oldIssues = issues
        let oldDetail = selectedIssue

        // Optimistic
        if let idx = issues.firstIndex(where: { $0.id == id }) {
            issues[idx].status = status
        }
        if selectedIssue?.id == id { selectedIssue?.status = status }

        Task {
            do {
                try await cliExecutor.updateStatus(id: id, status: status, dbPath: project.dbPath)
            } catch {
                self.issues = oldIssues
                self.selectedIssue = oldDetail
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func updatePriority(_ id: String, to priority: IssuePriority) {
        let oldIssues = issues
        if let idx = issues.firstIndex(where: { $0.id == id }) {
            issues[idx].priority = priority
        }
        if selectedIssue?.id == id { selectedIssue?.priority = priority }

        Task {
            do {
                try await cliExecutor.updatePriority(id: id, priority: priority, dbPath: project.dbPath)
            } catch {
                self.issues = oldIssues
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func updateTitle(_ id: String, to title: String) {
        let oldIssues = issues
        if let idx = issues.firstIndex(where: { $0.id == id }) {
            issues[idx].title = title
        }
        if selectedIssue?.id == id { selectedIssue?.title = title }

        Task {
            do {
                try await cliExecutor.updateTitle(id: id, title: title, dbPath: project.dbPath)
            } catch {
                self.issues = oldIssues
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func updateField(_ id: String, field: String, value: String) {
        Task {
            do {
                switch field {
                case "description":
                    try await cliExecutor.updateDescription(id: id, description: value, dbPath: project.dbPath)
                case "design":
                    try await cliExecutor.updateDesign(id: id, design: value, dbPath: project.dbPath)
                case "notes":
                    try await cliExecutor.updateNotes(id: id, notes: value, dbPath: project.dbPath)
                default:
                    try await cliExecutor.updateIssue(id: id, field: field, value: value, dbPath: project.dbPath)
                }
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func createIssue(
        title: String, type: IssueType, priority: IssuePriority,
        description: String?, labels: [String]
    ) {
        Task {
            do {
                _ = try await cliExecutor.createIssue(
                    title: title, type: type, priority: priority,
                    description: description, labels: labels, dbPath: project.dbPath)
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func launchClaude(_ issueId: String, comment: String? = nil) {
        let now = ContinuousClock.Instant.now
        guard now - lastLaunchTime > .seconds(1) else { return }
        lastLaunchTime = now

        guard let issue = (selectedIssue?.id == issueId ? selectedIssue : nil)
                ?? issues.first(where: { $0.id == issueId }) else { return }
        Task {
            do {
                try await GhosttyLauncher.launchClaude(issue: issue, projectPath: project.path, comment: comment)
            } catch {
                self.errorMessage = "Failed to launch Claude: \(error.localizedDescription)"
            }
        }
    }

    func addComment(_ issueId: String, text: String) {
        Task {
            do {
                try await cliExecutor.addComment(issueId: issueId, text: text, dbPath: project.dbPath)
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }
}
