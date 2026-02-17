import SwiftUI

private enum StatusFilter: Hashable {
    case all
    case status(IssueStatus)
}

struct SidebarView: View {
    @Bindable var appState: AppState

    @State private var selection: StatusFilter = .status(.open)

    var body: some View {
        VStack(spacing: 0) {
            // Project picker
            if appState.projects.count > 1 {
                Menu {
                    ForEach(appState.projects) { project in
                        Button {
                            appState.selectProject(project)
                            selection = .all
                        } label: {
                            HStack {
                                Text(project.name)
                                if appState.selectedProject?.id == project.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "circle.hexagongrid")
                            .foregroundStyle(.blue)
                        Text(appState.selectedProject?.name ?? "Select Project")
                            .fontWeight(.semibold)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .menuStyle(.borderlessButton)

                Divider()
                    .padding(.horizontal, 8)
            } else if let project = appState.projects.first {
                HStack {
                    Image(systemName: "circle.hexagongrid")
                        .foregroundStyle(.blue)
                    Text(project.name)
                        .fontWeight(.semibold)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }

            // Status filters
            if let state = appState.currentProjectState {
                List(selection: $selection) {
                    Section("Filter") {
                        Label {
                            HStack {
                                Text("All Issues")
                                Spacer()
                                Text("\(state.statusCounts.values.reduce(0, +))")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                                    .monospacedDigit()
                            }
                        } icon: {
                            Image(systemName: "tray.full")
                        }
                        .tag(StatusFilter.all)

                        ForEach(IssueStatus.sidebarStatuses, id: \.self) { status in
                            Label {
                                HStack {
                                    Text(status.label)
                                    Spacer()
                                    Text("\(state.statusCounts[status] ?? 0)")
                                        .foregroundStyle(.secondary)
                                        .font(.caption)
                                        .monospacedDigit()
                                }
                            } icon: {
                                Image(systemName: status.icon)
                                    .foregroundStyle(status.color)
                            }
                            .tag(StatusFilter.status(status))
                        }
                    }
                }
                .listStyle(.sidebar)
                .onChange(of: selection) { _, newValue in
                    switch newValue {
                    case .all:
                        state.statusFilter = nil
                    case .status(let status):
                        state.statusFilter = status
                    }
                }
            }
        }
        .frame(minWidth: 180)
    }
}
