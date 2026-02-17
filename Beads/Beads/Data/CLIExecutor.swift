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

    private func run(arguments: [String], dbPath: String) async throws -> CLIResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: bdPath)
        process.arguments = arguments + ["--db", dbPath]

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
        description: String?, labels: [String], dbPath: String
    ) async throws -> String {
        var args = ["create", title, "--type", type.rawValue, "--priority", "P\(priority.rawValue)"]
        if let desc = description, !desc.isEmpty {
            args += ["--description", desc]
        }
        for label in labels {
            args += ["--add-label", label]
        }
        let result = try await run(arguments: args, dbPath: dbPath)
        // bd create outputs the new issue ID
        return result.output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func updateIssue(id: String, field: String, value: String, dbPath: String) async throws {
        _ = try await run(arguments: ["update", id, "--\(field)", value], dbPath: dbPath)
    }

    func updateStatus(id: String, status: IssueStatus, dbPath: String) async throws {
        if status == .closed {
            _ = try await run(arguments: ["close", id], dbPath: dbPath)
        } else {
            _ = try await run(arguments: ["update", id, "--status", status.rawValue], dbPath: dbPath)
        }
    }

    func updatePriority(id: String, priority: IssuePriority, dbPath: String) async throws {
        _ = try await run(arguments: ["update", id, "--priority", "P\(priority.rawValue)"], dbPath: dbPath)
    }

    func updateType(id: String, type: IssueType, dbPath: String) async throws {
        _ = try await run(arguments: ["update", id, "--type", type.rawValue], dbPath: dbPath)
    }

    func updateAssignee(id: String, assignee: String, dbPath: String) async throws {
        _ = try await run(arguments: ["update", id, "--assignee", assignee], dbPath: dbPath)
    }

    func updateTitle(id: String, title: String, dbPath: String) async throws {
        _ = try await run(arguments: ["update", id, "--title", title], dbPath: dbPath)
    }

    func updateDescription(id: String, description: String, dbPath: String) async throws {
        _ = try await run(arguments: ["update", id, "--description", description], dbPath: dbPath)
    }

    func updateDesign(id: String, design: String, dbPath: String) async throws {
        _ = try await run(arguments: ["update", id, "--design", design], dbPath: dbPath)
    }

    func updateNotes(id: String, notes: String, dbPath: String) async throws {
        _ = try await run(arguments: ["update", id, "--notes", notes], dbPath: dbPath)
    }

    func closeIssue(id: String, reason: String?, dbPath: String) async throws {
        var args = ["close", id]
        if let reason, !reason.isEmpty {
            args += ["--reason", reason]
        }
        _ = try await run(arguments: args, dbPath: dbPath)
    }

    func reopenIssue(id: String, dbPath: String) async throws {
        _ = try await run(arguments: ["reopen", id], dbPath: dbPath)
    }

    func addComment(issueId: String, text: String, dbPath: String) async throws {
        _ = try await run(arguments: ["comments", "add", issueId, text], dbPath: dbPath)
    }

    func addLabel(issueId: String, label: String, dbPath: String) async throws {
        _ = try await run(arguments: ["label", "add", issueId, label], dbPath: dbPath)
    }

    func removeLabel(issueId: String, label: String, dbPath: String) async throws {
        _ = try await run(arguments: ["label", "remove", issueId, label], dbPath: dbPath)
    }
}
