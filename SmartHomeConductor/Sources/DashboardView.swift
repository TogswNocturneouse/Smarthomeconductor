import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: AppStore

    private let metricColumns = [
        GridItem(.adaptive(minimum: 145), spacing: 10)
    ]

    private let deviceColumns = [
        GridItem(.adaptive(minimum: 260), spacing: 11)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    SystemStatusBand()

                    SectionHeader(
                        title: "Scenes",
                        subtitle: "Run a coordinated state across your home"
                    )

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(ScenePreset.allCases) { scene in
                                SceneButton(
                                    scene: scene,
                                    isActive: store.activeScene == scene
                                ) {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        store.runScene(scene)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }

                    LazyVGrid(columns: metricColumns, spacing: 10) {
                        MetricTile(
                            title: "ONLINE",
                            value: "\(store.onlineDeviceCount)",
                            detail: "of \(store.devices.count) endpoints",
                            symbol: "antenna.radiowaves.left.and.right",
                            accent: AppStyle.mint
                        )
                        MetricTile(
                            title: "ACTIVE",
                            value: "\(store.activeDeviceCount)",
                            detail: "devices running",
                            symbol: "bolt.fill",
                            accent: AppStyle.amber
                        )
                        MetricTile(
                            title: "AUTOMATIONS",
                            value: "\(store.enabledRuleCount)",
                            detail: "rules enabled",
                            symbol: "point.3.connected.trianglepath.dotted",
                            accent: AppStyle.cyan
                        )
                        MetricTile(
                            title: "EVENTS",
                            value: "\(store.signals.filter { !$0.isAcknowledged }.count)",
                            detail: "need review",
                            symbol: "waveform.path.ecg",
                            accent: AppStyle.coral
                        )
                    }

                    SectionHeader(
                        title: "Priority devices",
                        subtitle: "Live state and direct controls"
                    )

                    LazyVGrid(columns: deviceColumns, spacing: 11) {
                        ForEach(store.devices.prefix(6)) { device in
                            NavigationLink {
                                DeviceDetailView(deviceID: device.id)
                            } label: {
                                DeviceCard(device: device)
                            }
                            .buttonStyle(
                                GlassButtonStyle(
                                    accent: AppStyle.accent(for: device.kind),
                                    isActive: device.isOn
                                )
                            )
                        }
                    }

                    SectionHeader(
                        title: "Rooms",
                        subtitle: "Endpoint health by zone"
                    )

                    LazyVGrid(columns: deviceColumns, spacing: 10) {
                        ForEach(store.rooms, id: \.self) { room in
                            RoomSummaryRow(
                                room: room,
                                devices: store.devices(in: room)
                            )
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 8)
            }
            .background(Color.clear)
            .navigationTitle("Home")
        }
    }
}

private struct SystemStatusBand: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var classifier: SoundClassifierController

    var body: some View {
        GlassPanel(
            accent: classifier.state.isListening ? AppStyle.coral : AppStyle.mint,
            isActive: true,
            padding: 16
        ) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(AppStyle.mint.opacity(0.11))
                    Image(systemName: "wave.3.right.circle.fill")
                        .font(.title2)
                        .foregroundStyle(AppStyle.mint)
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Conductor is online")
                        .font(.headline)
                        .foregroundStyle(AppStyle.text)
                    Text(
                        store.activeScene.map { "\($0.rawValue) scene active" }
                            ?? "\(store.enabledRuleCount) automations watching"
                    )
                    .font(.subheadline)
                    .foregroundStyle(AppStyle.secondaryText)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 5) {
                    Label("LOCAL", systemImage: "lock.shield.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppStyle.mint)
                    Text(classifier.state.title)
                        .font(.caption2)
                        .foregroundStyle(AppStyle.secondaryText)
                        .lineLimit(1)
                }
            }
        }
    }
}

private struct SceneButton: View {
    let scene: ScenePreset
    let isActive: Bool
    let action: () -> Void

    private var accent: Color {
        switch scene {
        case .arrive: AppStyle.mint
        case .focus: AppStyle.violet
        case .airCare: AppStyle.cyan
        case .allOff: AppStyle.coral
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: scene.symbol)
                    .font(.title3)
                    .foregroundStyle(accent)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(scene.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppStyle.text)
                    Text(scene.detail)
                        .font(.caption)
                        .foregroundStyle(AppStyle.secondaryText)
                }
            }
            .padding(.horizontal, 14)
            .frame(width: 176, height: 62, alignment: .leading)
        }
        .buttonStyle(GlassButtonStyle(accent: accent, isActive: isActive))
    }
}

private struct RoomSummaryRow: View {
    let room: String
    let devices: [SmartDevice]

    private var onlineCount: Int {
        devices.filter(\.isOnline).count
    }

    private var activeCount: Int {
        devices.filter(\.isOn).count
    }

    var body: some View {
        GlassPanel(
            accent: onlineCount == devices.count ? AppStyle.mint : AppStyle.amber,
            padding: 14
        ) {
            HStack(spacing: 12) {
                Image(systemName: "square.split.2x2")
                    .foregroundStyle(AppStyle.cyan)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 3) {
                    Text(room)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppStyle.text)
                    Text("\(onlineCount)/\(devices.count) online")
                        .font(.caption)
                        .foregroundStyle(AppStyle.secondaryText)
                }

                Spacer()

                Text("\(activeCount) active")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(activeCount > 0 ? AppStyle.amber : AppStyle.secondaryText)
            }
        }
    }
}
