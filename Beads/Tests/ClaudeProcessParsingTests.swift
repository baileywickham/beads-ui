import Foundation
import Testing
@testable import BeadsLib

@Suite("ClaudeProcess NDJSON Parsing")
struct ClaudeProcessParsingTests {

    // MARK: - stream_event text deltas

    @Test func streamEventTextDelta() {
        let json = """
        {"type":"stream_event","event":{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"hello"}},"session_id":"sess-1"}
        """
        let result = ClaudeProcess.parseStreamLine(json)
        #expect(result.events == [.textDelta("hello")])
        #expect(result.sessionId == "sess-1")
    }

    @Test func streamEventMultipleTextDeltas() {
        let lines = [
            """
            {"type":"stream_event","event":{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hello"}},"session_id":"sess-1"}
            """,
            """
            {"type":"stream_event","event":{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":" world"}},"session_id":"sess-1"}
            """,
        ]
        var accumulated = ""
        for line in lines {
            let result = ClaudeProcess.parseStreamLine(line)
            for event in result.events {
                if case .textDelta(let text) = event { accumulated += text }
            }
        }
        #expect(accumulated == "Hello world")
    }

    @Test func streamEventInputJsonDeltaIgnored() {
        // Tool input streaming uses input_json_delta — should not produce events
        let json = """
        {"type":"stream_event","event":{"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"{\\"command\\""}},"session_id":"sess-1"}
        """
        let result = ClaudeProcess.parseStreamLine(json)
        #expect(result.events.isEmpty)
        #expect(result.sessionId == "sess-1")
    }

    @Test func streamEventContentBlockStartIgnored() {
        let json = """
        {"type":"stream_event","event":{"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}},"session_id":"sess-1"}
        """
        let result = ClaudeProcess.parseStreamLine(json)
        #expect(result.events.isEmpty)
    }

    @Test func streamEventContentBlockStopIgnored() {
        let json = """
        {"type":"stream_event","event":{"type":"content_block_stop","index":0},"session_id":"sess-1"}
        """
        let result = ClaudeProcess.parseStreamLine(json)
        #expect(result.events.isEmpty)
    }

    @Test func streamEventMessageStartIgnored() {
        let json = """
        {"type":"stream_event","event":{"type":"message_start","message":{"model":"claude-opus-4-6","id":"msg_01","type":"message","role":"assistant"}},"session_id":"sess-1"}
        """
        let result = ClaudeProcess.parseStreamLine(json)
        #expect(result.events.isEmpty)
    }

    @Test func streamEventMessageDeltaIgnored() {
        let json = """
        {"type":"stream_event","event":{"type":"message_delta","delta":{"stop_reason":"end_turn"}},"session_id":"sess-1"}
        """
        let result = ClaudeProcess.parseStreamLine(json)
        #expect(result.events.isEmpty)
    }

    @Test func streamEventMessageStopIgnored() {
        let json = """
        {"type":"stream_event","event":{"type":"message_stop"},"session_id":"sess-1"}
        """
        let result = ClaudeProcess.parseStreamLine(json)
        #expect(result.events.isEmpty)
    }

    @Test func streamEventToolUseBlockStartIgnored() {
        // Tool use content_block_start — tool call data comes from assistant messages
        let json = """
        {"type":"stream_event","event":{"type":"content_block_start","index":0,"content_block":{"type":"tool_use","id":"toolu_01","name":"Bash","input":{}}},"session_id":"sess-1"}
        """
        let result = ClaudeProcess.parseStreamLine(json)
        #expect(result.events.isEmpty)
    }

    // MARK: - assistant messages (tool_use extraction)

    @Test func assistantMessageIgnoresTextBlocks() {
        let json = """
        {"type":"assistant","message":{"content":[{"type":"text","text":"accumulated text"}]},"session_id":"sess-1"}
        """
        let result = ClaudeProcess.parseStreamLine(json)
        #expect(result.events.isEmpty)
        #expect(result.sessionId == "sess-1")
    }

