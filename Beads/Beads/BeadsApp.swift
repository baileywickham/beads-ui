import SwiftUI

@main
struct BeadsApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView(appState: appState)
        }
        .commands {
            BeadsCommands()
        }
        .defaultSize(width: 1200, height: 800)
    }
}
