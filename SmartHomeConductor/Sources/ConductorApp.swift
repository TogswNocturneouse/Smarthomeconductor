import SwiftUI
import SwiftData

@main
struct ConductorApp: App {
    private let modelContainer: ModelContainer
    @StateObject private var store: AppStore
    @StateObject private var classifier = SoundClassifierController()
    @StateObject private var discovery = LocalDiscoveryController()
    @StateObject private var navigation = AppNavigation()

    init() {
        let result = AppModelContainer.make()
        modelContainer = result.container
        _store = StateObject(
            wrappedValue: AppStore(
                modelContainer: result.container,
                persistenceMode: result.mode
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(classifier)
                .environmentObject(discovery)
                .environmentObject(navigation)
                .modelContainer(modelContainer)
        }
        .commands {
            ConductorCommands(navigation: navigation)
        }

        WindowGroup("Command Audit", id: "command-audit") {
            AuditLogView()
                .environmentObject(store)
                .modelContainer(modelContainer)
        }

        WindowGroup("Conductor Settings", id: "conductor-settings") {
            ZStack {
                AppBackground()
                SettingsView()
                    .environmentObject(store)
                    .environmentObject(classifier)
            }
            .modelContainer(modelContainer)
        }
    }
}
