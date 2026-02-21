import SwiftUI

struct ChatView: View {
    var chatState: ChatState

    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(chatState.messages) { message in
                            messageBubble(message)
                                .id(message.id)
                        }
                    }
                    .padding(12)
                }
                .onChange(of: chatState.messages.last?.text) {
                    if let last = chatState.messages.last {
                        withAnimation(.easeOut(duration: 0.15)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: chatState.messages.count) {
                    if let last = chatState.messages.last {
                        withAnimation(.easeOut(duration: 0.15)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            // Error banner
            if let error = chatState.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(error)
                        .lineLimit(2)
                    Spacer()
                    Button {
                        chatState.errorMessage = nil
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.borderless)
                }
                .font(.callout)
                .foregroundStyle(.yellow)
                .padding(8)
                .background(.yellow.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .padding(.horizontal, 12)
            }

            // Input
            HStack(alignment: .bottom) {
                TextField("Ask Claude...", text: $inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...8)
                    .focused($isInputFocused)
                    .onSubmit {
                        if !NSEvent.modifierFlags.contains(.shift) {
                            send()
                        }
                    }

                if chatState.isStreaming {
                    Button {
                        chatState.cancel()
                    } label: {
                        Image(systemName: "stop.circle.fill")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.borderless)
                } else {
                    Button {
                        send()
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .foregroundStyle(
                                inputText.trimmingCharacters(in: .whitespaces).isEmpty
                                    ? Color.secondary : Color.accentColor
                            )
                    }
                    .buttonStyle(.borderless)
                    .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isInputFocused ? Color.accentColor.opacity(0.5) : Color.secondary.opacity(0.2),
                        lineWidth: 1
                    )
                    .fill(.background)
            )
            .padding(12)
        }
    }

    private func send() {
        let text = inputText
        inputText = ""
        chatState.sendMessage(text)
    }

    @ViewBuilder
    private func messageBubble(_ message: ChatMessage) -> some View {
        switch message.role {
        case .user:
            HStack {
                Spacer(minLength: 60)
                Text(message.text)
                    .padding(10)
                    .background(Color.accentColor.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        case .assistant:
            HStack {
                if message.text.isEmpty && chatState.isStreaming {
                    ProgressView()
                        .controlSize(.small)
                        .padding(10)
                } else {
                    MarkdownView(content: message.text)
                        .font(.callout)
                        .padding(10)
                        .background(.quaternary.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                Spacer(minLength: 60)
            }
        }
    }
}
