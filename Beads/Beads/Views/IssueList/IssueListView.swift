import SwiftUI

struct IssueListView: View {
    @Bindable var state: ProjectState
    @FocusState private var isFocused: Bool

    var body: some View {
        issueList
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .animation(.default, value: state.filteredIssues.map(\.id))
            .searchable(text: Binding(
                get: { state.searchText },
                set: { state.searchText = $0 }
            ), prompt: "Filter issues...")
            .overlay { emptyState }
            .focusable()
            .focused($isFocused)
            .onKeyPress(characters: CharacterSet(charactersIn: "jk")) { press in
                guard isFocused else { return .ignored }
                switch press.characters {
                case "j":
                    state.selectNextIssue()
                    return .handled
                case "k":
                    state.selectPreviousIssue()
                    return .handled
                default:
                    return .ignored
                }
            }
            .onKeyPress(keys: [.return], phases: .down) { press in
                guard press.modifiers.contains(EventModifiers.command) else { return .ignored }
                if let id = state.selectedIssueId {
                    state.launchClaude(id)
                    return .handled
                }
                return .ignored
            }
            .onAppear { isFocused = true }
            .frame(minWidth: 280)
    }

    private var issueList: some View {
        List(selection: Binding(
            get: { state.selectedIssueId },
            set: { id in
                if let id, let issue = state.filteredIssues.first(where: { $0.id == id }) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        state.selectIssue(issue)
                    }
                }
            }
        )) {
            ForEach(state.filteredIssues) { issue in
                IssueRow(
                    issue: issue,
                    isSelected: state.selectedIssueId == issue.id
                )
                .tag(issue.id)
                .contextMenu { contextMenu(for: issue) }
            }
        }
    }

    @ViewBuilder
    private func contextMenu(for issue: Issue) -> some View {
        Button("Launch Claude") {
            state.launchClaude(issue.id)
        }
        Button("Check Relevance") {
            state.launchClaude(issue.id, comment: "Before starting any work, check if this issue is still relevant. The codebase may have changed since this issue was created. Review the current state of the code and determine if this task has already been done, is no longer needed, or needs to be updated. Report your findings and close the issue with `bd close` if it's no longer relevant.")
        }

        Divider()

        if issue.status == .closed {
            Button("Reopen") {
                state.updateStatus(issue.id, to: .open)
            }
        } else {
            Button("Close") {
                state.closeAndAdvance(issue.id)
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if state.filteredIssues.isEmpty {
            ContentUnavailableView {
                Label("No Issues", systemImage: "tray")
            } description: {
                if !state.searchText.isEmpty {
                    Text("No issues match \"\(state.searchText)\"")
                } else if state.statusFilter != nil {
                    Text("No issues with this status")
                } else {
                    Text("This project has no issues")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.background)
        }
    }
}
