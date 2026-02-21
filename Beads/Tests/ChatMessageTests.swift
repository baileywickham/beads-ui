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

    @Test func textIsMutable() {
        var msg = ChatMessage(role: .assistant, text: "")
        msg.text += "streamed"
        #expect(msg.text == "streamed")
    }
}
