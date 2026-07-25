import SwiftUI

enum AppTab: String, CaseIterable, Identifiable, Hashable {
    case home = "Home"
    case assistant = "Assistant"
    case devices = "Devices"
    case signals = "Signals"
    case integrations = "Integrations"
    case logic = "Automations"
    case teach = "Teach"
    case settings = "Settings"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .home: "house.fill"
        case .assistant: "sparkles"
        case .devices: "square.grid.2x2.fill"
        case .signals: "waveform.path.ecg"
        case .integrations: "antenna.radiowaves.left.and.right"
        case .logic: "point.3.connected.trianglepath.dotted"
        case .teach: "brain.head.profile"
        case .settings: "gearshape.fill"
        }
    }

    var accent: Color {
        switch self {
        case .home, .devices: AppStyle.mint
        case .assistant, .integrations: AppStyle.violet
        case .signals: AppStyle.coral
        case .logic: AppStyle.cyan
        case .teach: AppStyle.mint
        case .settings: AppStyle.amber
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var navigation: AppNavigation
    @EnvironmentObject private var store: AppStore
    @State private var isMenuPresented = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.openWindow) private var openWindow

    private var selection: Binding<AppTab> {
        Binding(
            get: { navigation.selection },
            set: { navigation.selection = $0 }
        )
    }

    var body: some View {
        ZStack {
            AppBackground()

            if horizontalSizeClass == .compact {
                compactShell
            } else {
                regularShell
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            EnvironmentSummaryBar()
        }
        .tint(AppStyle.mint)
        .preferredColorScheme(.dark)
        .task {
            await store.refreshHomeAssistantIfConfigured()
        }
    }

    private var compactShell: some View {
        DestinationView(selection: navigation.selection)
            .id(navigation.selection)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                CompactTabBar(
                    selection: selection,
                    isMenuPresented: $isMenuPresented
                )
            }
            .sheet(isPresented: $isMenuPresented) {
                AppMenuView(selection: selection)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(.ultraThinMaterial)
            }
    }

    private var regularShell: some View {
        NavigationSplitView {
            Sidebar(selection: selection)
                .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 260)
        } detail: {
            DestinationView(selection: navigation.selection)
                .id(navigation.selection)
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    openWindow(id: "command-audit")
                } label: {
                    Image(systemName: "checklist")
                }
                .help("Command audit")

                Button {
                    openWindow(id: "conductor-settings")
                } label: {
                    Image(systemName: "gearshape")
                }
                .help("Conductor settings")
            }
        }
    }
}

private struct DestinationView: View {
    let selection: AppTab

    @ViewBuilder
    var body: some View {
        switch selection {
        case .home:
            DashboardView()
        case .assistant:
            AssistantView()
        case .devices:
            DevicesView()
        case .signals:
            SignalsView()
        case .integrations:
            IntegrationsView()
        case .logic:
            LogicView()
        case .teach:
            LearningView()
        case .settings:
            SettingsView()
        }
    }
}

private struct Sidebar: View {
    @Binding var selection: AppTab
    @EnvironmentObject private var store: AppStore

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(AppStyle.mint.opacity(0.13))
                    Image(systemName: "wave.3.right.circle.fill")
                        .foregroundStyle(AppStyle.mint)
                }
                .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 1) {
                    Text("CONDUCTOR")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppStyle.text)
                    Text("LOCAL CONTROL")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(AppStyle.secondaryText)
                }
                Spacer()
            }
            .padding(16)

            List {
                ForEach(AppTab.allCases) { tab in
                    Button {
                        selection = tab
                    } label: {
                        Label(tab.rawValue, systemImage: tab.symbol)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(
                                selection == tab
                                    ? tab.accent
                                    : AppStyle.secondaryText
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(
                        selection == tab
                            ? tab.accent.opacity(0.09)
                            : Color.clear
                    )
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)

            HStack(spacing: 9) {
                StatusDot(color: AppStyle.mint)
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(store.onlineDeviceCount) endpoints")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppStyle.text)
                    Text(
                        store.onlineDeviceCount > 0
                            ? "Local routes active"
                            : "Connections pending"
                    )
                        .font(.caption2)
                        .foregroundStyle(AppStyle.secondaryText)
                }
                Spacer()
            }
            .padding(16)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 0.7)
            }
        }
        .background(AppStyle.canvas.opacity(0.94))
    }
}

private struct CompactTabBar: View {
    @Binding var selection: AppTab
    @Binding var isMenuPresented: Bool

    private let tabs: [AppTab] = [.home, .devices, .logic, .teach]

    private var menuIsActive: Bool {
        [.assistant, .signals, .integrations, .settings].contains(selection)
    }

    var body: some View {
        HStack(spacing: 3) {
            ForEach(tabs) { tab in
                CompactTabButton(
                    title: tab.rawValue,
                    symbol: tab.symbol,
                    accent: tab.accent,
                    isActive: selection == tab
                ) {
                    selection = tab
                }
            }

            CompactTabButton(
                title: "Menu",
                symbol: "line.3.horizontal",
                accent: AppStyle.amber,
                isActive: menuIsActive
            ) {
                isMenuPresented = true
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 5)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(AppStyle.surface.opacity(0.90))
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.10))
                .frame(height: 0.7)
        }
    }
}

private struct CompactTabButton: View {
    let title: String
    let symbol: String
    let accent: Color
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(.system(size: 9, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(isActive ? accent : AppStyle.secondaryText)
            .frame(maxWidth: .infinity)
            .frame(height: 43)
        }
        .buttonStyle(.plain)
        .background(isActive ? accent.opacity(0.08) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(alignment: .top) {
            if isActive {
                StatusDot(color: accent)
                    .offset(y: -2)
            }
        }
        .contentShape(Rectangle())
        .accessibilityLabel(title)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

private struct AppMenuView: View {
    @Binding var selection: AppTab
    @Environment(\.dismiss) private var dismiss

    private let menuTabs: [AppTab] = [.assistant, .signals, .integrations, .settings]

    var body: some View {
        ZStack {
            AppBackground()

            VStack(alignment: .leading, spacing: 16) {
                Text("Menu")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppStyle.text)

                ForEach(menuTabs) { tab in
                    Button {
                        selection = tab
                        dismiss()
                    } label: {
                        HStack(spacing: 13) {
                            Image(systemName: tab.symbol)
                                .font(.title3)
                                .foregroundStyle(tab.accent)
                                .frame(width: 34)
                            Text(tab.rawValue)
                                .font(.headline)
                                .foregroundStyle(AppStyle.text)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(AppStyle.secondaryText)
                        }
                        .padding(15)
                    }
                    .buttonStyle(
                        GlassButtonStyle(
                            accent: tab.accent,
                            isActive: selection == tab
                        )
                    )
                }

                Spacer()
            }
            .padding(20)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AppStore())
            .environmentObject(SoundClassifierController())
            .environmentObject(LocalDiscoveryController())
    }
}
