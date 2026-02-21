import Foundation

enum ClaudeStreamEvent: Equatable {
    case textDelta(String)
    case sessionId(String)
    case toolUse(id: String, name: String, input: String)
    case toolResult(toolUseId: String, content: String)
    case completed
}

enum ClaudeProcess {
    /// Parse a single NDJSON line into stream events.
    /// Returns any events found and the first session ID encountered (if any).
    static func parseStreamLine(_ jsonLine: String) -> (events: [ClaudeStreamEvent], sessionId: String?) {
        guard let jsonData = jsonLine.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        else { return ([], nil) }

        var events: [ClaudeStreamEvent] = []
        var sessionId: String?

        if let sid = obj["session_id"] as? String {
            sessionId = sid
        }

        if let type = obj["type"] as? String {
            if type == "content_block_delta",
               let delta = obj["delta"] as? [String: Any],
               let text = delta["text"] as? String {
                events.append(.textDelta(text))
            }

            // assistant partial messages contain the full accumulated content.
            // Text is already covered by content_block_delta — only extract tool_use blocks.
            if type == "assistant",
               let message = obj["message"] as? [String: Any],
               let content = message["content"] as? [[String: Any]] {
                for block in content {
                    if block["type"] as? String == "tool_use",
                       let toolId = block["id"] as? String,
                       let name = block["name"] as? String {
                        let input: String
                        if let inputDict = block["input"] as? [String: Any],
                           let jsonData = try? JSONSerialization.data(withJSONObject: inputDict),
                           let jsonStr = String(data: jsonData, encoding: .utf8) {
                            input = jsonStr
                        } else {
                            input = "{}"
                        }
                        events.append(.toolUse(id: toolId, name: name, input: input))
                    }
                }
            }

            if type == "user",
               let message = obj["message"] as? [String: Any],
               let content = message["content"] as? [[String: Any]] {
                for block in content {
                    if block["type"] as? String == "tool_result",
                       let toolUseId = block["tool_use_id"] as? String {
                        let resultContent: String
                        if let contentArr = block["content"] as? [[String: Any]] {
                            resultContent = contentArr.compactMap { $0["text"] as? String }.joined(separator: "\n")
                        } else if let text = block["content"] as? String {
                            resultContent = text
                        } else {
                            resultContent = ""
                        }
                        events.append(.toolResult(toolUseId: toolUseId, content: resultContent))
                    }
                }
            }
        }

        return (events, sessionId)
    }

    /// Parse a JSON response (fallback format) into text and session ID.
    static func parseJsonResponse(_ data: Data) -> (text: String, sessionId: String?)? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        let text = obj["result"] as? String ?? ""
        let sid = obj["session_id"] as? String
        return (text, sid)
    }

    private static func findClaude() -> String? {
        let candidates = [
            ("~/.local/bin/claude" as NSString).expandingTildeInPath,
            "/usr/local/bin/claude",
            "/opt/homebrew/bin/claude",
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    static func send(
        prompt: String,
        sessionId: String?,
        projectPath: String
    ) -> AsyncThrowingStream<ClaudeStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let claudePath = findClaude() else {
                    continuation.finish(throwing: ClaudeError.notInstalled)
                    return
                }

                let process = Process()
                process.executableURL = URL(fileURLWithPath: claudePath)
                process.currentDirectoryURL = URL(fileURLWithPath: projectPath)

                var args = ["-p", prompt, "--output-format", "stream-json", "--verbose", "--include-partial-messages"]
                if let sessionId {
                    args += ["--resume", sessionId]
                }
                process.arguments = args

                var env = ProcessInfo.processInfo.environment
                env.removeValue(forKey: "CLAUDECODE")
                process.environment = env

                let stdout = Pipe()
                let stderr = Pipe()
                process.standardOutput = stdout
                process.standardError = stderr

                continuation.onTermination = { _ in
                    if process.isRunning { process.terminate() }
                }

                do {
                    try process.run()
                } catch {
                    continuation.finish(throwing: error)
                    return
                }

                let handle = stdout.fileHandleForReading
                var capturedSessionId: String?
                var gotStreamOutput = false

                while true {
                    let data = handle.availableData
                    if data.isEmpty { break }

                    guard let line = String(data: data, encoding: .utf8) else { continue }

                    for jsonLine in line.components(separatedBy: "\n") where !jsonLine.isEmpty {
                        let parsed = parseStreamLine(jsonLine)
                        if parsed.events.isEmpty && parsed.sessionId == nil { continue }

                        gotStreamOutput = true

                        if let sid = parsed.sessionId, capturedSessionId == nil {
                            capturedSessionId = sid
                            continuation.yield(.sessionId(sid))
                        }

                        for event in parsed.events {
                            continuation.yield(event)
                        }
                    }
                }

                process.waitUntilExit()

                // Fallback: if stream-json produced no output, try parsing as single JSON
                if !gotStreamOutput {
                    if let fallbackResult = tryJsonFallback(
                        claudePath: claudePath, prompt: prompt,
                        sessionId: sessionId, projectPath: projectPath, env: env
                    ) {
                        if let sid = fallbackResult.sessionId {
                            continuation.yield(.sessionId(sid))
                        }
                        if !fallbackResult.text.isEmpty {
                            continuation.yield(.textDelta(fallbackResult.text))
                        }
                    }
                }

                if process.terminationStatus != 0 && !gotStreamOutput {
                    continuation.finish(throwing: ClaudeError.processExited(Int(process.terminationStatus)))
                } else {
                    continuation.yield(.completed)
                    continuation.finish()
                }
            }
        }
    }

    private static func tryJsonFallback(
        claudePath: String,
        prompt: String,
        sessionId: String?,
        projectPath: String,
        env: [String: String]
    ) -> (text: String, sessionId: String?)? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: claudePath)
        process.currentDirectoryURL = URL(fileURLWithPath: projectPath)

        var args = ["-p", prompt, "--output-format", "json", "--verbose"]
        if let sessionId {
            args += ["--resume", sessionId]
        }
        process.arguments = args
        process.environment = env

        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        return parseJsonResponse(data)
    }

    enum ClaudeError: LocalizedError {
        case notInstalled
        case processExited(Int)

        var errorDescription: String? {
            switch self {
            case .notInstalled:
                return "Claude CLI not found. Install it at ~/.local/bin/claude, /usr/local/bin/claude, or /opt/homebrew/bin/claude"
            case .processExited(let code):
                return "Claude process exited with code \(code)"
            }
        }
    }
}
