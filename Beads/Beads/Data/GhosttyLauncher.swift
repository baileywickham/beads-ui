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

        // Write a temp script to avoid shell quoting issues and Ghostty's -e security prompt
        let scriptDir = FileManager.default.temporaryDirectory.appendingPathComponent("beads-launch")
        try FileManager.default.createDirectory(at: scriptDir, withIntermediateDirectories: true)
        let scriptFile = scriptDir.appendingPathComponent("\(UUID().uuidString).sh")
        let scriptContent = """
            #!/bin/zsh -li
            cd \(shellQuote(projectPath))
            unset CLAUDECODE
            exec claude --dangerously-skip-permissions \(shellQuote(prompt))
            """
        try scriptContent.write(to: scriptFile, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptFile.path)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/Applications/Ghostty.app/Contents/MacOS/ghostty")
        process.currentDirectoryURL = URL(fileURLWithPath: projectPath)
        process.arguments = ["--window-save-state=never", "--command=\(scriptFile.path)"]

        try process.run()
    }

    private static func shellQuote(_ string: String) -> String {
        "'" + string.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
