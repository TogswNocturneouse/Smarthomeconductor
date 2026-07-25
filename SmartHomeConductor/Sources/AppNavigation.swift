import SwiftUI

@MainActor
final class AppNavigation: ObservableObject {
    @Published var selection: AppTab = .home
}

struct ConductorCommands: Commands {
    @ObservedObject var navigation: AppNavigation
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandMenu("Navigate") {
            Button("Home") {
                navigation.selection = .home
            }
            .keyboardShortcut("1", modifiers: .command)

            Button("Assistant") {
                navigation.selection = .assistant
            }
            .keyboardShortcut("2", modifiers: .command)

            Button("Devices") {
                navigation.selection = .devices
            }
            .keyboardShortcut("3", modifiers: .command)

            Button("Signals") {
                navigation.selection = .signals
            }
            .keyboardShortcut("4", modifiers: .command)

            Button("Integrations") {
                navigation.selection = .integrations
            }
            .keyboardShortcut("5", modifiers: .command)

            Button("Automations") {
                navigation.selection = .logic
            }
            .keyboardShortcut("6", modifiers: .command)

            Button("Teach Conductor") {
                navigation.selection = .teach
            }
            .keyboardShortcut("7", modifiers: .command)
        }

        CommandMenu("Operations") {
            Button("Command Audit") {
                openWindow(id: "command-audit")
            }
            .keyboardShortcut("l", modifiers: [.command, .shift])

            Button("Conductor Settings") {
                openWindow(id: "conductor-settings")
            }
            .keyboardShortcut(",", modifiers: .command)
        }
    }
}
