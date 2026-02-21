import Foundation
import Testing
@testable import BeadsLib

@Suite("ChatState")
struct ChatStateTests {

    private static func mockProvider(
        events: [ClaudeStreamEvent]
    ) -> @Sendable (String, String?, String) -> AsyncThrowingStream<ClaudeStreamEvent, Error> {
        return { @Sendable _, _, _ in
            AsyncThrowingStream { continuation in
                for event in events {
                    continuation.yield(event)
                }
                continuation.finish()
            }
        }
    }

    private static func failingProvider(
        error: Error
    ) -> @Sendable (String, String?, String) -> AsyncThrowingStream<ClaudeStreamEvent, Error> {
        return { @Sendable _, _, _ in
            AsyncThrowingStream { continuation in
                continuation.finish(throwing: error)
            }
        }
    }

    @MainActor
    @Test func sendMessageAppendsUserAndAssistant() async {
        let state = ChatState(projectPath: "/tmp")
        state.streamProvider = Self.mockProvider(events: [
            .textDelta("hi"),
            .completed,
        ])
        state.sendMessage("hello")

        while state.isStreaming {
            await Task.yield()
        }

        #expect(state.messages.count == 2)
        #expect(state.messages[0].role == .user)
        #expect(state.messages[0].text == "hello")
        #expect(state.messages[1].role == .assistant)
        #expect(state.messages[1].text == "hi")
    }

    @MainActor
    @Test func emptyMessageRejected() {
        let state = ChatState(projectPath: "/tmp")
        state.sendMessage("")
        #expect(state.messages.isEmpty)
        #expect(!state.isStreaming)
    }

    @MainActor
    @Test func whitespaceOnlyMessageRejected() {
        let state = ChatState(projectPath: "/tmp")
        state.sendMessage("   \n  ")
        #expect(state.messages.isEmpty)
        #expect(!state.isStreaming)
    }

    @MainActor
    @Test func cannotSendWhileStreaming() async {
        let state = ChatState(projectPath: "/tmp")
        state.streamProvider = { @Sendable _, _, _ in
            AsyncThrowingStream { _ in }
        }
        state.sendMessage("first")
        #expect(state.isStreaming)

        state.sendMessage("second")
        #expect(state.messages.count == 2)

        state.cancel()
    }

    @MainActor
    @Test func textDeltasAccumulate() async {
        let state = ChatState(projectPath: "/tmp")
        state.streamProvider = Self.mockProvider(events: [
            .textDelta("a"),
            .textDelta("b"),
            .textDelta("c"),
            .completed,
        ])
        state.sendMessage("go")

        while state.isStreaming {
            await Task.yield()
        }

        #expect(state.messages[1].text == "abc")
    }

    @MainActor
    @Test func sessionIdCapturedFromStream() async {
        let state = ChatState(projectPath: "/tmp")
        state.streamProvider = Self.mockProvider(events: [
            .sessionId("sess-test"),
            .textDelta("ok"),
            .completed,
        ])
        state.sendMessage("go")

        while state.isStreaming {
            await Task.yield()
        }

        #expect(state.sessionId == "sess-test")
    }

    @MainActor
    @Test func errorRemovesEmptyAssistantMessage() async {
        struct TestError: Error, LocalizedError {
            var errorDescription: String? { "boom" }
        }

        let state = ChatState(projectPath: "/tmp")
        state.streamProvider = Self.failingProvider(error: TestError())
        state.sendMessage("go")

        while state.isStreaming {
            await Task.yield()
        }

        #expect(state.messages.count == 1)
        #expect(state.messages[0].role == .user)
        #expect(state.errorMessage == "boom")
    }

    @MainActor
    @Test func errorKeepsAssistantMessageWithText() async {
        struct TestError: Error {}

        let state = ChatState(projectPath: "/tmp")
        state.streamProvider = { @Sendable _, _, _ in
            AsyncThrowingStream { continuation in
                continuation.yield(.textDelta("partial"))
                continuation.finish(throwing: TestError())
            }
        }
        state.sendMessage("go")

        while state.isStreaming {
            await Task.yield()
        }

        #expect(state.messages.count == 2)
        #expect(state.messages[1].text == "partial")
    }

