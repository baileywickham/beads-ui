import Foundation
import SwiftUI

@MainActor @Observable
package final class AppState {
    package init() {}

    var projects: [Project] = []
    var selectedProject: Project?
    var projectStates: [String: ProjectState] = [:]
    var workspaceRoots: [String] = ProjectDiscovery.defaultRoots

    let cliExecutor = CLIExecutor()

    func loadProjects() {
        projects = ProjectDiscovery.discoverProjects(in: workspaceRoots)
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
}
