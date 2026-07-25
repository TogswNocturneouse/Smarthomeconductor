import SwiftUI

struct IntegrationsView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var classifier: SoundClassifierController
    @State private var selectedAdapter: BrandAdapterPlan?

    private let columns = [
        GridItem(.adaptive(minimum: 290), spacing: 11)
    ]

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 20) {
                    IntegrationStatusBand()

                    SectionHeader(
                        title: "Connection routes",
                        subtitle: "Discovery, authorization, and validation boundaries"
                    )

                    LazyVGrid(columns: columns, spacing: 11) {
                        ForEach(store.brandAdapters) { adapter in
                            BrandAdapterCard(adapter: adapter) {
                                selectedAdapter = adapter
                            }
                        }
                    }

                    SectionHeader(
                        title: "RF and IR bridge",
                        subtitle: "Stored commands for legacy hardware"
                    )

                    LazyVGrid(columns: columns, spacing: 11) {
                        ForEach(store.bridgeCommands) { command in
                            BridgeCommandCard(command: command)
                        }
                    }

                    SectionHeader(
                        title: "On-device intelligence",
                        subtitle: "Models available to the automation engine"
                    )

                    ForEach(store.classifierSlots) { slot in
                        ClassifierSlotCard(
                            slot: slot,
                            modelIsBundled: classifier.modelIsBundled
                        )
                    }
                }
                .padding(16)
            }
            .background(Color.clear)
            .navigationTitle("Integrations")
            .sheet(item: $selectedAdapter) { adapter in
                IntegrationConnectionView(adapter: adapter)
            }
        }
    }
}

private struct IntegrationStatusBand: View {
    @EnvironmentObject private var store: AppStore

    private var enabledCount: Int {
        store.brandAdapters.filter(\.isEnabled).count
    }

    private var discoveredCount: Int {
        store.brandAdapters.map(\.discoveredDevices).reduce(0, +)
    }

    var body: some View {
        GlassPanel(
            accent: AppStyle.violet,
            isActive: enabledCount > 0
        ) {
            HStack(spacing: 14) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.title2)
                    .foregroundStyle(AppStyle.violet)
                    .frame(width: 42, height: 42)
                    .background(AppStyle.violet.opacity(0.11))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Adapter registry")
                        .font(.headline)
                        .foregroundStyle(AppStyle.text)
                    Text("\(enabledCount) enabled - \(discoveredCount) endpoints found")
                        .font(.subheadline)
                        .foregroundStyle(AppStyle.secondaryText)
                }
                Spacer()
                Pill("ISOLATED", color: AppStyle.violet)
            }
        }
    }
}

private struct BrandAdapterCard: View {
    let adapter: BrandAdapterPlan
    let openConnection: () -> Void
    @EnvironmentObject private var store: AppStore

    private var stageColor: Color {
        switch adapter.stage {
        case .ready: AppStyle.mint
        case .scaffolded: AppStyle.cyan
        case .planned: AppStyle.amber
        }
    }

    var body: some View {
        GlassPanel(
            accent: stageColor,
            isActive: adapter.isEnabled
        ) {
            VStack(alignment: .leading, spacing: 13) {
                HStack(alignment: .top, spacing: 11) {
                    Image(systemName: adapter.symbol)
                        .font(.title3)
                        .foregroundStyle(stageColor)
                        .frame(width: 38, height: 38)
                        .background(stageColor.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(adapter.brand)
                            .font(.headline)
                            .foregroundStyle(AppStyle.text)
                        Text(adapter.ecosystem)
                            .font(.caption)
                            .foregroundStyle(AppStyle.secondaryText)
                            .lineLimit(2)
                    }

                    Spacer()

                    Pill(adapter.stage.rawValue, color: stageColor)
                }

                TagGrid(
                    items: adapter.deviceKinds.map(\.rawValue),
                    color: stageColor
                )

                Text(adapter.connectionPlan)
                    .font(.caption)
                    .foregroundStyle(AppStyle.secondaryText)

                Label(adapter.nextAction, systemImage: "arrow.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(stageColor)

                if adapter.brand == "TP-Link / Tapo" ||
                    adapter.brand == "Home Assistant" ||
                    adapter.brand == "Apple Home"
                {
                    Button(action: openConnection) {
                        Label(
                            adapter.isEnabled ? "Manage connection" : "Connect",
                            systemImage: "link"
                        )
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                    }
                    .buttonStyle(GlassButtonStyle(accent: stageColor))
                }
            }
        }
    }
}

private struct IntegrationConnectionView: View {
    let adapter: BrandAdapterPlan

    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var discovery: LocalDiscoveryController
    @Environment(\.dismiss) private var dismiss
    @State private var address = ""
    @State private var token = ""
    @State private var resultMessage: String?

    private var isTapo: Bool {
        adapter.brand == "TP-Link / Tapo"
    }

