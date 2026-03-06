import Foundation

actor CLIExecutor {
    private let bdPath: String

    init(bdPath: String = ("~/.local/bin/bd" as NSString).expandingTildeInPath) {
        self.bdPath = bdPath
    }

    struct CLIError: Error, LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    struct CLIResult {
        let output: String
        let exitCode: Int32
    }

    private func run(arguments: [String], source: ProjectSource) async throws -> CLIResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: bdPath)

        switch source {
        case .sqlite(_, let dbPath):
            process.arguments = arguments + ["--db", dbPath]
        case .dolt(let conn):
            process.arguments = arguments + [
                "--backend", "dolt",
                "--server",
                "--server-host", conn.host,
                "--server-port", String(conn.port),
                "--server-user", conn.user,
            ]
            if let password = conn.password {
                var env = ProcessInfo.processInfo.environment
                env["BEADS_DOLT_PASSWORD"] = password
                process.environment = env
            }
        }

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        let outData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errData = stderr.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outData, encoding: .utf8) ?? ""
        let errOutput = String(data: errData, encoding: .utf8) ?? ""

        if process.terminationStatus != 0 {
            let msg = errOutput.isEmpty ? output : errOutput
            throw CLIError(message: msg.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return CLIResult(output: output, exitCode: process.terminationStatus)
    }

    // MARK: - Write Operations

    func createIssue(
        title: String, type: IssueType, priority: IssuePriority,
        description: String?, labels: [String], source: ProjectSource
    ) async throws -> String {
        var args = ["create", title, "--type", type.rawValue, "--priority", "P\(priority.rawValue)"]
        if let desc = description, !desc.isEmpty {
            args += ["--description", desc]
        }
        for label in labels {
            args += ["--add-label", label]
        }
        let result = try await run(arguments: args, source: source)
        return result.output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func updateIssue(id: String, field: String, value: String, source: ProjectSource) async throws {
        _ = try await run(arguments: ["update", id, "--\(field)", value], source: source)
    }

    func updateStatus(id: String, status: IssueStatus, source: ProjectSource) async throws {
        if status == .closed {
            _ = try await run(arguments: ["close", id], source: source)
        } else {
            _ = try await run(arguments: ["update", id, "--status", status.rawValue], source: source)
        }
    }

    func updatePriority(id: String, priority: IssuePriority, source: ProjectSource) async throws {
        _ = try await run(arguments: ["update", id, "--priority", "P\(priority.rawValue)"], source: source)
    }

    func updateType(id: String, type: IssueType, source: ProjectSource) async throws {
        _ = try await run(arguments: ["update", id, "--type", type.rawValue], source: source)
    }

    func updateAssignee(id: String, assignee: String, source: ProjectSource) async throws {
        _ = try await run(arguments: ["update", id, "--assignee", assignee], source: source)
    }

    func updateTitle(id: String, title: String, source: ProjectSource) async throws {
        _ = try await run(arguments: ["update", id, "--title", title], source: source)
    }

    func updateDescription(id: String, description: String, source: ProjectSource) async throws {
        _ = try await run(arguments: ["update", id, "--description", description], source: source)
    }

    func updateDesign(id: String, design: String, source: ProjectSource) async throws {
        _ = try await run(arguments: ["update", id, "--design", design], source: source)
    }

    func updateNotes(id: String, notes: String, source: ProjectSource) async throws {
        _ = try await run(arguments: ["update", id, "--notes", notes], source: source)
    }

    func closeIssue(id: String, reason: String?, source: ProjectSource) async throws {
        var args = ["close", id]
        if let reason, !reason.isEmpty {
            args += ["--reason", reason]
        }
        _ = try await run(arguments: args, source: source)
    }

    func reopenIssue(id: String, source: ProjectSource) async throws {
        _ = try await run(arguments: ["reopen", id], source: source)
    }

    func addComment(issueId: String, text: String, source: ProjectSource) async throws {
        _ = try await run(arguments: ["comments", "add", issueId, text], source: source)
    }

    func addLabel(issueId: String, label: String, source: ProjectSource) async throws {
        _ = try await run(arguments: ["label", "add", issueId, label], source: source)
    }

    func removeLabel(issueId: String, label: String, source: ProjectSource) async throws {
        _ = try await run(arguments: ["label", "remove", issueId, label], source: source)
    }
}
