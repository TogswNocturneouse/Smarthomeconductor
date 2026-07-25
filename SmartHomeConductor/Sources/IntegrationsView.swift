import SwiftUI

struct IntegrationsView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var classifier: SoundClassifierController

    private let columns = [
        GridItem(.adaptive(minimum: 290), spacing: 11)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    IntegrationStatusBand()

                    SectionHeader(
                        title: "Brand adapters",
                        subtitle: "Discovery and endpoint status"
                    )

                    LazyVGrid(columns: columns, spacing: 11) {
                        ForEach(store.brandAdapters) { adapter in
                            BrandAdapterCard(adapter: adapter)
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

                HStack {
                    Label(
                        "\(adapter.discoveredDevices) endpoints",
                        systemImage: "dot.radiowaves.left.and.right"
                    )
                    Spacer()
                    if let lastSync = adapter.lastSync {
                        Text(lastSync, style: .relative)
                    } else {
                        Text("Never scanned")
                    }
                }
                .font(.caption)
                .foregroundStyle(AppStyle.secondaryText)

                HStack(spacing: 10) {
                    Toggle(
                        "Enabled",
                        isOn: Binding(
                            get: { adapter.isEnabled },
                            set: { store.setAdapterEnabled($0, id: adapter.id) }
                        )
                    )
                    .labelsHidden()
                    .tint(stageColor)
                    .accessibilityLabel("\(adapter.brand) enabled")

                    Button {
                        store.discoverDevices(for: adapter.id)
                    } label: {
                        HStack(spacing: 8) {
                            if adapter.isScanning {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                            }
                            Text(adapter.isScanning ? "Scanning" : "Discover")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppStyle.text)
                        .padding(.horizontal, 13)
                        .frame(height: 40)
                    }
                    .buttonStyle(GlassButtonStyle(accent: stageColor))
                    .disabled(adapter.isScanning)

                    Spacer()
                }
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
            isActive: command.lastResult == "Sent"
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
                        Pill(result, color: AppStyle.mint)
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
                        modelIsBundled ? "READY" : "MISSING",
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