    @Test func assistantToolUseExtracted() {
        let json = """
        {"type":"assistant","message":{"content":[{"type":"tool_use","id":"toolu_01","name":"Read","input":{"file_path":"/tmp/file"}}]},"session_id":"sess-1"}
        """
        let result = ClaudeProcess.parseStreamLine(json)
        #expect(result.events.count == 1)
        guard case .toolUse(let id, let name, let input) = result.events.first else {
            Issue.record("Expected toolUse, got \(result.events)")
            return
        }
        #expect(id == "toolu_01")
        #expect(name == "Read")
        #expect(input.contains("file_path"))
    }

    @Test func assistantMixedTextAndToolUse() {
        let json = """
        {"type":"assistant","message":{"content":[{"type":"text","text":"checking..."},{"type":"tool_use","id":"toolu_02","name":"Bash","input":{"command":"ls"}}]},"session_id":"sess-1"}
        """
        let result = ClaudeProcess.parseStreamLine(json)
        #expect(result.events.count == 1)
        guard case .toolUse(_, let name, _) = result.events[0] else {
            Issue.record("Expected toolUse")
            return
        }
        #expect(name == "Bash")
    }

    @Test func assistantMultipleToolUseBlocks() {
        let json = """
        {"type":"assistant","message":{"content":[{"type":"tool_use","id":"t1","name":"Bash","input":{"command":"echo first"}},{"type":"tool_use","id":"t2","name":"Bash","input":{"command":"echo second"}}]},"session_id":"sess-1"}
        """
        let result = ClaudeProcess.parseStreamLine(json)
        #expect(result.events.count == 2)
        guard case .toolUse(let id1, _, _) = result.events[0],
              case .toolUse(let id2, _, _) = result.events[1] else {
            Issue.record("Expected two toolUse events")
            return
        }
        #expect(id1 == "t1")
        #expect(id2 == "t2")
    }

    @Test func assistantToolUseInputSerialization() {
        let json = """
        {"type":"assistant","message":{"content":[{"type":"tool_use","id":"tu-3","name":"Edit","input":{"file":"a.txt","line":42}}]}}
        """
        let result = ClaudeProcess.parseStreamLine(json)
        guard case .toolUse(_, _, let input) = result.events.first else {
            Issue.record("Expected toolUse")
            return
        }
        let data = input.data(using: .utf8)!
        let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(parsed != nil)
        #expect(parsed?["file"] as? String == "a.txt")
        #expect(parsed?["line"] as? Int == 42)
    }

    @Test func assistantToolUseWithEmptyInput() {
        let json = """
        {"type":"assistant","message":{"content":[{"type":"tool_use","id":"t1","name":"Read","input":{}}]}}
        """
        let result = ClaudeProcess.parseStreamLine(json)
        guard case .toolUse(_, _, let input) = result.events.first else {
            Issue.record("Expected toolUse")
            return
        }
        #expect(input == "{}")
    }

    // MARK: - user messages (tool_result extraction)

    @Test func userToolResultWithArrayContent() {
        let json = """
        {"type":"user","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_01","content":[{"text":"file contents here"}],"is_error":false}]},"session_id":"sess-1"}
        """
        let result = ClaudeProcess.parseStreamLine(json)
        #expect(result.events.count == 1)
        guard case .toolResult(let toolUseId, let content) = result.events.first else {
            Issue.record("Expected toolResult, got \(result.events)")
            return
        }
        #expect(toolUseId == "toolu_01")
        #expect(content == "file contents here")
    }

    @Test func userToolResultWithStringContent() {
        let json = """
        {"type":"user","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_01","content":"hello-from-claude","is_error":false}]},"session_id":"sess-1"}
        """
        let result = ClaudeProcess.parseStreamLine(json)
        guard case .toolResult(let id, let content) = result.events.first else {
            Issue.record("Expected toolResult")
            return
        }
        #expect(id == "toolu_01")
        #expect(content == "hello-from-claude")
    }

    @Test func userToolResultWithNoContent() {
        let json = """
        {"type":"user","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_01"}]}}
        """
        let result = ClaudeProcess.parseStreamLine(json)
        guard case .toolResult(_, let content) = result.events.first else {
            Issue.record("Expected toolResult")
            return
        }
        #expect(content == "")
    }

