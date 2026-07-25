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
    @State private var isOn: Bool
    @State private var brightness: Double
    @State private var fanSpeed: Double
    @State private var targetTemperature: Double
    @State private var selectedColor = "Amber"

    init(device: SmartDevice) {
        self.device = device
        _isOn = State(initialValue: device.isOn)
        _brightness = State(initialValue: device.brightness ?? 50)
        _fanSpeed = State(initialValue: 2)
        _targetTemperature = State(initialValue: device.temperature ?? 24)
    }

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

            Section("Controls") {
                DeviceControlPanel(
                    device: device,
                    isOn: $isOn,
                    brightness: $brightness,
                    fanSpeed: $fanSpeed,
                    targetTemperature: $targetTemperature,
                    selectedColor: $selectedColor
                )
            }

            Section("Implementation note") {
                Text(device.note)
            }
        }
        .navigationTitle(device.name)
    }
}


private struct DeviceControlPanel: View {
    let device: SmartDevice
    @Binding var isOn: Bool
    @Binding var brightness: Double
    @Binding var fanSpeed: Double
    @Binding var targetTemperature: Double
    @Binding var selectedColor: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if device.capabilities.contains(.power) {
                Toggle("Power", isOn: $isOn)
            }

            if device.capabilities.contains(.brightness) {
                VStack(alignment: .leading) {
                    LabeledContent("Brightness", value: "\(Int(brightness))%")
                    Slider(value: $brightness, in: 0...100)
                }
            }

            if device.capabilities.contains(.color) {
                Picker("Color", selection: $selectedColor) {
                    ForEach(["Amber", "Blue", "Green", "Rose", "White"], id: \.self) { color in
                        Text(color).tag(color)
                    }
                }
                .pickerStyle(.segmented)
            }

            if device.capabilities.contains(.fanSpeed) {
                VStack(alignment: .leading) {
                    LabeledContent("Fan speed", value: "\(Int(fanSpeed))")
                    Slider(value: $fanSpeed, in: 0...5, step: 1)
                }
            }

            if device.capabilities.contains(.coolingMode) {
                Stepper("Target \(Int(targetTemperature)) C", value: $targetTemperature, in: 16...30, step: 1)
            }

            if device.capabilities.contains(.cameraStream) {
                Label("Camera stream placeholder ready", systemImage: "video.badge.checkmark")
                    .foregroundStyle(.teal)
            }

            if device.capabilities.contains(.hubBridge) {
                Label("Bridge routing endpoint staged", systemImage: "point.3.connected.trianglepath.dotted")
                    .foregroundStyle(.teal)
            }
        }
        .padding(.vertical, 4)
    }
}
