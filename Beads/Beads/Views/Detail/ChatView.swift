import SwiftUI

struct ChatView: View {
    var chatState: ChatState
    var issue: Issue

    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Issue context header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(issue.id)
                            .font(.caption)
                            .monospaced()
                            .foregroundStyle(.secondary)
                        Text(issue.title)
                            .font(.callout)
                            .fontWeight(.medium)
                            .lineLimit(1)
                    }
                    if !issue.description.isEmpty {
                        Text(issue.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                Spacer()
                if !chatState.messages.isEmpty {
                    Button {
                        chatState.clear()
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .help("Clear chat")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onChange(of: chatState.messages.last?.text) {
                    scrollToBottom(proxy)
                }
                .onChange(of: chatState.messages.count) {
                    scrollToBottom(proxy)
                }
                .onChange(of: chatState.messages.last?.toolCalls.count) {
                    scrollToBottom(proxy)
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
                    .disabled(chatState.isStreaming)
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

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        if let last = chatState.messages.last {
            withAnimation(.easeOut(duration: 0.15)) {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    private func send() {
        let text = inputText
        inputText = ""
        chatState.sendMessage(text)
    }

    // MARK: - Tool call view

    private struct ToolCallView: View {
        let toolCall: ChatMessage.ToolCall
        let isStreaming: Bool
        @State private var isExpanded = false

        private var isRunning: Bool {
            isStreaming && toolCall.result == nil
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        // Status indicator
                        if isRunning {
                            ProgressView()
                                .controlSize(.mini)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }

                        Text(toolCall.name)
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(.medium)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if isExpanded {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(toolCall.input)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .lineLimit(8)

                        if let result = toolCall.result {
                            Divider()
                            Text(result)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.tertiary)
                                .lineLimit(12)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 6)
                }
            }
            .background(.fill.quinary)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    // MARK: - Message bubbles

    @ViewBuilder
    private func messageBubble(_ message: ChatMessage) -> some View {
        switch message.role {
        case .user:
            HStack {
                Spacer(minLength: 60)
                Text(message.text)
                    .font(.callout)
                    .padding(10)
                    .background(Color.accentColor.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        case .assistant:
            HStack {
                if message.text.isEmpty && message.toolCalls.isEmpty && chatState.isStreaming {
                    ProgressView()
                        .controlSize(.small)
                        .padding(10)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        if !message.text.isEmpty {
                            Text(message.text)
                                .font(.callout)
                                .textSelection(.enabled)
                        }
                        ForEach(message.toolCalls) { toolCall in
                            ToolCallView(
                                toolCall: toolCall,
                                isStreaming: chatState.isStreaming && message.id == chatState.messages.last?.id
                            )
                        }
                    }
                    .padding(10)
                    .background(.quaternary.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                Spacer(minLength: 60)
            }
        }
    }
}