    @Test func userMultipleToolResults() {
        let json = """
        {"type":"user","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"t1","content":"first"},{"type":"tool_result","tool_use_id":"t2","content":"second"}]}}
        """
        let result = ClaudeProcess.parseStreamLine(json)
        #expect(result.events.count == 2)
        guard case .toolResult(let id1, let c1) = result.events[0],
              case .toolResult(let id2, let c2) = result.events[1] else {
            Issue.record("Expected two toolResult events")
            return
        }
        #expect(id1 == "t1")
        #expect(c1 == "first")
        #expect(id2 == "t2")
        #expect(c2 == "second")
    }

    // MARK: - Session ID

    @Test func sessionIdFromInit() {
        let json = """
        {"type":"system","subtype":"init","session_id":"sess-abc123"}
        """
        let result = ClaudeProcess.parseStreamLine(json)
        #expect(result.sessionId == "sess-abc123")
        #expect(result.events.isEmpty)
    }

    @Test func sessionIdFromResult() {
        let json = """
        {"type":"result","subtype":"success","session_id":"sess-xyz","result":"done"}
        """
        let result = ClaudeProcess.parseStreamLine(json)
        #expect(result.sessionId == "sess-xyz")
        #expect(result.events.isEmpty)
    }

    @Test func sessionIdFromStreamEvent() {
        let json = """
        {"type":"stream_event","event":{"type":"message_start"},"session_id":"sess-from-stream"}
        """
        let result = ClaudeProcess.parseStreamLine(json)
        #expect(result.sessionId == "sess-from-stream")
    }

    @Test func sessionIdFromAssistantMessage() {
        let json = """
        {"type":"assistant","session_id":"sess-asst","message":{"content":[{"type":"text","text":"hi"}]}}
        """
        let result = ClaudeProcess.parseStreamLine(json)
        #expect(result.sessionId == "sess-asst")
        #expect(result.events.isEmpty)
    }

    // MARK: - Skipped line types

    @Test func systemHookEventIgnored() {
        let json = """
        {"type":"system","subtype":"hook_started","hook_id":"abc","session_id":"sess-1"}
        """
        let result = ClaudeProcess.parseStreamLine(json)
        #expect(result.events.isEmpty)
        #expect(result.sessionId == "sess-1")
    }

    @Test func systemHookResponseIgnored() {
        let json = """
        {"type":"system","subtype":"hook_response","hook_id":"abc","output":"long hook output...","session_id":"sess-1"}
        """
        let result = ClaudeProcess.parseStreamLine(json)
        #expect(result.events.isEmpty)
    }

    @Test func rateLimitEventIgnored() {
        let json = """
        {"type":"rate_limit_event","rate_limit_info":{"status":"allowed"},"session_id":"sess-1"}
        """
        let result = ClaudeProcess.parseStreamLine(json)
        #expect(result.events.isEmpty)
        #expect(result.sessionId == "sess-1")
    }

    @Test func unknownTypeIgnored() {
        let json = """
        {"type":"ping"}
        """
        let result = ClaudeProcess.parseStreamLine(json)
        #expect(result.events.isEmpty)
        #expect(result.sessionId == nil)
    }

    // MARK: - Edge cases

    @Test func malformedJsonReturnsEmpty() {
        let result = ClaudeProcess.parseStreamLine("not json at all")
        #expect(result.events.isEmpty)
        #expect(result.sessionId == nil)
    }

    @Test func emptyStringReturnsEmpty() {
        let result = ClaudeProcess.parseStreamLine("")
        #expect(result.events.isEmpty)
        #expect(result.sessionId == nil)
    }

    @Test func missingTypeFieldReturnsEmpty() {
        let result = ClaudeProcess.parseStreamLine("""
        {"session_id":"sess-1","data":"something"}
        """)
        #expect(result.events.isEmpty)
        #expect(result.sessionId == "sess-1")
    }

    @Test func streamEventWithMissingDelta() {
        let json = """
        {"type":"stream_event","event":{"type":"content_block_delta"},"session_id":"sess-1"}
        """
        let result = ClaudeProcess.parseStreamLine(json)
        #expect(result.events.isEmpty)
    }

