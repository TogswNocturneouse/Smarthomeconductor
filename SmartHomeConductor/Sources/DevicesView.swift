import SwiftUI

struct DevicesView: View {
    @EnvironmentObject private var store: AppStore
    @State private var selectedKind: DeviceKind?

    private var filteredDevices: [SmartDevice] {
        guard let selectedKind else { return store.devices }
        return store.devices.filter { $0.kind == selectedKind }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterChip(title: "All", isSelected: selectedKind == nil) {
                                selectedKind = nil
                            }

                            ForEach(DeviceKind.allCases) { kind in
                                FilterChip(title: kind.rawValue, isSelected: selectedKind == kind) {
                                    selectedKind = kind
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.horizontal, -16)

                    LazyVStack(spacing: 12) {
                        ForEach(filteredDevices) { device in
                            NavigationLink {
                                DeviceDetailView(device: device)
                            } label: {
                                DeviceCard(device: device)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding()
            }
            .background(AppStyle.background.ignoresSafeArea())
            .navigationTitle("Devices")
        }
    }
}

struct DeviceDetailView: View {
    let device: SmartDevice

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    DeviceIcon(kind: device.kind, isOnline: device.isOnline)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(device.name).font(.headline)
                        Text("\(device.room) - \(device.manufacturer)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }

            Section("Capabilities") {
                ForEach(device.capabilities) { capability in
                    Label(capability.rawValue, systemImage: "checkmark.circle")
                }
            }

            Section("Protocols") {
                ForEach(device.protocols) { item in
                    Label(item.rawValue, systemImage: "point.3.connected.trianglepath.dotted")
                }
            }

            Section("Readings") {
                if let brightness = device.brightness {
                    LabeledContent("Brightness", value: "\(Int(brightness))%")
                }
                if let colorName = device.colorName {
                    LabeledContent("Color", value: colorName)
                }
                if let temperature = device.temperature {
                    LabeledContent("Temperature", value: String(format: "%.1f C", temperature))
                }
                if let humidity = device.humidity {
                    LabeledContent("Humidity", value: "\(Int(humidity))%")
                }
                if let lux = device.lux {
                    LabeledContent("Light", value: "\(Int(lux)) lux")
                }
                if let airQualityIndex = device.airQualityIndex {
                    LabeledContent("AQI", value: "\(airQualityIndex)")
                }
            }

            Section("Implementation note") {
                Text(device.note)
            }
        }
        .navigationTitle(device.name)
    }
}
