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
                            selection = .status(.open)
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
                    .padding(.bottom, 4)
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
                        Label("All Issues", systemImage: "tray.full")
                            .badge(state.statusCounts.values.reduce(0, +))
                            .tag(StatusFilter.all)

                        ForEach(IssueStatus.sidebarStatuses, id: \.self) { status in
                            Label(status.label, systemImage: status.icon)
                                .foregroundStyle(status.color)
                                .badge(state.statusCounts[status] ?? 0)
                                .tag(StatusFilter.status(status))
                        }
                    }
                }
                .listStyle(.sidebar)
                .animation(.default, value: state.statusCounts)
                .onChange(of: selection) { _, newValue in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        switch newValue {
                        case .all:
                            state.statusFilter = nil
                        case .status(let status):
                            state.statusFilter = status
                        }
                    }
                }
            }
            // Version
            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                Text("v\(version)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.bottom, 8)
            }
        }
        .frame(minWidth: 180)
    }
}
