import Foundation

@MainActor @Observable
final class ChatState {
    let projectPath: String

    var messages: [ChatMessage] = []
    var isStreaming: Bool = false
    var errorMessage: String?
    var sessionId: String?

    private var streamTask: Task<Void, Never>?

    var streamProvider: @Sendable (String, String?, String) -> AsyncThrowingStream<ClaudeStreamEvent, Error> = ClaudeProcess.send

    init(projectPath: String) {
        self.projectPath = projectPath
    }

    func sendMessage(_ text: String) {
        guard !isStreaming else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        errorMessage = nil
        messages.append(ChatMessage(role: .user, text: trimmed))

        let assistantIndex = messages.count
        messages.append(ChatMessage(role: .assistant, text: ""))
        isStreaming = true

        let currentSessionId = sessionId
        let projectPath = self.projectPath
        let provider = streamProvider

        streamTask = Task {
            do {
                let stream = provider(
                    trimmed,
                    currentSessionId,
                    projectPath
                )
                for try await event in stream {
                    switch event {
                    case .textDelta(let delta):
                        if assistantIndex < messages.count {
                            messages[assistantIndex].text += delta
                        }
                    case .sessionId(let sid):
                        sessionId = sid
                    case .toolUse(let id, let name, let input):
                        if assistantIndex < messages.count {
                            messages[assistantIndex].toolCalls.append(
                                ChatMessage.ToolCall(id: id, name: name, input: input)
                            )
                        }
                    case .toolResult(let toolUseId, let content):
                        if assistantIndex < messages.count,
                           let idx = messages[assistantIndex].toolCalls.firstIndex(where: { $0.id == toolUseId }) {
                            messages[assistantIndex].toolCalls[idx].result = content
                        }
                    case .completed:
                        break
                    }
                }
            } catch is CancellationError {
                // User cancelled
            } catch {
                errorMessage = error.localizedDescription
                // Remove assistant message if it has no visible content
                if assistantIndex < messages.count
                    && messages[assistantIndex].text.isEmpty
                    && messages[assistantIndex].toolCalls.isEmpty {
                    messages.remove(at: assistantIndex)
                }
            }
            isStreaming = false
            streamTask = nil
        }
    }

    func cancel() {
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
    }
}