    private var showsHomeAssistant: Bool {
        isTapo || adapter.brand == "Home Assistant"
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 18) {
                    SectionHeader(
                        title: adapter.brand,
                        subtitle: "Use a route that can prove it reached the device."
                    )

                    if isTapo {
                        tapoRoutes
                    } else if adapter.brand == "Apple Home" {
                        appleHomeRoute
                    }

                    if showsHomeAssistant {
                        homeAssistantForm
                    }
                }
                .padding(18)
            }
            .background(AppBackground())
            .navigationTitle("Connect")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            if address.isEmpty {
                address = store.homeAssistant.savedAddress
            }
        }
    }

    private var tapoRoutes: some View {
        VStack(alignment: .leading, spacing: 12) {
            GlassPanel(accent: AppStyle.mint) {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Compatibility already enabled", systemImage: "checkmark.shield")
                        .font(.headline)
                        .foregroundStyle(AppStyle.text)
                    Text(
                        "Conductor will not send you back to that switch. Tapo states that enabling it does not guarantee a third-party connection; the next step is an authenticated route with read-back."
                    )
                    .font(.caption)
                    .foregroundStyle(AppStyle.secondaryText)

                    Link(
                        destination: URL(string: "https://www.tapo.com/en/faq/714/")!
                    ) {
                        Label("Tapo compatibility details", systemImage: "arrow.up.right.square")
                    }
                    .font(.subheadline.weight(.semibold))
                }
            }

            GlassPanel(accent: AppStyle.cyan) {
                VStack(alignment: .leading, spacing: 10) {
                    Label("H100 and T310", systemImage: "homekit")
                        .font(.headline)
                        .foregroundStyle(AppStyle.text)
                    Text(
                        "Bridge the T310 through the H100 Matter Bridge, add it to Apple Home, then import it here."
                    )
                    .font(.caption)
                    .foregroundStyle(AppStyle.secondaryText)

                    Button {
                        discovery.importAppleHome()
                        resultMessage = "Apple Home access requested. Imported accessories appear under Devices > Add > Discover."
                    } label: {
                        Label("Import from Apple Home", systemImage: "house")
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                    }
                    .buttonStyle(GlassButtonStyle(accent: AppStyle.cyan))

                    Link(
                        destination: URL(
                            string: "https://community.tp-link.com/us/home/kb/detail/412808"
                        )!
                    ) {
                        Label("Official H100 Matter Bridge guide", systemImage: "arrow.up.right.square")
                    }
                    .font(.subheadline.weight(.semibold))
                }
            }

            GlassPanel(accent: AppStyle.coral) {
                VStack(alignment: .leading, spacing: 10) {
                    Label("C220 and TC71 cameras", systemImage: "video")
                        .font(.headline)
                        .foregroundStyle(AppStyle.text)
                    Text(
                        "Tapo cameras use a separate camera account for RTSP/ONVIF. Your TP-Link account password is not the camera-stream password."
                    )
                    .font(.caption)
                    .foregroundStyle(AppStyle.secondaryText)
                    Link(
                        destination: URL(string: "https://www.tapo.com/en/faq/34/")!
                    ) {
                        Label("Official camera account and RTSP guide", systemImage: "arrow.up.right.square")
                    }
                    .font(.subheadline.weight(.semibold))
                }
            }

            if let resultMessage {
                Label(resultMessage, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(AppStyle.secondaryText)
            }
        }
    }

    private var appleHomeRoute: some View {
        GlassPanel(accent: AppStyle.cyan) {
            VStack(alignment: .leading, spacing: 11) {
                Text(
                    "Import devices already commissioned in Apple Home. Conductor requests Home access and preserves the existing room assignment."
                )
                .font(.caption)
                .foregroundStyle(AppStyle.secondaryText)

                Button {
                    discovery.importAppleHome()
                    resultMessage = "Apple Home access requested. Open Devices > Add > Discover to review accessories."
                } label: {
                    Label("Request access", systemImage: "house")
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                }
                .buttonStyle(GlassButtonStyle(accent: AppStyle.cyan))

                if let resultMessage {
                    Text(resultMessage)
                        .font(.caption)
                        .foregroundStyle(AppStyle.secondaryText)
                }
            }
        }
    }

    private var homeAssistantForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: "Home Assistant",
                subtitle: "Authenticated local import and real command transport"
            )

            GlassPanel(
                accent: store.homeAssistant.isConnected ? AppStyle.mint : AppStyle.violet,
                isActive: store.homeAssistant.isConnected
            ) {
                VStack(alignment: .leading, spacing: 13) {
                    TextField(
                        "http://homeassistant.local:8123",
                        text: $address
                    )
                    .textContentType(.URL)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()

                    SecureField("Long-lived access token", text: $token)
                        .textFieldStyle(.roundedBorder)

                    HStack(spacing: 10) {
                        Button {
                            connectHomeAssistant()
                        } label: {
                            Label("Connect and import", systemImage: "link")
                                .frame(maxWidth: .infinity)
                                .frame(height: 42)
                        }
                        .buttonStyle(GlassButtonStyle(accent: AppStyle.mint))
                        .disabled(
                            store.homeAssistant.isWorking ||
                            address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                            token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        )

                        if !store.homeAssistant.savedAddress.isEmpty {
                            Button {
                                refreshHomeAssistant()
                            } label: {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .frame(width: 42, height: 42)
                            }
                            .buttonStyle(GlassButtonStyle(accent: AppStyle.cyan))
                            .disabled(store.homeAssistant.isWorking)
                            .accessibilityLabel("Refresh saved Home Assistant connection")
                        }
                    }

                    if store.homeAssistant.isWorking {
                        ProgressView()
                            .controlSize(.small)
                    }

                    Label(
                        store.homeAssistant.status,
                        systemImage: store.homeAssistant.isConnected
                            ? "checkmark.circle.fill"
                            : "network"
                    )
                    .font(.caption)
                    .foregroundStyle(
                        store.homeAssistant.isConnected
                            ? AppStyle.mint
                            : AppStyle.secondaryText
                    )

                    if let error = store.homeAssistant.lastError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(AppStyle.coral)
                    }

                    HStack {
                        Link(
                            destination: URL(
                                string: "https://developers.home-assistant.io/docs/api/rest/"
                            )!
                        ) {
                            Label("Token instructions", systemImage: "arrow.up.right.square")
                        }

                        Spacer()

                        if !store.homeAssistant.savedAddress.isEmpty {
                            Button("Disconnect", role: .destructive) {
                                store.disconnectHomeAssistant()
                            }
                        }
                    }
                    .font(.caption.weight(.semibold))

                    Link(
                        destination: URL(string: "https://www.home-assistant.io/installation/")!
                    ) {
                        Label("Install Home Assistant", systemImage: "arrow.up.right.square")
                    }
                    .font(.caption.weight(.semibold))
                }
            }
        }
    }

    private func connectHomeAssistant() {
        Task {
            do {
                let devices = try await store.homeAssistant.connect(
                    address: address,
                    token: token
                )
                store.importHomeAssistantDevices(devices)
                token = ""
                resultMessage = "\(devices.count) live entities imported."
            } catch {
                resultMessage = error.localizedDescription
            }
        }
    }

    private func refreshHomeAssistant() {
        Task {
            do {
                let devices = try await store.homeAssistant.reconnectAndImport()
                store.importHomeAssistantDevices(devices)
                resultMessage = "\(devices.count) live entities refreshed."
            } catch {
                resultMessage = error.localizedDescription
            }
        }
    }
}