    @Test func streamEventWithMissingTextField() {
        let json = """
        {"type":"stream_event","event":{"type":"content_block_delta","delta":{"type":"text_delta"}},"session_id":"sess-1"}
        """
        let result = ClaudeProcess.parseStreamLine(json)
        #expect(result.events.isEmpty)
    }

    // MARK: - parseJsonResponse

    @Test func parseJsonResponseWithResult() {
        let json = """
        {"result":"hello world","session_id":"sess-fallback"}
        """
        let data = json.data(using: .utf8)!
        let result = ClaudeProcess.parseJsonResponse(data)
        #expect(result != nil)
        #expect(result?.text == "hello world")
        #expect(result?.sessionId == "sess-fallback")
    }

    @Test func parseJsonResponseWithoutSessionId() {
        let json = """
        {"result":"just text"}
        """
        let data = json.data(using: .utf8)!
        let result = ClaudeProcess.parseJsonResponse(data)
        #expect(result?.text == "just text")
        #expect(result?.sessionId == nil)
    }

    @Test func parseJsonResponseInvalidData() {
        let data = "not json".data(using: .utf8)!
        let result = ClaudeProcess.parseJsonResponse(data)
        #expect(result == nil)
    }

    // MARK: - Full stream sequence tests (from real captures)

    @Test func simpleTextStream() {
        // Based on capture 01: "What is 2+2?" → "4"
        let lines = [
            """
            {"type":"system","subtype":"init","session_id":"sess-simple"}
            """,
            """
            {"type":"stream_event","event":{"type":"message_start","message":{"model":"claude-opus-4-6"}},"session_id":"sess-simple"}
            """,
            """
            {"type":"stream_event","event":{"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}},"session_id":"sess-simple"}
            """,
            """
            {"type":"stream_event","event":{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"4"}},"session_id":"sess-simple"}
            """,
            """
            {"type":"assistant","message":{"content":[{"type":"text","text":"4"}]},"session_id":"sess-simple"}
            """,
            """
            {"type":"stream_event","event":{"type":"content_block_stop","index":0},"session_id":"sess-simple"}
            """,
            """
            {"type":"stream_event","event":{"type":"message_delta","delta":{"stop_reason":"end_turn"}},"session_id":"sess-simple"}
            """,
            """
            {"type":"result","subtype":"success","session_id":"sess-simple","result":"4"}
            """,
        ]

        var text = ""
        var sid: String?
        for line in lines {
            let parsed = ClaudeProcess.parseStreamLine(line)
            if let s = parsed.sessionId, sid == nil { sid = s }
            for event in parsed.events {
                if case .textDelta(let t) = event { text += t }
            }
        }
        #expect(text == "4")
        #expect(sid == "sess-simple")
    }

    @Test func bashToolCallStream() {
        // Based on capture 04: "echo hello-from-claude" → tool call → "Done."
        let lines = [
            """
            {"type":"system","subtype":"init","session_id":"sess-bash"}
            """,
            // Tool use streaming (input_json_delta — should be ignored)
            """
            {"type":"stream_event","event":{"type":"content_block_start","index":0,"content_block":{"type":"tool_use","id":"toolu_01","name":"Bash","input":{}}},"session_id":"sess-bash"}
            """,
            """
            {"type":"stream_event","event":{"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"{\\"command\\": \\"echo hello\\"}"}},"session_id":"sess-bash"}
            """,
            // Assistant message with complete tool_use
            """
            {"type":"assistant","message":{"content":[{"type":"tool_use","id":"toolu_01","name":"Bash","input":{"command":"echo hello-from-claude","description":"Print hello"}}]},"session_id":"sess-bash"}
            """,
            // Tool result
            """
            {"type":"user","message":{"role":"user","content":[{"tool_use_id":"toolu_01","type":"tool_result","content":"hello-from-claude","is_error":false}]},"session_id":"sess-bash"}
            """,
            // Response text
            """
            {"type":"stream_event","event":{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Done."}},"session_id":"sess-bash"}
            """,
            """
            {"type":"assistant","message":{"content":[{"type":"text","text":"Done."}]},"session_id":"sess-bash"}
            """,
            """
            {"type":"result","subtype":"success","session_id":"sess-bash","result":"Done."}
            """,
        ]

        var textParts: [String] = []
        var toolCalls: [(id: String, name: String, input: String)] = []
        var toolResults: [(id: String, content: String)] = []

        for line in lines {
            let parsed = ClaudeProcess.parseStreamLine(line)
            for event in parsed.events {
                switch event {
                case .textDelta(let t): textParts.append(t)
                case .toolUse(let id, let name, let input): toolCalls.append((id, name, input))
                case .toolResult(let id, let content): toolResults.append((id, content))
                default: break
                }
            }
        }

        #expect(toolCalls.count == 1)
        #expect(toolCalls[0].name == "Bash")
        #expect(toolCalls[0].id == "toolu_01")
        #expect(toolResults.count == 1)
        #expect(toolResults[0].content == "hello-from-claude")
        #expect(textParts.joined() == "Done.")
    }

