import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HeroPanel()

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        MetricTile(title: "Online", value: "\(store.onlineDeviceCount)", detail: "devices linked", symbol: "antenna.radiowaves.left.and.right")
                        MetricTile(title: "Active", value: "\(store.activeDeviceCount)", detail: "running now", symbol: "bolt.fill")
                        MetricTile(title: "Rooms", value: "\(store.rooms.count)", detail: "mapped zones", symbol: "square.split.2x2")
                        MetricTile(title: "Signals", value: "\(store.signals.count)", detail: "listening", symbol: "waveform")
                    }

                    SectionHeader(title: "Priority devices", subtitle: "The first real device families")

                    VStack(spacing: 12) {
                        ForEach(store.devices.prefix(5)) { device in
                            DeviceRow(device: device)
                        }
                    }
                }
                .padding()
            }
            .background(AppStyle.background.ignoresSafeArea())
            .navigationTitle("Conductor")
        }
    }
}

private struct HeroPanel: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Local bridge ready", systemImage: "checkmark.seal.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)
                Spacer()
                Image(systemName: "cpu")
                    .foregroundStyle(.teal)
            }

            Text("One app to coordinate lights, sensors, hubs, cameras, air, media, IR and RF extensions.")
                .font(.title2.weight(.bold))
                .lineSpacing(2)

            HStack(spacing: 8) {
                Pill("HomeKit")
                Pill("Matter")
                Pill("Core ML")
                Pill("RF/IR")
            }
        }
        .padding(18)
        .background(AppStyle.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
