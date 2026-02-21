import Foundation

struct ChatMessage: Identifiable, Hashable {
    let id: UUID
    let role: Role
    let timestamp: Date
    var blocks: [Block] = []

    enum Role: Hashable {
        case user
        case assistant
    }

    struct Block: Identifiable, Hashable {
        let id: String
        var content: Content

        enum Content: Hashable {
            case text(String)
            case toolCall(name: String, input: String, result: String?)
        }
    }

    struct ToolCall: Identifiable, Hashable {
        let id: String
        let name: String
        let input: String
        var result: String?
    }

    // Computed: all text concatenated (for compatibility)
    var text: String {
        blocks.compactMap {
            if case .text(let t) = $0.content { return t }
            return nil
        }.joined()
    }

    // Computed: all tool calls (for compatibility)
    var toolCalls: [ToolCall] {
        blocks.compactMap {
            if case .toolCall(let name, let input, let result) = $0.content {
                return ToolCall(id: $0.id, name: name, input: input, result: result)
            }
            return nil
        }
    }

    init(id: UUID = UUID(), role: Role, text: String = "", timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.timestamp = timestamp
        if !text.isEmpty {
            blocks.append(Block(id: UUID().uuidString, content: .text(text)))
        }
    }

    mutating func appendText(_ delta: String) {
        if let lastIndex = blocks.indices.last, case .text(let existing) = blocks[lastIndex].content {
            blocks[lastIndex].content = .text(existing + delta)
        } else {
            blocks.append(Block(id: UUID().uuidString, content: .text(delta)))
        }
    }

    mutating func addToolCall(id: String, name: String, input: String) {
        guard !blocks.contains(where: { $0.id == id }) else { return }
        blocks.append(Block(id: id, content: .toolCall(name: name, input: input, result: nil)))
    }

    mutating func setToolResult(toolUseId: String, content: String) {
        guard let idx = blocks.firstIndex(where: { $0.id == toolUseId }),
              case .toolCall(let name, let input, nil) = blocks[idx].content else { return }
        blocks[idx].content = .toolCall(name: name, input: input, result: content)
    }
}
