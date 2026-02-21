import SwiftUI

package struct ContentView: View {
    @Bindable package var appState: AppState

    package init(appState: AppState) {
        self.appState = appState
    }
    @State private var paletteState = CommandPaletteState()
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    package var body: some View {
        ZStack {
            NavigationSplitView(columnVisibility: $columnVisibility) {
                SidebarView(appState: appState)
                    .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 300)
            } content: {
                if let state = appState.currentProjectState {
                    IssueListView(state: state)
                        .navigationSplitViewColumnWidth(min: 280, ideal: 340, max: 500)
                } else {
                    ContentUnavailableView(
                        "Select a Project",
                        systemImage: "sidebar.left",
                        description: Text("Choose a project from the sidebar")
                    )
                }
            } detail: {
                if let state = appState.currentProjectState, let issue = state.selectedIssue {
                    IssueDetailView(issue: issue, state: state)
                        .id(issue.id)
                        .transition(.opacity)
                } else {
                    ContentUnavailableView(
                        "Select an Issue",
                        systemImage: "doc.text",
                        description: Text("Choose an issue from the list")
                    )
                }
            }
            .animation(.easeInOut(duration: 0.2), value: appState.currentProjectState?.selectedIssueId)
            .navigationTitle(appState.selectedProject?.name ?? "Beads")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    if let state = appState.currentProjectState {
                        Button {
                            state.showCreateSheet = true
                        } label: {
                            Label("New Issue", systemImage: "plus")
                        }
                        .keyboardShortcut("n")
                    }

                    Button {
                        appState.currentProjectState?.loadIssues()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .keyboardShortcut("r")
                }
            }
            .sheet(isPresented: Binding(
                get: { appState.currentProjectState?.showCreateSheet ?? false },
                set: { newValue in appState.currentProjectState?.showCreateSheet = newValue }
            )) {
                if let state = appState.currentProjectState {
                    CreateIssueSheet(state: state)
                }
            }
            .alert(
                "Error",
                isPresented: Binding(
                    get: { appState.currentProjectState?.errorMessage != nil },
                    set: { if !$0 { appState.currentProjectState?.errorMessage = nil } }
                )
            ) {
                Button("OK") { appState.currentProjectState?.errorMessage = nil }
            } message: {
                Text(appState.currentProjectState?.errorMessage ?? "")
            }

            // Command palette overlay
            if paletteState.isVisible {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture { paletteState.toggle() }
                    .transition(.opacity)

                VStack {
                    CommandPaletteView(
                        paletteState: paletteState,
                        onSelect: { issue in
                            appState.currentProjectState?.selectIssue(issue)
                        }
                    )
                    .padding(.top, 100)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    Spacer()
                }
            }
        }
        .animation(.easeOut(duration: 0.2), value: paletteState.isVisible)
        .onAppear {
            appState.loadProjects()
        }
        .onChange(of: appState.selectedProject) { _, newProject in
            if let project = newProject {
                paletteState.configure(dbPath: project.dbPath)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleCommandPalette)) { _ in
            paletteState.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: .refreshIssues)) { _ in
            appState.currentProjectState?.loadIssues()
        }
        .onReceive(NotificationCenter.default.publisher(for: .createIssue)) { _ in
            appState.currentProjectState?.showCreateSheet = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .launchClaude)) { _ in
            if let state = appState.currentProjectState, let id = state.selectedIssueId {
                state.launchClaude(id)
            }
        }
        .onKeyPress(keys: [.return], phases: .down) { press in
            guard press.modifiers.contains(EventModifiers.command) else { return .ignored }
            if let state = appState.currentProjectState, let id = state.selectedIssueId {
                state.launchClaude(id)
                return .handled
            }
            return .ignored
        }
    }
}
