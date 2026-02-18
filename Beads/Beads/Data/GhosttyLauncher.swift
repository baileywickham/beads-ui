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

        let escapedPath = projectPath.replacingOccurrences(of: "'", with: "'\\''")
        let escapedPrompt = prompt.replacingOccurrences(of: "'", with: "'\\''")
        let script = "cd '\(escapedPath)' && unset CLAUDECODE && claude --dangerously-skip-permissions '\(escapedPrompt)'"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/Applications/Ghostty.app/Contents/MacOS/ghostty")
        process.arguments = ["-e", "/bin/zsh", "-li", "-c", script]

        try process.run()
    }
}