    @Test func globToolCallStream() {
        // Based on capture 02: Glob tool call → file list → text response
        let lines = [
            """
            {"type":"system","subtype":"init","session_id":"sess-glob"}
            """,
            """
            {"type":"stream_event","event":{"type":"content_block_start","index":0,"content_block":{"type":"tool_use","id":"toolu_glob","name":"Glob","input":{}}},"session_id":"sess-glob"}
            """,
            """
            {"type":"stream_event","event":{"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"{\\"pattern\\": \\"*.swift\\"}"}},"session_id":"sess-glob"}
            """,
            """
            {"type":"assistant","message":{"content":[{"type":"tool_use","id":"toolu_glob","name":"Glob","input":{"pattern":"Beads/Beads/Models/*.swift"}}]},"session_id":"sess-glob"}
            """,
            """
            {"type":"user","message":{"role":"user","content":[{"tool_use_id":"toolu_glob","type":"tool_result","content":"Issue.swift\\nComment.swift\\nProject.swift"}]},"session_id":"sess-glob"}
            """,
            """
            {"type":"stream_event","event":{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Here"}},"session_id":"sess-glob"}
            """,
            """
            {"type":"stream_event","event":{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":" are the files."}},"session_id":"sess-glob"}
            """,
            """
            {"type":"result","subtype":"success","session_id":"sess-glob"}
            """,
        ]

        var text = ""
        var toolCalls: [(id: String, name: String)] = []
        var toolResults: [(id: String, content: String)] = []

        for line in lines {
            let parsed = ClaudeProcess.parseStreamLine(line)
            for event in parsed.events {
                switch event {
                case .textDelta(let t): text += t
                case .toolUse(let id, let name, _): toolCalls.append((id, name))
                case .toolResult(let id, let content): toolResults.append((id, content))
                default: break
                }
            }
        }

        #expect(toolCalls.count == 1)
        #expect(toolCalls[0].name == "Glob")
        #expect(toolResults.count == 1)
        #expect(toolResults[0].content.contains("Issue.swift"))
        #expect(text == "Here are the files.")
    }

    @Test func twoParallelBashCommands() {
        // Based on capture 08: Two Bash commands in one turn, results come separately
        let lines = [
            """
            {"type":"system","subtype":"init","session_id":"sess-2bash"}
            """,
            // First tool_use
            """
            {"type":"assistant","message":{"content":[{"type":"tool_use","id":"t1","name":"Bash","input":{"command":"echo first"}}]},"session_id":"sess-2bash"}
            """,
            // Second tool_use (separate assistant message per content block)
            """
            {"type":"assistant","message":{"content":[{"type":"tool_use","id":"t2","name":"Bash","input":{"command":"echo second"}}]},"session_id":"sess-2bash"}
            """,
            // Results come as separate user messages
            """
            {"type":"user","message":{"role":"user","content":[{"tool_use_id":"t1","type":"tool_result","content":"first","is_error":false}]},"session_id":"sess-2bash"}
            """,
            """
            {"type":"user","message":{"role":"user","content":[{"tool_use_id":"t2","type":"tool_result","content":"second","is_error":false}]},"session_id":"sess-2bash"}
            """,
            // Follow-up text
            """
            {"type":"stream_event","event":{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Done — both ran."}},"session_id":"sess-2bash"}
            """,
        ]

        var toolCalls: [(id: String, name: String)] = []
        var toolResults: [(id: String, content: String)] = []
        var text = ""

        for line in lines {
            let parsed = ClaudeProcess.parseStreamLine(line)
            for event in parsed.events {
                switch event {
                case .textDelta(let t): text += t
                case .toolUse(let id, let name, _): toolCalls.append((id, name))
                case .toolResult(let id, let content): toolResults.append((id, content))
                default: break
                }
            }
        }

        #expect(toolCalls.count == 2)
        #expect(toolCalls[0].id == "t1")
        #expect(toolCalls[1].id == "t2")
        #expect(toolResults.count == 2)
        #expect(toolResults[0].content == "first")
        #expect(toolResults[1].content == "second")
        #expect(text == "Done — both ran.")
    }