    @MainActor
    @Test func cancelSetsStreamingFalse() {
        let state = ChatState(projectPath: "/tmp")
        state.streamProvider = { @Sendable _, _, _ in
            AsyncThrowingStream { _ in }
        }
        state.sendMessage("go")
        #expect(state.isStreaming)

        state.cancel()
        #expect(!state.isStreaming)
    }

    // MARK: - Follow-up & cancel-resend

    @MainActor
    @Test func followUpMessageReusesSessionId() async {
        let state = ChatState(projectPath: "/tmp")
        state.streamProvider = Self.mockProvider(events: [
            .sessionId("sess-1"),
            .textDelta("first reply"),
            .completed,
        ])
        state.sendMessage("hello")
        while state.isStreaming { await Task.yield() }

        #expect(state.sessionId == "sess-1")
        #expect(state.messages.count == 2)

        // Send follow-up — provider captures sessionId passed through
        nonisolated(unsafe) var capturedSessionId: String?
        state.streamProvider = { @Sendable _, sid, _ in
            capturedSessionId = sid
            return AsyncThrowingStream { continuation in
                continuation.yield(.textDelta("second reply"))
                continuation.finish()
            }
        }
        state.sendMessage("follow up")
        while state.isStreaming { await Task.yield() }

        #expect(state.messages.count == 4)
        #expect(state.messages[2].role == .user)
        #expect(state.messages[3].role == .assistant)
        #expect(state.messages[3].text == "second reply")
        #expect(capturedSessionId == "sess-1")
    }

    @MainActor
    @Test func cancelThenResend() async {
        let state = ChatState(projectPath: "/tmp")
        state.streamProvider = { @Sendable _, _, _ in
            AsyncThrowingStream { _ in }
        }
        state.sendMessage("first")
        #expect(state.isStreaming)

        state.cancel()
        #expect(!state.isStreaming)

        state.streamProvider = Self.mockProvider(events: [
            .textDelta("response"),
            .completed,
        ])
        state.sendMessage("second")
        while state.isStreaming { await Task.yield() }

        #expect(state.messages.count == 4)
        #expect(state.messages[2].text == "second")
        #expect(state.messages[3].text == "response")
        #expect(!state.isStreaming)
    }

    @MainActor
    @Test func streamWithoutCompletedEvent() async {
        let state = ChatState(projectPath: "/tmp")
        state.streamProvider = { @Sendable _, _, _ in
            AsyncThrowingStream { continuation in
                continuation.yield(.textDelta("text"))
                continuation.finish()
            }
        }
        state.sendMessage("go")
        while state.isStreaming { await Task.yield() }

        #expect(!state.isStreaming)
        #expect(state.messages.count == 2)
        #expect(state.messages[1].text == "text")
    }

    // MARK: - Tool call handling

    @MainActor
    @Test func toolUseAppendsToAssistantMessage() async {
        let state = ChatState(projectPath: "/tmp")
        state.streamProvider = Self.mockProvider(events: [
            .textDelta("let me check"),
            .toolUse(id: "tool-1", name: "Read", input: "{\"path\":\"/tmp/file\"}"),
            .completed,
        ])
        state.sendMessage("go")
        while state.isStreaming { await Task.yield() }

        #expect(state.messages[1].toolCalls.count == 1)
        #expect(state.messages[1].toolCalls[0].name == "Read")
        #expect(state.messages[1].toolCalls[0].id == "tool-1")
    }

    @MainActor
    @Test func toolResultMatchesToToolCall() async {
        let state = ChatState(projectPath: "/tmp")
        state.streamProvider = Self.mockProvider(events: [
            .toolUse(id: "tool-1", name: "Bash", input: "{\"cmd\":\"ls\"}"),
            .toolResult(toolUseId: "tool-1", content: "file.txt"),
            .textDelta("done"),
            .completed,
        ])
        state.sendMessage("go")
        while state.isStreaming { await Task.yield() }

        #expect(state.messages[1].toolCalls[0].result == "file.txt")
    }

