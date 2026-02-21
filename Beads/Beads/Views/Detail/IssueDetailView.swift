import SwiftUI

private enum DetailTab: Hashable {
    case comments
    case chat
}

struct IssueDetailView: View {
    let issue: Issue
    @Bindable var state: ProjectState

    @State private var editingTitle = false
    @State private var titleText = ""
    @State private var showClaudeComment = false
    @State private var claudeComment = ""
    @State private var selectedTab: DetailTab = .comments

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                header

                // Metadata
                GroupBox {
                    IssueMetadataView(
                        issue: issue,
                        onStatusChange: { status in
                            state.updateStatus(issue.id, to: status)
                        },
                        onPriorityChange: { priority in
                            state.updatePriority(issue.id, to: priority)
                        }
                    )
                    .padding(4)
                }

                // Description
                IssueMarkdownSection(
                    title: "Description",
                    content: issue.description,
                    onSave: { text in
                        state.updateField(issue.id, field: "description", value: text)
                    }
                )

                // Design
                if !issue.design.isEmpty {
                    IssueMarkdownSection(
                        title: "Design",
                        content: issue.design,
                        onSave: { text in
                            state.updateField(issue.id, field: "design", value: text)
                        }
                    )
                }

                // Acceptance Criteria
                if !issue.acceptanceCriteria.isEmpty {
                    IssueMarkdownSection(
                        title: "Acceptance Criteria",
                        content: issue.acceptanceCriteria,
                        onSave: { text in
                            state.updateField(issue.id, field: "acceptance", value: text)
                        }
                    )
                }

                // Notes
                if !issue.notes.isEmpty {
                    IssueMarkdownSection(
                        title: "Notes",
                        content: issue.notes,
                        onSave: { text in
                            state.updateField(issue.id, field: "notes", value: text)
                        }
                    )
                }

                // Dependencies
                if !issue.dependencies.isEmpty {
                    GroupBox {
                        IssueDependenciesView(
                            dependencies: issue.dependencies,
                            onSelect: { id in
                                state.loadIssueDetail(id: id)
                                state.selectedIssueId = id
                            }
                        )
                        .padding(4)
                    }
                }

                // Tab bar: Comments | Chat
                HStack(spacing: 0) {
                    tabButton("Comments", tab: .comments)
                    tabButton("Chat", tab: .chat)
                    Spacer()
                }

                // Tab content
                switch selectedTab {
                case .comments:
                    IssueCommentsView(
                        comments: issue.comments,
                        onAdd: { text in
                            state.addComment(issue.id, text: text)
                        }
                    )
                case .chat:
                    ChatView(chatState: state.chatState(for: issue.id))
                        .frame(minHeight: 300)
                }
            }
            .padding(20)
        }
        .frame(minWidth: 400)
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                if issue.status == .closed {
                    Button("Reopen") {
                        state.updateStatus(issue.id, to: .open)
                    }
                } else {
                    Button("Close") {
                        state.closeAndAdvance(issue.id)
                    }
                }

                Menu {
                    Button("Launch Claude") {
                        state.launchClaude(issue.id)
                    }
                    Button("Check Relevance") {
                        state.launchClaude(issue.id, comment: "Before starting any work, check if this issue is still relevant. The codebase may have changed since this issue was created. Review the current state of the code and determine if this task has already been done, is no longer needed, or needs to be updated. Report your findings and close the issue with `bd close` if it's no longer relevant.")
                    }
                    Divider()
                    Button("With Comment...") {
                        claudeComment = ""
                        showClaudeComment = true
                    }
                } label: {
                    Label("Claude", systemImage: "terminal")
                }
                .sheet(isPresented: $showClaudeComment) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Comment for Claude")
                            .font(.headline)
                        TextEditor(text: $claudeComment)
                            .font(.body)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .background(.quaternary.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        HStack {
                            Spacer()
                            Button("Cancel") {
                                showClaudeComment = false
                            }
                            .keyboardShortcut(.cancelAction)
                            Button("Launch") {
                                state.launchClaude(issue.id, comment: claudeComment)
                                showClaudeComment = false
                            }
                            .buttonStyle(.borderedProminent)
                            .keyboardShortcut(.return, modifiers: .command)
                        }
                    }
                    .padding()
                    .frame(minWidth: 400, minHeight: 200)
                }
            }
        }
    }

    @ViewBuilder
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(issue.id)
                    .font(.callout)
                    .monospaced()
                    .foregroundStyle(.secondary)

                if issue.pinned {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            if editingTitle {
                HStack {
                    TextField("Title", text: $titleText)
                        .font(.title2)
                        .fontWeight(.bold)
                        .textFieldStyle(.plain)
                        .onSubmit {
                            state.updateTitle(issue.id, to: titleText)
                            editingTitle = false
                        }
                    Button("Save") {
                        state.updateTitle(issue.id, to: titleText)
                        editingTitle = false
                    }
                    .controlSize(.small)
                }
            } else {
                Text(issue.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .textSelection(.enabled)
                    .onTapGesture(count: 2) {
                        titleText = issue.title
                        editingTitle = true
                    }
            }
        }
    }

    @ViewBuilder
    private func tabButton(_ title: String, tab: DetailTab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(selectedTab == tab ? .semibold : .regular)
                    .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                Rectangle()
                    .fill(selectedTab == tab ? Color.accentColor : .clear)
                    .frame(height: 2)
            }
        }
        .buttonStyle(.plain)
        .frame(width: 80)
    }
}