private struct BridgeCommandCard: View {
    let command: BridgeCommand
    @EnvironmentObject private var store: AppStore

    private var accent: Color {
        command.transport == .infrared ? AppStyle.coral : AppStyle.amber
    }

    var body: some View {
        GlassPanel(
            accent: accent,
            isActive: false
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(
                        systemName: command.transport == .infrared
                            ? "sensor.tag.radiowaves.forward"
                            : "dot.radiowaves.left.and.right"
                    )
                    .font(.title3)
                    .foregroundStyle(accent)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(command.name)
                            .font(.headline)
                            .foregroundStyle(AppStyle.text)
                        Text("\(command.transport.rawValue) - \(command.target)")
                            .font(.caption)
                            .foregroundStyle(AppStyle.secondaryText)
                    }
                    Spacer()
                    if let result = command.lastResult {
                        Pill(
                            result,
                            color: result.hasPrefix("Blocked")
                                ? AppStyle.coral
                                : AppStyle.secondaryText
                        )
                    }
                }

                Text(command.payload)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(AppStyle.secondaryText)
                    .padding(9)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.black.opacity(0.22))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                Label(command.safetyNote, systemImage: "shield")
                    .font(.caption)
                    .foregroundStyle(AppStyle.secondaryText)

                HStack {
                    Button {
                        store.executeBridgeCommand(command.id)
                    } label: {
                        Label("Send command", systemImage: "paperplane.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppStyle.text)
                            .padding(.horizontal, 13)
                            .frame(height: 40)
                    }
                    .buttonStyle(GlassButtonStyle(accent: accent))

                    Spacer()

                    if let lastRun = command.lastRun {
                        Text(lastRun, style: .relative)
                            .font(.caption)
                            .foregroundStyle(AppStyle.secondaryText)
                    }
                }
            }
        }
    }
}

private struct ClassifierSlotCard: View {
    let slot: ClassifierSlot
    let modelIsBundled: Bool

    var body: some View {
        GlassPanel(
            accent: modelIsBundled ? AppStyle.coral : AppStyle.amber,
            isActive: modelIsBundled
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(slot.name, systemImage: "waveform")
                        .font(.headline)
                        .foregroundStyle(AppStyle.text)
                    Spacer()
                    Pill(
                        modelIsBundled ? "BUNDLED" : "MISSING",
                        color: modelIsBundled ? AppStyle.mint : AppStyle.amber
                    )
                }

                Text(slot.modelFile)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(AppStyle.secondaryText)

                Text(slot.input)
                    .font(.subheadline)
                    .foregroundStyle(AppStyle.secondaryText)

                TagGrid(items: slot.outputs, color: AppStyle.coral)
            }
        }
    }
}
