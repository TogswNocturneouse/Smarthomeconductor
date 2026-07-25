import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case home = "Home"
    case devices = "Devices"
    case signals = "Signals"
    case integrations = "Integrations"
    case logic = "Logic"
    case settings = "Settings"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .home: "house.fill"
        case .devices: "square.grid.2x2.fill"
        case .signals: "waveform.path.ecg"
        case .integrations: "antenna.radiowaves.left.and.right"
        case .logic: "point.3.connected.trianglepath.dotted"
        case .settings: "gearshape.fill"
        }
    }
}

struct ContentView: View {
    @State private var selection: AppTab = .home

    var body: some View {
        TabView(selection: $selection) {
            DashboardView()
                .tag(AppTab.home)
                .tabItem { Label(AppTab.home.rawValue, systemImage: AppTab.home.symbol) }

            DevicesView()
                .tag(AppTab.devices)
                .tabItem { Label(AppTab.devices.rawValue, systemImage: AppTab.devices.symbol) }

            SignalsView()
                .tag(AppTab.signals)
                .tabItem { Label(AppTab.signals.rawValue, systemImage: AppTab.signals.symbol) }

            IntegrationsView()
                .tag(AppTab.integrations)
                .tabItem { Label(AppTab.integrations.rawValue, systemImage: AppTab.integrations.symbol) }

            LogicView()
                .tag(AppTab.logic)
                .tabItem { Label(AppTab.logic.rawValue, systemImage: AppTab.logic.symbol) }

            SettingsView()
                .tag(AppTab.settings)
                .tabItem { Label(AppTab.settings.rawValue, systemImage: AppTab.settings.symbol) }
        }
        .tint(.teal)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AppStore())
    }
}