    @Test func toolCallFollowedByTextInSameSession() {
        // Multi-turn: tool call → result → more text (like captures 02, 04)
        // Verifies session_id consistency across turns
        let lines = [
            """
            {"type":"system","subtype":"init","session_id":"sess-multi"}
            """,
            """
            {"type":"stream_event","event":{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Let me "}},"session_id":"sess-multi"}
            """,
            """
            {"type":"stream_event","event":{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"check."}},"session_id":"sess-multi"}
            """,
            """
            {"type":"assistant","message":{"content":[{"type":"tool_use","id":"t1","name":"Read","input":{"file_path":"/tmp/test.swift"}}]},"session_id":"sess-multi"}
            """,
            """
            {"type":"user","message":{"role":"user","content":[{"tool_use_id":"t1","type":"tool_result","content":"import Foundation\\nstruct Foo {}"}]},"session_id":"sess-multi"}
            """,
            """
            {"type":"stream_event","event":{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"The file defines `Foo`."}},"session_id":"sess-multi"}
            """,
        ]

        var allText = ""
        var sessionIds: Set<String> = []

        for line in lines {
            let parsed = ClaudeProcess.parseStreamLine(line)
            if let sid = parsed.sessionId { sessionIds.insert(sid) }
            for event in parsed.events {
                if case .textDelta(let t) = event { allText += t }
            }
        }

        #expect(allText == "Let me check.The file defines `Foo`.")
        #expect(sessionIds == ["sess-multi"])
    }

    @Test func markdownResponseStream() {
        // Text with markdown formatting (backticks, code blocks, newlines)
        let lines = [
            """
            {"type":"stream_event","event":{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Here's a "}},"session_id":"sess-md"}
            """,
            """
            {"type":"stream_event","event":{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Swift example:\\n\\n```swift"}},"session_id":"sess-md"}
            """,
            """
            {"type":"stream_event","event":{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"\\nlet x = 42\\n```"}},"session_id":"sess-md"}
            """,
        ]

        var text = ""
        for line in lines {
            let parsed = ClaudeProcess.parseStreamLine(line)
            for event in parsed.events {
                if case .textDelta(let t) = event { text += t }
            }
        }

        #expect(text.contains("```swift"))
        #expect(text.contains("let x = 42"))
    }

    // MARK: - Backward compatibility with bare events (legacy format)

    @Test func bareContentBlockDeltaNoLongerEmitsText() {
        // Old format without stream_event wrapper — should NOT produce text
        // (real CLI always wraps in stream_event)
        let json = """
        {"type":"content_block_delta","delta":{"text":"hello"}}
        """
        let result = ClaudeProcess.parseStreamLine(json)
        #expect(result.events.isEmpty)
    }

    // MARK: - Real CLI output (captured from claude v2.1.69 --output-format stream-json --verbose --include-partial-messages)

