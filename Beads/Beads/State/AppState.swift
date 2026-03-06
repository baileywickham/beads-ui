import Foundation
import SwiftUI

@MainActor @Observable
package final class AppState {
    package init() {}

    var projects: [Project] = []
    var selectedProject: Project?
    var projectStates: [String: ProjectState] = [:]
    var workspaceRoots: [String] = ProjectDiscovery.defaultRoots
    var savedConnections: [DoltConnection] = SavedConnections.load()
    var showServerConnectionSheet: Bool = false

    let cliExecutor = CLIExecutor()

    func loadProjects() {
        let localProjects = ProjectDiscovery.discoverProjects(in: workspaceRoots)

        Task {
            let doltProjects = await ProjectDiscovery.discoverDoltProjects(connections: savedConnections)
            self.projects = localProjects + doltProjects
            if selectedProject == nil, let first = projects.first {
                selectProject(first)
            }
        }

        // Show local projects immediately while Dolt discovery runs
        projects = localProjects
        if selectedProject == nil, let first = projects.first {
            selectProject(first)
        }
    }

    func selectProject(_ project: Project) {
        selectedProject = project
        if projectStates[project.id] == nil {
            let state = ProjectState(project: project, cliExecutor: cliExecutor)
            projectStates[project.id] = state
            state.loadIssues()
            state.startWatching()
        }
    }

    var currentProjectState: ProjectState? {
        guard let project = selectedProject else { return nil }
        return projectStates[project.id]
    }

    // MARK: - Server Connections

    func addConnection(_ connection: DoltConnection) {
        SavedConnections.add(connection)
        savedConnections = SavedConnections.load()
        // Clear cached states for this server and reload
        for key in projectStates.keys where key.hasPrefix("dolt://") {
            projectStates[key]?.stopWatching()
            projectStates.removeValue(forKey: key)
        }
        loadProjects()
    }

    func removeConnection(_ connection: DoltConnection) {
        SavedConnections.remove(connection)
        savedConnections = SavedConnections.load()
        // Clean up states for removed connection
        let prefix = "dolt://\(connection.host):\(connection.port)"
        for key in projectStates.keys where key.hasPrefix(prefix) {
            projectStates[key]?.stopWatching()
            projectStates.removeValue(forKey: key)
        }
        loadProjects()
    }
}
