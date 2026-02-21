import Foundation
import Testing
@testable import BeadsLib

@Suite("ClaudeProcess NDJSON Parsing")
struct ClaudeProcessParsingTests {

    // MARK: - parseStreamLine

    @Test func contentBlockDeltaYieldsTextDelta() {
        let json = """
        {"type":"content_block_delta","delta":{"text":"hello"}}
        """
        let result = ClaudeProcess.parseStreamLine(json)
        #expect(result.events.count == 1)
        guard case .textDelta(let text) = result.events.first else {
            Issue.record("Expected textDelta, got \(result.events)")
            return
        }
        #expect(text == "hello")
        #expect(result.sessionId == nil)
    }

    @Test func assistantMessageYieldsTextDeltas() {
        let json = """
        {"type":"assistant","message":{"content":[{"text":"first"},{"text":"second"}]}}
        """
        let result = ClaudeProcess.parseStreamLine(json)
        #expect(result.events.count == 2)
        guard case .textDelta(let t1) = result.events[0],
              case .textDelta(let t2) = result.events[1] else {
            Issue.record("Expected two textDeltas")
            return
        }
        #expect(t1 == "first")
        #expect(t2 == "second")
    }

    @Test func sessionIdCapturedFromTopLevel() {
        let json = """
        {"type":"init","session_id":"sess-abc123"}
        """
        let result = ClaudeProcess.parseStreamLine(json)
        #expect(result.sessionId == "sess-abc123")
    }

    @Test func resultEventCapturesSessionId() {
        let json = """
        {"type":"result","session_id":"sess-xyz","result":"done"}
        """
        let result = ClaudeProcess.parseStreamLine(json)
        #expect(result.sessionId == "sess-xyz")
        #expect(result.events.isEmpty)
    }

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

    @Test func assistantWithSessionId() {
        let json = """
        {"type":"assistant","session_id":"sess-multi","message":{"content":[{"text":"chunk"}]}}
        """
        let result = ClaudeProcess.parseStreamLine(json)
        #expect(result.sessionId == "sess-multi")
        #expect(result.events.count == 1)
        guard case .textDelta(let text) = result.events.first else {
            Issue.record("Expected textDelta")
            return
        }
        #expect(text == "chunk")
    }

    @Test func contentBlockDeltaWithMissingTextField() {
        let json = """
        {"type":"content_block_delta","delta":{"type":"text_delta"}}
        """
        let result = ClaudeProcess.parseStreamLine(json)
        #expect(result.events.isEmpty)
    }

    @Test func unknownTypeYieldsNoEvents() {
        let json = """
        {"type":"ping"}
        """
        let result = ClaudeProcess.parseStreamLine(json)
        #expect(result.events.isEmpty)
        #expect(result.sessionId == nil)
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
        #expect(result != nil)
        #expect(result?.text == "just text")
        #expect(result?.sessionId == nil)
    }

    @Test func parseJsonResponseWithEmptyResult() {
        let json = """
        {"session_id":"sess-empty"}
        """
        let data = json.data(using: .utf8)!
        let result = ClaudeProcess.parseJsonResponse(data)
        #expect(result != nil)
        #expect(result?.text == "")
        #expect(result?.sessionId == "sess-empty")
    }

    @Test func parseJsonResponseInvalidData() {
        let data = "not json".data(using: .utf8)!
        let result = ClaudeProcess.parseJsonResponse(data)
        #expect(result == nil)
    }

    // MARK: - Tool use parsing

    @Test func toolUseInAssistantContent() {
        let json = """
        {"type":"assistant","message":{"content":[{"type":"tool_use","id":"tu-1","name":"Read","input":{"path":"/tmp"}}]}}
        """
        let result = ClaudeProcess.parseStreamLine(json)
        #expect(result.events.count == 1)
        guard case .toolUse(let id, let name, let input) = result.events.first else {
            Issue.record("Expected toolUse, got \(result.events)")
            return
        }
        #expect(id == "tu-1")
        #expect(name == "Read")
        #expect(input.contains("/tmp"))
    }

    @Test func toolResultInUserContent() {
        let json = """
        {"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"tu-1","content":[{"text":"file contents"}]}]}}
        """
        let result = ClaudeProcess.parseStreamLine(json)
        #expect(result.events.count == 1)
        guard case .toolResult(let toolUseId, let content) = result.events.first else {
            Issue.record("Expected toolResult, got \(result.events)")
            return
        }
        #expect(toolUseId == "tu-1")
        #expect(content == "file contents")
    }

    @Test func mixedTextAndToolUse() {
        let json = """
        {"type":"assistant","message":{"content":[{"text":"checking..."},{"type":"tool_use","id":"tu-2","name":"Bash","input":{"command":"ls"}}]}}
        """
        let result = ClaudeProcess.parseStreamLine(json)
        #expect(result.events.count == 2)
        guard case .textDelta(let text) = result.events[0] else {
            Issue.record("Expected textDelta first")
            return
        }
        #expect(text == "checking...")
        guard case .toolUse(_, let name, _) = result.events[1] else {
            Issue.record("Expected toolUse second")
            return
        }
        #expect(name == "Bash")
    }

    @Test func toolUseInputSerialization() {
        let json = """
        {"type":"assistant","message":{"content":[{"type":"tool_use","id":"tu-3","name":"Edit","input":{"file":"a.txt","line":42}}]}}
        """
        let result = ClaudeProcess.parseStreamLine(json)
        guard case .toolUse(_, _, let input) = result.events.first else {
            Issue.record("Expected toolUse")
            return
        }
        // Verify input is valid JSON
        let data = input.data(using: .utf8)!
        let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(parsed != nil)
        #expect(parsed?["file"] as? String == "a.txt")
        #expect(parsed?["line"] as? Int == 42)
    }

    @Test func toolResultWithStringContent() {
        let json = """
        {"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"tu-4","content":"plain text result"}]}}
        """
        let result = ClaudeProcess.parseStreamLine(json)
        #expect(result.events.count == 1)
        guard case .toolResult(_, let content) = result.events.first else {
            Issue.record("Expected toolResult")
            return
        }
        #expect(content == "plain text result")
    }
}
