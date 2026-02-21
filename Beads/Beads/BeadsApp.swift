import SwiftUI
import Sparkle
import BeadsLib

final class UpdaterDelegate: NSObject, SPUUpdaterDelegate {
    func allowedChannels(for updater: SPUUpdater) -> Set<String> {
        UserDefaults.standard.bool(forKey: "betaUpdates") ? Set(["beta"]) : Set()
    }
}

@main
struct BeadsApp: App {
    @State private var appState = AppState()
    @State private var betaUpdates = UserDefaults.standard.bool(forKey: "betaUpdates")
    private let updaterDelegate = UpdaterDelegate()
    private let updaterController: SPUStandardUpdaterController

    init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: updaterDelegate,
            userDriverDelegate: nil
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView(appState: appState)
        }
        .commands {
            BeadsCommands()
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: updaterController.updater)
                Toggle("Beta Updates", isOn: $betaUpdates)
                    .onChange(of: betaUpdates) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "betaUpdates")
                    }
            }
        }
        .defaultSize(width: 1200, height: 800)
    }
}

struct CheckForUpdatesView: View {
    @ObservedObject private var viewModel: CheckForUpdatesViewModel
    private let updater: SPUUpdater

    init(updater: SPUUpdater) {
        self.updater = updater
        self.viewModel = CheckForUpdatesViewModel(updater: updater)
    }

    var body: some View {
        Button("Check for Updates…", action: updater.checkForUpdates)
            .disabled(!viewModel.canCheckForUpdates)
    }
}

final class CheckForUpdatesViewModel: ObservableObject {
    @Published var canCheckForUpdates = false

    init(updater: SPUUpdater) {
        updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }
}
