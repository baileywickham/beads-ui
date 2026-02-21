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
}
