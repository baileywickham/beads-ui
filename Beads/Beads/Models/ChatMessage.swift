import Foundation

struct ChatMessage: Identifiable, Hashable {
    let id: UUID
    let role: Role
    var text: String
    let timestamp: Date
    var toolCalls: [ToolCall]

    enum Role: Hashable {
        case user
        case assistant
    }

    struct ToolCall: Identifiable, Hashable {
        let id: String
        let name: String
        let input: String
        var result: String?
    }

    init(id: UUID = UUID(), role: Role, text: String, timestamp: Date = Date(), toolCalls: [ToolCall] = []) {
        self.id = id
        self.role = role
        self.text = text
        self.timestamp = timestamp
        self.toolCalls = toolCalls
    }
}
