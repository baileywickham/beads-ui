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
                .onChange(of: chatState.messages.last?.blocks.count) {
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

        private var toolIcon: String {
            switch toolCall.name {
            case "Read": "doc.text"
            case "Write": "doc.text.fill"
            case "Edit": "pencil"
            case "Bash": "terminal"
            case "Glob": "folder.badge.gearshape"
            case "Grep": "magnifyingglass"
            case "WebFetch", "WebSearch": "globe"
            default: "gearshape"
            }
        }

        private var summary: String? {
            guard let data = toolCall.input.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { return nil }

            if let cmd = obj["command"] as? String { return cmd }
            if let path = obj["file_path"] as? String { return (path as NSString).lastPathComponent }
            if let pattern = obj["pattern"] as? String { return pattern }
            if let query = obj["query"] as? String { return query }
            return nil
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        if isRunning {
                            ProgressView()
                                .controlSize(.mini)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }

                        Image(systemName: toolIcon)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .frame(width: 14)

                        Text(toolCall.name)
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(.medium)

                        if let summary {
                            Text(summary)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }

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
                    VStack(alignment: .leading, spacing: 4) {
                        Text(toolCall.input)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .lineLimit(8)
                            .textSelection(.enabled)

                        if let result = toolCall.result {
                            Divider()
                                .padding(.vertical, 2)
                            Text(result)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.tertiary)
                                .lineLimit(16)
                                .textSelection(.enabled)
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
            let isLast = message.id == chatState.messages.last?.id
            HStack {
                if message.blocks.isEmpty && chatState.isStreaming {
                    ProgressView()
                        .controlSize(.small)
                        .padding(10)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(message.blocks) { block in
                            switch block.content {
                            case .text(let text):
                                if chatState.isStreaming && isLast {
                                    Text(text)
                                        .font(.callout)
                                        .textSelection(.enabled)
                                } else {
                                    MarkdownView(content: text)
                                        .font(.callout)
                                }
                            case .toolCall(let name, let input, let result):
                                ToolCallView(
                                    toolCall: ChatMessage.ToolCall(id: block.id, name: name, input: input, result: result),
                                    isStreaming: chatState.isStreaming && isLast
                                )
                            }
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
