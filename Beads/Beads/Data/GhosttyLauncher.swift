import Foundation

enum GhosttyLauncher {
    static func launchClaude(issue: Issue, projectPath: String, comment: String? = nil) async throws {
        let description = issue.description.prefix(500)
        let comments = issue.comments
            .map { "[\($0.author)] \($0.text)" }
            .joined(separator: "\n")
        var prompt = "This is a bead. Use `bd` to manage this issue (e.g. `bd comment`, `bd update`, `bd close`).\n\nWork on \(issue.id): \(issue.title)\n\n\(description)"
        if !comments.isEmpty {
            prompt += "\n\nComments:\n\(comments)"
        }
        if let comment, !comment.isEmpty {
            prompt += "\n\nAdditional instructions:\n\(comment)"
        }

        let script = "cd \"$0\" && unset CLAUDECODE && claude --dangerously-skip-permissions \"$1\""

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-na", "Ghostty", "--args", "-e", "sh", "-c", script, projectPath, prompt]

        try process.run()
    }
}
