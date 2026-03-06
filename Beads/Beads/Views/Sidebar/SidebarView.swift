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
            projectPicker

            if let state = appState.currentProjectState {
                List(selection: $selection) {
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

            Spacer()

            VStack(spacing: 4) {
                Button {
                    appState.showServerConnectionSheet = true
                } label: {
                    HStack {
                        Image(systemName: "server.rack")
                        Text("Connect to Server...")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderless)
                .padding(.horizontal, 12)

                if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                    Text("v\(version)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.bottom, 8)
        }
        .frame(minWidth: 180)
    }

    @ViewBuilder
    private var projectPicker: some View {
        if appState.projects.count > 1 {
            VStack(spacing: 0) {
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
                        Image(systemName: appState.selectedProject?.isDolt == true ? "server.rack" : "circle.hexagongrid")
                            .foregroundStyle(appState.selectedProject?.isDolt == true ? .orange : .blue)
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
                    .padding(.vertical, 8)
            }
        } else if let project = appState.projects.first {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: project.isDolt ? "server.rack" : "circle.hexagongrid")
                        .foregroundStyle(project.isDolt ? .orange : .blue)
                    Text(project.name)
                        .fontWeight(.semibold)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                Divider()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
            }
        }
    }
}
