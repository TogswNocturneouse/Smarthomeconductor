import SwiftUI
import SwiftData

@main
struct ConductorApp: App {
    @StateObject private var store = AppStore()
    @StateObject private var classifier = SoundClassifierController()
    @StateObject private var discovery = LocalDiscoveryController()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(classifier)
                .environmentObject(discovery)
                .modelContainer(for: LearnedRecord.self)
        }
    }
}