    @MainActor
    @Test func toolResultForUnknownIdIgnored() async {
        let state = ChatState(projectPath: "/tmp")
        state.streamProvider = Self.mockProvider(events: [
            .toolUse(id: "tool-1", name: "Read", input: "{}"),
            .toolResult(toolUseId: "unknown-id", content: "data"),
            .completed,
        ])
        state.sendMessage("go")
        while state.isStreaming { await Task.yield() }

        #expect(state.messages[1].toolCalls.count == 1)
        #expect(state.messages[1].toolCalls[0].result == nil)
    }

    @MainActor
    @Test func errorKeepsAssistantMessageWithToolCalls() async {
        struct TestError: Error {}

        let state = ChatState(projectPath: "/tmp")
        state.streamProvider = { @Sendable _, _, _ in
            AsyncThrowingStream { continuation in
                continuation.yield(.toolUse(id: "t1", name: "Read", input: "{}"))
                continuation.finish(throwing: TestError())
            }
        }
        state.sendMessage("go")
        while state.isStreaming { await Task.yield() }

        #expect(state.messages.count == 2)
        #expect(state.messages[1].toolCalls.count == 1)
    }

    @MainActor
    @Test func multipleToolCallsMatchedCorrectly() async {
        let state = ChatState(projectPath: "/tmp")
        state.streamProvider = Self.mockProvider(events: [
            .toolUse(id: "t1", name: "Read", input: "{}"),
            .toolUse(id: "t2", name: "Bash", input: "{\"cmd\":\"ls\"}"),
            .toolResult(toolUseId: "t2", content: "file.txt"),
            .toolResult(toolUseId: "t1", content: "contents"),
            .textDelta("done"),
            .completed,
        ])
        state.sendMessage("go")
        while state.isStreaming { await Task.yield() }

        #expect(state.messages[1].toolCalls.count == 2)
        #expect(state.messages[1].toolCalls[0].result == "contents")
        #expect(state.messages[1].toolCalls[1].result == "file.txt")
    }

    // MARK: - Issue context

    private static func capturingProvider(
        events: [ClaudeStreamEvent] = [.textDelta("ok"), .completed]
    ) -> (@Sendable (String, String?, String) -> AsyncThrowingStream<ClaudeStreamEvent, Error>, @Sendable () -> String?) {
        nonisolated(unsafe) var capturedPrompt: String?
        let provider: @Sendable (String, String?, String) -> AsyncThrowingStream<ClaudeStreamEvent, Error> = { prompt, _, _ in
            capturedPrompt = prompt
            return AsyncThrowingStream { continuation in
                for event in events {
                    continuation.yield(event)
                }
                continuation.finish()
            }
        }
        return (provider, { capturedPrompt })
    }

    @MainActor
    @Test func issueContextPrependedToFirstMessage() async {
        let state = ChatState(projectPath: "/tmp")
        state.issueContext = "Issue PROJ-42: Fix login timeout\nDescription: Users get timeout errors"
        let (provider, getPrompt) = Self.capturingProvider()
        state.streamProvider = provider

        state.sendMessage("what's wrong?")
        while state.isStreaming { await Task.yield() }

        let prompt = getPrompt()
        #expect(prompt != nil)
        #expect(prompt!.hasPrefix("Issue PROJ-42: Fix login timeout"))
        #expect(prompt!.hasSuffix("what's wrong?"))
        #expect(prompt!.contains("Users get timeout errors"))
    }

    @MainActor
    @Test func issueContextNotPrependedOnFollowUp() async {
        let state = ChatState(projectPath: "/tmp")
        state.issueContext = "Issue PROJ-42: Fix login timeout"
        state.streamProvider = Self.mockProvider(events: [
            .sessionId("sess-1"),
            .textDelta("first"),
            .completed,
        ])
        state.sendMessage("hello")
        while state.isStreaming { await Task.yield() }

        #expect(state.sessionId == "sess-1")

        let (provider, getPrompt) = Self.capturingProvider()
        state.streamProvider = provider
        state.sendMessage("follow up")
        while state.isStreaming { await Task.yield() }

        let prompt = getPrompt()
        #expect(prompt == "follow up")
    }

    @MainActor
    @Test func issueContextNotPrependedWhenNil() async {
        let state = ChatState(projectPath: "/tmp")
        #expect(state.issueContext == nil)

        let (provider, getPrompt) = Self.capturingProvider()
        state.streamProvider = provider
        state.sendMessage("hello")
        while state.isStreaming { await Task.yield() }

        #expect(getPrompt() == "hello")
    }