    @Test func realCLIOutputWithHooksAndExtraFields() {
        // Real output includes hook_started, hook_response (huge), init with tools/mcp_servers,
        // uuid/parent_tool_use_id on every line, context_management on assistant messages.
        // Parser must handle these extra fields without breaking.
        let lines = [
            #"{"type":"system","subtype":"hook_started","hook_id":"e5c6","hook_name":"SessionStart:startup","hook_event":"SessionStart","uuid":"1f51","session_id":"sess-real"}"#,
            #"{"type":"system","subtype":"hook_response","hook_id":"e5c6","hook_name":"SessionStart:startup","output":"long hook output...","stdout":"long hook output...","stderr":"","exit_code":0,"outcome":"success","uuid":"7101","session_id":"sess-real"}"#,
            #"{"type":"system","subtype":"init","cwd":"/tmp","session_id":"sess-real","tools":["Bash","Read"],"mcp_servers":[{"name":"usebits-prod","status":"connected"}],"model":"claude-opus-4-6","permissionMode":"default","uuid":"f842"}"#,
            #"{"type":"stream_event","event":{"type":"message_start","message":{"model":"claude-opus-4-6","id":"msg_01","type":"message","role":"assistant","content":[],"stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":3,"cache_creation_input_tokens":8116,"cache_read_input_tokens":0}}},"session_id":"sess-real","parent_tool_use_id":null,"uuid":"0faf"}"#,
            #"{"type":"stream_event","event":{"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}},"session_id":"sess-real","parent_tool_use_id":null,"uuid":"8b7d"}"#,
            #"{"type":"stream_event","event":{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"4"}},"session_id":"sess-real","parent_tool_use_id":null,"uuid":"0633"}"#,
            #"{"type":"assistant","message":{"model":"claude-opus-4-6","id":"msg_01","type":"message","role":"assistant","content":[{"type":"text","text":"4"}],"stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":3},"context_management":null},"parent_tool_use_id":null,"session_id":"sess-real","uuid":"01a7"}"#,
            #"{"type":"stream_event","event":{"type":"content_block_stop","index":0},"session_id":"sess-real","parent_tool_use_id":null,"uuid":"c908"}"#,
            #"{"type":"stream_event","event":{"type":"message_delta","delta":{"stop_reason":"end_turn","stop_sequence":null},"usage":{"input_tokens":3,"output_tokens":5},"context_management":{"applied_edits":[]}},"session_id":"sess-real","parent_tool_use_id":null,"uuid":"1776"}"#,
            #"{"type":"stream_event","event":{"type":"message_stop"},"session_id":"sess-real","parent_tool_use_id":null,"uuid":"0601"}"#,
            #"{"type":"rate_limit_event","rate_limit_info":{"status":"allowed","resetsAt":1772740800},"uuid":"58ab","session_id":"sess-real"}"#,
            #"{"type":"result","subtype":"success","is_error":false,"duration_ms":2142,"num_turns":1,"result":"4","stop_reason":"end_turn","session_id":"sess-real","total_cost_usd":0.05,"uuid":"7a7a"}"#,
        ]

        var text = ""
        var sid: String?
        for line in lines {
            let parsed = ClaudeProcess.parseStreamLine(line)
            if let s = parsed.sessionId, sid == nil { sid = s }
            for event in parsed.events {
                if case .textDelta(let t) = event { text += t }
            }
        }
        #expect(text == "4")
        #expect(sid == "sess-real")
    }

    // MARK: - parseStreamChunks (line buffering)

    @Test func chunksAlignedToLinesBehavesIdentically() {
        // When chunks are complete lines, output matches per-line parsing
        let chunks = [
            #"{"type":"system","subtype":"init","session_id":"sess-1"}"# + "\n",
            #"{"type":"stream_event","event":{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"hello"}},"session_id":"sess-1"}"# + "\n",
            #"{"type":"result","subtype":"success","session_id":"sess-1"}"# + "\n",
        ]

        let result = ClaudeProcess.parseStreamChunks(chunks)
        #expect(result.events == [.textDelta("hello")])
        #expect(result.sessionId == "sess-1")
    }

    @Test func chunksSplitMidLineReassembles() {
        // A JSON line is split across two chunks — buffering must reassemble it
        let fullLine = #"{"type":"stream_event","event":{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"hello"}},"session_id":"sess-1"}"#

        let splitPoint = fullLine.index(fullLine.startIndex, offsetBy: 40)
        let firstHalf = String(fullLine[..<splitPoint])
        let secondHalf = String(fullLine[splitPoint...])

        let chunks = [
            firstHalf,           // no newline — partial line
            secondHalf + "\n",   // rest of line + newline
        ]

        let result = ClaudeProcess.parseStreamChunks(chunks)
        #expect(result.events == [.textDelta("hello")])
        #expect(result.sessionId == "sess-1")
    }

