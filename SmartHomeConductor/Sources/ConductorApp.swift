import SwiftUI

@main
struct ConductorApp: App {
    @StateObject private var store = AppStore()
    @StateObject private var classifier = SoundClassifierController()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(classifier)
        }
    }
}