    @MainActor
    @Test func clearResetsSessionAndMessages() async {
        let state = ChatState(projectPath: "/tmp")
        state.issueContext = "Issue PROJ-1: Test"
        state.streamProvider = Self.mockProvider(events: [
            .sessionId("sess-1"),
            .textDelta("reply"),
            .completed,
        ])
        state.sendMessage("go")
        while state.isStreaming { await Task.yield() }

        #expect(state.sessionId == "sess-1")
        #expect(state.messages.count == 2)

        state.clear()

        #expect(state.messages.isEmpty)
        #expect(state.sessionId == nil)
        #expect(!state.isStreaming)
        #expect(state.errorMessage == nil)
    }

    @MainActor
    @Test func clearThenSendPrependsContextAgain() async {
        let state = ChatState(projectPath: "/tmp")
        state.issueContext = "Issue PROJ-42: Fix it"
        state.streamProvider = Self.mockProvider(events: [
            .sessionId("sess-1"),
            .textDelta("first"),
            .completed,
        ])
        state.sendMessage("hello")
        while state.isStreaming { await Task.yield() }

        state.clear()

        let (provider, getPrompt) = Self.capturingProvider()
        state.streamProvider = provider
        state.sendMessage("start over")
        while state.isStreaming { await Task.yield() }

        let prompt = getPrompt()
        #expect(prompt!.hasPrefix("Issue PROJ-42: Fix it"))
        #expect(prompt!.hasSuffix("start over"))
    }

    // MARK: - Streaming guard

    @MainActor
    @Test func sendWhileStreamingDropsMessageAndPreservesInput() async {
        let state = ChatState(projectPath: "/tmp")
        state.streamProvider = { @Sendable _, _, _ in
            AsyncThrowingStream { _ in }
        }
        state.sendMessage("first")
        #expect(state.isStreaming)
        #expect(state.messages.count == 2)

        // Attempt to send while streaming — should be silently rejected
        state.sendMessage("second")
        #expect(state.messages.count == 2)
        #expect(state.messages[0].text == "first")

        state.cancel()
    }

    @MainActor
    @Test func sendAfterStreamCompletes() async {
        let state = ChatState(projectPath: "/tmp")
        state.streamProvider = Self.mockProvider(events: [
            .textDelta("reply1"),
            .completed,
        ])
        state.sendMessage("first")
        while state.isStreaming { await Task.yield() }

        #expect(!state.isStreaming)
        #expect(state.messages.count == 2)

        state.streamProvider = Self.mockProvider(events: [
            .textDelta("reply2"),
            .completed,
        ])
        state.sendMessage("second")
        while state.isStreaming { await Task.yield() }

        #expect(state.messages.count == 4)
        #expect(state.messages[2].text == "second")
        #expect(state.messages[3].text == "reply2")
    }

    @MainActor
    @Test func cancelDuringStreamThenSendSucceeds() async {
        let state = ChatState(projectPath: "/tmp")
        state.streamProvider = { @Sendable _, _, _ in
            AsyncThrowingStream { _ in }
        }
        state.sendMessage("first")
        #expect(state.isStreaming)

        state.cancel()
        #expect(!state.isStreaming)

        // Should be able to send again immediately
        let (provider, getPrompt) = Self.capturingProvider()
        state.streamProvider = provider
        state.sendMessage("retry")
        while state.isStreaming { await Task.yield() }

        #expect(getPrompt() == "retry")
        #expect(state.messages.last?.text == "ok")
    }

    @MainActor
    @Test func clearWhileStreamingStopsAndResets() async {
        let state = ChatState(projectPath: "/tmp")
        state.streamProvider = { @Sendable _, _, _ in
            AsyncThrowingStream { _ in }
        }
        state.sendMessage("go")
        #expect(state.isStreaming)

        state.clear()
        #expect(!state.isStreaming)
        #expect(state.messages.isEmpty)
        #expect(state.sessionId == nil)
    }

    // MARK: - Issue context formatting