    @Test func chunksMultipleLinesSplitAcrossBoundary() {
        // Two complete lines arrive in a single chunk, then a third is split
        let line1 = #"{"type":"system","subtype":"init","session_id":"sess-1"}"#
        let line2 = #"{"type":"stream_event","event":{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"ab"}},"session_id":"sess-1"}"#
        let line3 = #"{"type":"stream_event","event":{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"cd"}},"session_id":"sess-1"}"#

        let splitPoint = line3.index(line3.startIndex, offsetBy: 20)

        let chunks = [
            line1 + "\n" + line2 + "\n" + String(line3[..<splitPoint]),
            String(line3[splitPoint...]) + "\n",
        ]

        let result = ClaudeProcess.parseStreamChunks(chunks)
        #expect(result.events == [.textDelta("ab"), .textDelta("cd")])
        #expect(result.sessionId == "sess-1")
    }

    @Test func chunksFinalLineWithoutTrailingNewline() {
        // Last line has no trailing newline (common for pipe EOF)
        let chunks = [
            #"{"type":"stream_event","event":{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"final"}},"session_id":"sess-1"}"#,
        ]

        let result = ClaudeProcess.parseStreamChunks(chunks)
        #expect(result.events == [.textDelta("final")])
        #expect(result.sessionId == "sess-1")
    }

    @Test func chunksNonJsonLinesSkipped() {
        // Non-JSON lines (like "TLS certificate verification disabled...") are silently skipped
        let chunks = [
            "TLS certificate verification disabled in production DB connection\n",
            #"{"type":"system","subtype":"init","session_id":"sess-1"}"# + "\n",
            "WARNING: something else\n",
            #"{"type":"stream_event","event":{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"works"}},"session_id":"sess-1"}"# + "\n",
        ]

        let result = ClaudeProcess.parseStreamChunks(chunks)
        #expect(result.events == [.textDelta("works")])
        #expect(result.sessionId == "sess-1")
    }

    @Test func chunksNonJsonLineSplitAcrossChunks() {
        // A non-JSON warning is split across chunks, followed by valid JSON
        let chunks = [
            "TLS certificate verific",
            "ation disabled\n" + #"{"type":"stream_event","event":{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"ok"}},"session_id":"sess-1"}"# + "\n",
        ]

        let result = ClaudeProcess.parseStreamChunks(chunks)
        #expect(result.events == [.textDelta("ok")])
        #expect(result.sessionId == "sess-1")
    }

    @Test func chunksLargeHookResponseSplitAcrossReads() {
        // Simulates a large hook_response line (several KB) split across multiple reads,
        // followed by the actual text delta. This matches real CLI behavior where --verbose
        // produces ~14KB of output with hook responses containing full beads context.
        let hookLine = ##"{"type":"system","subtype":"hook_response","hook_id":"abc","output":"# Beads Workflow Context\n"## + String(repeating: "x", count: 4000) + ##"","session_id":"sess-1"}"##

        let textLine = #"{"type":"stream_event","event":{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"response"}},"session_id":"sess-1"}"#

        // Split the hook line into 3 chunks (simulating multiple pipe reads)
        let third = hookLine.count / 3
        let idx1 = hookLine.index(hookLine.startIndex, offsetBy: third)
        let idx2 = hookLine.index(hookLine.startIndex, offsetBy: third * 2)

        let chunks = [
            String(hookLine[..<idx1]),
            String(hookLine[idx1..<idx2]),
            String(hookLine[idx2...]) + "\n" + textLine + "\n",
        ]

        let result = ClaudeProcess.parseStreamChunks(chunks)
        #expect(result.events == [.textDelta("response")])
        #expect(result.sessionId == "sess-1")
    }

    @Test func chunksEmptyChunksIgnored() {
        let chunks = [
            "",
            #"{"type":"stream_event","event":{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"hi"}},"session_id":"sess-1"}"# + "\n",
            "",
            "",
        ]

        let result = ClaudeProcess.parseStreamChunks(chunks)
        #expect(result.events == [.textDelta("hi")])
    }
}
