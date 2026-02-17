import SwiftUI

struct IssueListView: View {
    @Bindable var state: ProjectState

    var body: some View {
        List(selection: Binding(
            get: { state.selectedIssueId },
            set: { id in
                if let id, let issue = state.filteredIssues.first(where: { $0.id == id }) {
                    state.selectIssue(issue)
                }
            }
        )) {
            ForEach(state.filteredIssues) { issue in
                IssueRow(
                    issue: issue,
                    isSelected: state.selectedIssueId == issue.id
                )
                .tag(issue.id)
                .contextMenu {
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
            }
        }
        .listStyle(.inset)
        .searchable(text: Binding(
            get: { state.searchText },
            set: { state.searchText = $0 }
        ), prompt: "Filter issues...")
        .overlay {
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
            }
        }
        .frame(minWidth: 280)
    }
}
