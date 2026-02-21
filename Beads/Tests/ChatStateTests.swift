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
}