    @MainActor
    @Test func issueContextIncludesAllFields() async {
        let state = ChatState(projectPath: "/tmp")
        state.issueContext = "Issue PROJ-1: Title\nDescription: desc\nDesign: design\nAcceptance Criteria: ac\nNotes: notes"

        let (provider, getPrompt) = Self.capturingProvider()
        state.streamProvider = provider
        state.sendMessage("go")
        while state.isStreaming { await Task.yield() }

        let prompt = getPrompt()!
        #expect(prompt.contains("Description: desc"))
        #expect(prompt.contains("Design: design"))
        #expect(prompt.contains("Acceptance Criteria: ac"))
        #expect(prompt.contains("Notes: notes"))
        #expect(prompt.hasSuffix("go"))
    }

    @MainActor
    @Test func multipleSessionsPreserveIndependentState() async {
        let state1 = ChatState(projectPath: "/tmp")
        let state2 = ChatState(projectPath: "/tmp")

        state1.issueContext = "Issue A"
        state2.issueContext = "Issue B"

        let (provider1, getPrompt1) = Self.capturingProvider()
        state1.streamProvider = provider1
        state1.sendMessage("hello")
        while state1.isStreaming { await Task.yield() }

        let (provider2, getPrompt2) = Self.capturingProvider()
        state2.streamProvider = provider2
        state2.sendMessage("world")
        while state2.isStreaming { await Task.yield() }

        #expect(getPrompt1()!.hasPrefix("Issue A"))
        #expect(getPrompt2()!.hasPrefix("Issue B"))
    }

    // MARK: - Tool call deduplication

    @MainActor
    @Test func duplicateToolUseIdsAreIgnored() async {
        let state = ChatState(projectPath: "/tmp")
        state.streamProvider = Self.mockProvider(events: [
            .toolUse(id: "t1", name: "Bash", input: "{\"cmd\":\"ls\"}"),
            .toolUse(id: "t1", name: "Bash", input: "{\"cmd\":\"ls\"}"),
            .toolUse(id: "t1", name: "Bash", input: "{\"cmd\":\"ls\"}"),
            .textDelta("done"),
            .completed,
        ])
        state.sendMessage("ls")
        while state.isStreaming { await Task.yield() }

        #expect(state.messages[1].toolCalls.count == 1)
        #expect(state.messages[1].toolCalls[0].id == "t1")
    }

    @MainActor
    @Test func duplicateToolResultsAreIgnored() async {
        let state = ChatState(projectPath: "/tmp")
        state.streamProvider = Self.mockProvider(events: [
            .toolUse(id: "t1", name: "Bash", input: "{}"),
            .toolResult(toolUseId: "t1", content: "first result"),
            .toolResult(toolUseId: "t1", content: "duplicate result"),
            .completed,
        ])
        state.sendMessage("go")
        while state.isStreaming { await Task.yield() }

        #expect(state.messages[1].toolCalls[0].result == "first result")
    }

    @MainActor
    @Test func multipleDistinctToolCallsWithDuplicates() async {
        // Simulates partial messages repeating tool_use blocks
        let state = ChatState(projectPath: "/tmp")
        state.streamProvider = Self.mockProvider(events: [
            .toolUse(id: "t1", name: "Read", input: "{}"),
            .toolUse(id: "t1", name: "Read", input: "{}"),
            .toolResult(toolUseId: "t1", content: "file contents"),
            .toolUse(id: "t2", name: "Bash", input: "{\"cmd\":\"ls\"}"),
            .toolUse(id: "t1", name: "Read", input: "{}"),
            .toolUse(id: "t2", name: "Bash", input: "{\"cmd\":\"ls\"}"),
            .toolResult(toolUseId: "t2", content: "file.txt"),
            .textDelta("done"),
            .completed,
        ])
        state.sendMessage("do two things")
        while state.isStreaming { await Task.yield() }

        #expect(state.messages[1].toolCalls.count == 2)
        #expect(state.messages[1].toolCalls[0].id == "t1")
        #expect(state.messages[1].toolCalls[0].result == "file contents")
        #expect(state.messages[1].toolCalls[1].id == "t2")
        #expect(state.messages[1].toolCalls[1].result == "file.txt")
        #expect(state.messages[1].text == "done")
    }
}
