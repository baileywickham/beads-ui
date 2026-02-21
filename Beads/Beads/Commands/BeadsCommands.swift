import SwiftUI

package struct BeadsCommands: Commands {
    package init() {}

    package var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("New Issue") {
                NotificationCenter.default.post(name: .createIssue, object: nil)
            }
            .keyboardShortcut("n")
        }

        CommandGroup(after: .textEditing) {
            Button("Start Claude on Issue") {
                NotificationCenter.default.post(name: .launchClaude, object: nil)
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])
        }

        CommandGroup(after: .toolbar) {
            Button("Refresh") {
                NotificationCenter.default.post(name: .refreshIssues, object: nil)
            }
            .keyboardShortcut("r")

            Divider()

            Button("Command Palette") {
                NotificationCenter.default.post(name: .toggleCommandPalette, object: nil)
            }
            .keyboardShortcut("k")
        }

        CommandGroup(after: .sidebar) {
            Button("Focus Sidebar") {
                NotificationCenter.default.post(name: .focusSidebar, object: nil)
            }
            .keyboardShortcut("1")

            Button("Focus Issue List") {
                NotificationCenter.default.post(name: .focusList, object: nil)
            }
            .keyboardShortcut("2")

            Button("Focus Detail") {
                NotificationCenter.default.post(name: .focusDetail, object: nil)
            }
            .keyboardShortcut("3")
        }
    }
}

extension Notification.Name {
    static let createIssue = Notification.Name("createIssue")
    static let refreshIssues = Notification.Name("refreshIssues")
    static let toggleCommandPalette = Notification.Name("toggleCommandPalette")
    static let focusSidebar = Notification.Name("focusSidebar")
    static let focusList = Notification.Name("focusList")
    static let focusDetail = Notification.Name("focusDetail")
    static let launchClaude = Notification.Name("launchClaude")
}
