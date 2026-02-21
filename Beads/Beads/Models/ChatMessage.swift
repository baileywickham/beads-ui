import Foundation

struct ChatMessage: Identifiable, Hashable {
    let id: UUID
    let role: Role
    var text: String
    let timestamp: Date

    enum Role: Hashable {
        case user
        case assistant
    }

    init(id: UUID = UUID(), role: Role, text: String, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.text = text
        self.timestamp = timestamp
    }
}
