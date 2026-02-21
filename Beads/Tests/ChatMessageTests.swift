import Foundation
import Testing
@testable import BeadsLib

@Suite("ChatMessage")
struct ChatMessageTests {
    @Test func initWithDefaults() {
        let msg = ChatMessage(role: .user, text: "hello")
        #expect(msg.role == .user)
        #expect(msg.text == "hello")
        #expect(!msg.id.uuidString.isEmpty)
    }

    @Test func uniqueIds() {
        let a = ChatMessage(role: .user, text: "a")
        let b = ChatMessage(role: .user, text: "b")
        #expect(a.id != b.id)
    }

    @Test func assistantRole() {
        let msg = ChatMessage(role: .assistant, text: "response")
        #expect(msg.role == .assistant)
        #expect(msg.text == "response")
    }

    @Test func appendTextCreatesBlock() {
        var msg = ChatMessage(role: .assistant)
        msg.appendText("streamed")
        #expect(msg.text == "streamed")
        #expect(msg.blocks.count == 1)
    }

    @Test func appendTextAccumulatesInSameBlock() {
        var msg = ChatMessage(role: .assistant)
        msg.appendText("a")
        msg.appendText("b")
        msg.appendText("c")
        #expect(msg.text == "abc")
        #expect(msg.blocks.count == 1)
    }

    // MARK: - Tool calls

    @Test func toolCallsDefaultEmpty() {
        let msg = ChatMessage(role: .assistant, text: "hi")
        #expect(msg.toolCalls.isEmpty)
    }

    @Test func addToolCallAppendsBlock() {
        var msg = ChatMessage(role: .assistant)
        msg.addToolCall(id: "t1", name: "Read", input: "{}")
        #expect(msg.toolCalls.count == 1)
        #expect(msg.toolCalls[0].name == "Read")
        #expect(msg.toolCalls[0].result == nil)
    }

    @Test func setToolResultUpdatesBlock() {
        var msg = ChatMessage(role: .assistant)
        msg.addToolCall(id: "t1", name: "Read", input: "{}")
        msg.setToolResult(toolUseId: "t1", content: "file contents")
        #expect(msg.toolCalls[0].result == "file contents")
    }

    @Test func addToolCallDeduplicatesById() {
        var msg = ChatMessage(role: .assistant)
        msg.addToolCall(id: "t1", name: "Read", input: "{}")
        msg.addToolCall(id: "t1", name: "Read", input: "{}")
        #expect(msg.toolCalls.count == 1)
    }

    @Test func setToolResultIgnoresDuplicates() {
        var msg = ChatMessage(role: .assistant)
        msg.addToolCall(id: "t1", name: "Bash", input: "{}")
        msg.setToolResult(toolUseId: "t1", content: "first")
        msg.setToolResult(toolUseId: "t1", content: "second")
        #expect(msg.toolCalls[0].result == "first")
    }

    // MARK: - Block ordering

    @Test func blocksPreserveInsertionOrder() {
        var msg = ChatMessage(role: .assistant)
        msg.appendText("checking...")
        msg.addToolCall(id: "t1", name: "Read", input: "{}")
        msg.setToolResult(toolUseId: "t1", content: "data")
        msg.appendText("done")

        #expect(msg.blocks.count == 3)
        if case .text(let t) = msg.blocks[0].content { #expect(t == "checking...") }
        if case .toolCall(let name, _, _) = msg.blocks[1].content { #expect(name == "Read") }
        if case .text(let t) = msg.blocks[2].content { #expect(t == "done") }
    }

    @Test func textAfterToolCallCreatesNewBlock() {
        var msg = ChatMessage(role: .assistant)
        msg.appendText("a")
        msg.addToolCall(id: "t1", name: "Bash", input: "{}")
        msg.appendText("b")
        #expect(msg.blocks.count == 3)
        #expect(msg.text == "ab")
    }

    @Test func consecutiveTextDeltasMerge() {
        var msg = ChatMessage(role: .assistant)
        msg.appendText("a")
        msg.appendText("b")
        msg.addToolCall(id: "t1", name: "Bash", input: "{}")
        msg.appendText("c")
        msg.appendText("d")
        #expect(msg.blocks.count == 3)
        if case .text(let t) = msg.blocks[0].content { #expect(t == "ab") }
        if case .text(let t) = msg.blocks[2].content { #expect(t == "cd") }
    }
}
