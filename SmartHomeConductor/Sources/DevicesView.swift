import SwiftUI

struct DevicesView: View {
    @EnvironmentObject private var store: AppStore
    @State private var selectedKind: DeviceKind?
    @State private var selectedRoom: String?
    @State private var searchText = ""
    @State private var isAddPresented = false

    private let columns = [
        GridItem(.adaptive(minimum: 270), spacing: 11)
    ]

    private var filteredDevices: [SmartDevice] {
        store.devices
            .filter { store.preferences.showOfflineDevices || $0.isOnline }
            .filter { selectedKind == nil || $0.kind == selectedKind }
            .filter { selectedRoom == nil || $0.room == selectedRoom }
            .filter {
                searchText.isEmpty ||
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.manufacturer.localizedCaseInsensitiveContains(searchText) ||
                $0.room.localizedCaseInsensitiveContains(searchText)
            }
            .sorted {
                if $0.isOnline != $1.isOnline {
                    return $0.isOnline && !$1.isOnline
                }
                return $0.name < $1.name
            }
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 17) {
                    HStack(alignment: .center, spacing: 12) {
                        SectionHeader(
                            title: "Your devices",
                            subtitle: "\(store.devices.count) inventory records"
                        )

                        Button {
                            isAddPresented = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 15, weight: .bold))
                                .frame(width: 42, height: 42)
                        }
                        .buttonStyle(GlassButtonStyle(accent: AppStyle.moon))
                        .accessibilityLabel("Add device")
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterChip(title: "All", isSelected: selectedKind == nil) {
                                selectedKind = nil
                            }

                            ForEach(DeviceKind.allCases) { kind in
                                FilterChip(
                                    title: kind.rawValue,
                                    isSelected: selectedKind == kind
                                ) {
                                    selectedKind = kind
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }

                    if let selectedRoom {
                        HStack(spacing: 8) {
                            Pill(selectedRoom, color: AppStyle.cyan)
                            Button {
                                self.selectedRoom = nil
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(AppStyle.secondaryText)
                                    .frame(width: 26, height: 26)
                            }
                            .buttonStyle(
                                GlassButtonStyle(
                                    accent: AppStyle.cyan,
                                    cornerRadius: 7
                                )
                            )
                            .accessibilityLabel("Clear room filter")
                        }
                    }

                    if store.devices.isEmpty {
                        EmptyStateView(
                            title: "Your home is empty",
                            detail: "Add a device manually, import Apple Home, or scan nearby Bluetooth and Wi-Fi services.",
                            symbol: "plus.circle"
                        )
                    } else if filteredDevices.isEmpty {
                        EmptyStateView(
                            title: "No matching devices",
                            detail: "Change the filters or search term.",
                            symbol: "magnifyingglass"
                        )
                    } else {
                        LazyVGrid(columns: columns, spacing: 11) {
                            ForEach(filteredDevices) { device in
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
                    }
                }
                .padding(16)
            }
            .background(Color.clear)
            .navigationTitle("Devices")
            .searchable(text: $searchText, prompt: "Device, room, or brand")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("All rooms") {
                            selectedRoom = nil
                        }
                        ForEach(store.rooms, id: \.self) { room in
                            Button(room) {
                                selectedRoom = room
                            }
                        }
                    } label: {
                        Image(systemName: selectedRoom == nil ? "line.3.horizontal.decrease" : "line.3.horizontal.decrease.circle.fill")
                    }
                    .accessibilityLabel("Filter by room")
                }
            }
            .sheet(isPresented: $isAddPresented) {
                AddDeviceView()
            }
        }
    }
}

private struct AddDeviceView: View {
    private enum Mode: String, CaseIterable, Identifiable {
        case manual = "Manual"
        case discover = "Discover"

        var id: String { rawValue }
    }

    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var discovery: LocalDiscoveryController
    @State private var mode: Mode = .manual
    @State private var name = ""
    @State private var manufacturer = ""
    @State private var room = ""
    @State private var kind: DeviceKind = .normalLight
    @State private var addedCandidateIDs: Set<String> = []

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 18) {
                    Picker("Add method", selection: $mode) {
                        ForEach(Mode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    if mode == .manual {
                        manualForm
                    } else {
                        discoveryForm
                    }
                }
                .padding(18)
            }
            .background(AppBackground())
            .navigationTitle("Add Device")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        discovery.stop()
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var manualForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(
                title: "Inventory record",
                subtitle: "Add what you own now; connect a route when it becomes available."
            )

            GlassPanel(accent: AppStyle.moon) {
                VStack(spacing: 14) {
                    TextField("Device name", text: $name)
                        .textFieldStyle(.roundedBorder)
                    TextField("Manufacturer", text: $manufacturer)
                        .textFieldStyle(.roundedBorder)
                    TextField("Room (optional)", text: $room)
                        .textFieldStyle(.roundedBorder)

                    Picker("Device type", selection: $kind) {
                        ForEach(DeviceKind.allCases) { kind in
                            Label(kind.rawValue, systemImage: kind.symbol).tag(kind)
                        }
                    }

                    Button {
                        store.addDevice(
                            name: name,
                            room: room,
                            kind: kind,
                            manufacturer: manufacturer
                        )
                        dismiss()
                    } label: {
                        Label("Add to home", systemImage: "plus")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                    .buttonStyle(GlassButtonStyle(accent: AppStyle.moon))
                    .disabled(
                        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        manufacturer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                }
            }
        }
    }

    private var discoveryForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(
                title: "Nearby and authorized",
                subtitle: "Discovery identifies candidates. Pairing or account authorization may still be required."
            )

            HStack(spacing: 10) {
                Button {
                    discovery.scanNearby()
                } label: {
                    Label(
                        discovery.isScanning ? "Scanning" : "Scan nearby",
                        systemImage: discovery.isScanning
                            ? "antenna.radiowaves.left.and.right"
                            : "dot.radiowaves.left.and.right"
                    )
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                }
                .buttonStyle(
                    GlassButtonStyle(
                        accent: AppStyle.moon,
                        isActive: discovery.isScanning
                    )
                )

                Button {
                    discovery.importAppleHome()
                } label: {
                    Label("Apple Home", systemImage: "house")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(GlassButtonStyle(accent: AppStyle.silver))
            }

            HStack(spacing: 8) {
                if discovery.isScanning {
                    ProgressView()
                        .controlSize(.small)
                }
                Text(discovery.status)
                    .font(.caption)
                    .foregroundStyle(AppStyle.secondaryText)
            }

            if discovery.candidates.isEmpty {
                EmptyStateView(
                    title: "No candidates yet",
                    detail: "Start a nearby scan or import accessories already configured in Apple Home.",
                    symbol: "sensor.tag.radiowaves.forward"
                )
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(discovery.candidates) { candidate in
                        candidateRow(candidate)
                    }
                }
            }
        }
    }

    private func candidateRow(_ candidate: DiscoveryCandidate) -> some View {
        let isAdded = addedCandidateIDs.contains(candidate.id)
        return GlassPanel(
            accent: candidate.source == .appleHome ? AppStyle.silver : AppStyle.moon,
            isActive: candidate.isReachable
        ) {
            HStack(spacing: 12) {
                Image(systemName: candidate.source.symbol)
                    .foregroundStyle(AppStyle.moon)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 3) {
                    Text(candidate.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppStyle.text)
                    Text("\(candidate.source.rawValue) - \(candidate.detail)")
                        .font(.caption)
                        .foregroundStyle(AppStyle.secondaryText)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Button {
                    store.addDevice(candidate.makeDevice())
                    addedCandidateIDs.insert(candidate.id)
                } label: {
                    Image(systemName: isAdded ? "checkmark" : "plus")
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(
                    GlassButtonStyle(
                        accent: isAdded ? AppStyle.mint : AppStyle.moon,
                        isActive: isAdded
                    )
                )
                .disabled(isAdded)
                .accessibilityLabel(isAdded ? "Added" : "Add \(candidate.name)")
            }
        }
    }
}

struct DeviceDetailView: View {
    let deviceID: UUID
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation = false

    private var device: SmartDevice? {
        store.device(id: deviceID)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            if let device {
                VStack(alignment: .leading, spacing: 18) {
                    DeviceIdentityPanel(device: device)

                    if hasControls(device) {
                        SectionHeader(
                            title: "Controls",
                            subtitle: device.isOnline ? "Commands are available" : "Endpoint is offline"
                        )
                        DeviceControlPanel(device: device)
                            .disabled(!device.isOnline)
                            .opacity(device.isOnline ? 1 : 0.48)
                    }

                    if hasReadings(device) {
                        SectionHeader(
                            title: "Readings",
                            subtitle: "Latest values from this endpoint"
                        )
                        DeviceReadingsPanel(device: device)
                    }

                    SectionHeader(
                        title: "Connection",
                        subtitle: "Available routes and capabilities"
                    )
                    DeviceConnectionPanel(device: device)
                }
                .padding(16)
            } else {
                EmptyStateView(
                    title: "Device unavailable",
                    detail: "This endpoint is no longer in the active home.",
                    symbol: "exclamationmark.triangle"
                )
                .padding(16)
            }
        }
        .background(Color.clear)
        .navigationTitle(device?.name ?? "Device")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("Delete device")
            }
        }
        .alert("Delete this device?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                store.deleteDevice(deviceID)
                dismiss()
            }
        } message: {
            Text("This removes the inventory record and its stored state from Conductor.")
        }
    }

    private func hasControls(_ device: SmartDevice) -> Bool {
        !Set(device.capabilities).isDisjoint(
            with: [
                .power,
                .brightness,
                .color,
                .fanSpeed,
                .coolingMode,
                .mediaControl,
                .cameraStream,
                .hubBridge
            ]
        )
    }

    private func hasReadings(_ device: SmartDevice) -> Bool {
        device.brightness != nil ||
        device.colorName != nil ||
        device.temperature != nil ||
        device.humidity != nil ||
        device.lux != nil ||
        device.airQualityIndex != nil ||
        device.batteryLevel != nil
    }
}

private struct DeviceIdentityPanel: View {
    let device: SmartDevice

    var body: some View {
        GlassPanel(
            accent: AppStyle.accent(for: device.kind),
            isActive: device.isOn
        ) {
            HStack(spacing: 14) {
                DeviceIcon(kind: device.kind, isOnline: device.isOnline)
                VStack(alignment: .leading, spacing: 4) {
                    Text(device.name)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppStyle.text)
                    Text("\(device.room) - \(device.manufacturer)")
                        .font(.subheadline)
                        .foregroundStyle(AppStyle.secondaryText)
                    Text(device.isOnline ? "Online" : "Offline")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(device.isOnline ? AppStyle.mint : AppStyle.coral)
                }
                Spacer()
            }
        }
    }
}

private struct DeviceControlPanel: View {
    let device: SmartDevice
    @EnvironmentObject private var store: AppStore

    private let colors = ["Amber", "Blue", "Green", "Rose", "Violet", "White"]

    var body: some View {
        GlassPanel(
            accent: AppStyle.accent(for: device.kind),
            isActive: device.isOn
        ) {
            VStack(alignment: .leading, spacing: 19) {
                if device.capabilities.contains(.power) {
                    Toggle(
                        "Power",
                        isOn: Binding(
                            get: { device.isOn },
                            set: { store.setPower($0, for: device.id) }
                        )
                    )
                    .font(.headline)
                    .foregroundStyle(AppStyle.text)
                    .tint(AppStyle.accent(for: device.kind))
                }

                if device.capabilities.contains(.brightness) {
                    ValueSlider(
                        title: "Brightness",
                        value: "\(Int(device.brightness ?? 0))%",
                        symbol: "sun.max",
                        accent: AppStyle.amber,
                        binding: Binding(
                            get: { device.brightness ?? 0 },
                            set: { store.setBrightness($0, for: device.id) }
                        ),
                        range: 0...100,
                        step: 1
                    )
                }

                if device.capabilities.contains(.color) {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Color", systemImage: "paintpalette")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppStyle.text)

                        HStack(spacing: 13) {
                            ForEach(colors, id: \.self) { colorName in
                                Button {
                                    store.setColor(colorName, for: device.id)
                                } label: {
                                    Circle()
                                        .fill(AppStyle.color(named: colorName))
                                        .frame(width: 27, height: 27)
                                        .overlay {
                                            Circle()
                                                .stroke(
                                                    device.colorName == colorName
                                                        ? Color.white
                                                        : Color.white.opacity(0.15),
                                                    lineWidth: device.colorName == colorName ? 2 : 0.7
                                                )
                                        }
                                        .shadow(
                                            color: AppStyle.color(named: colorName)
                                                .opacity(device.colorName == colorName ? 0.45 : 0),
                                            radius: 6
                                        )
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(colorName)
                                .accessibilityAddTraits(
                                    device.colorName == colorName ? .isSelected : []
                                )
                            }
                        }
                    }
                }

                if device.capabilities.contains(.fanSpeed) {
                    ValueSlider(
                        title: "Fan speed",
                        value: "\(Int(device.fanSpeed ?? 0))",
                        symbol: "fan",
                        accent: AppStyle.mint,
                        binding: Binding(
                            get: { device.fanSpeed ?? 0 },
                            set: { store.setFanSpeed($0, for: device.id) }
                        ),
                        range: 0...5,
                        step: 1
                    )
                }

                if device.capabilities.contains(.coolingMode) {
                    VStack(alignment: .leading, spacing: 11) {
                        Picker(
                            "Mode",
                            selection: Binding(
                                get: { device.mode ?? "Auto" },
                                set: { store.setMode($0, for: device.id) }
                            )
                        ) {
                            ForEach(["Auto", "Cool", "Dry", "Fan"], id: \.self) {
                                Text($0).tag($0)
                            }
                        }
                        .pickerStyle(.segmented)

                        Stepper(
                            value: Binding(
                                get: { device.targetTemperature ?? device.temperature ?? 24 },
                                set: { store.setTargetTemperature($0, for: device.id) }
                            ),
                            in: 16...30,
                            step: 1
                        ) {
                            LabeledContent(
                                "Target temperature",
                                value: "\(Int(device.targetTemperature ?? device.temperature ?? 24)) C"
                            )
                            .foregroundStyle(AppStyle.text)
                        }
                    }
                }

                if device.capabilities.contains(.mediaControl) {
                    DeviceActionRow(
                        actions: [
                            ("backward.fill", "Previous"),
                            ("playpause.fill", "Play or pause"),
                            ("forward.fill", "Next"),
                            ("speaker.wave.2.fill", "Volume")
                        ],
                        accent: AppStyle.violet
                    ) { action in
                        store.performDeviceAction(action, for: device.id)
                    }
                }

                if device.capabilities.contains(.cameraStream) {
                    CameraEndpointPanel(device: device)
                }

                if device.capabilities.contains(.hubBridge) {
                    Button {
                        store.performDeviceAction("Refresh routes", for: device.id)
                    } label: {
                        Label("Refresh bridge routes", systemImage: "arrow.triangle.2.circlepath")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppStyle.text)
                            .padding(.horizontal, 13)
                            .frame(height: 42)
                    }
                    .buttonStyle(GlassButtonStyle(accent: AppStyle.violet))
                }

                if let message = store.lastCommandMessage {
                    Label(message, systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(AppStyle.secondaryText)
                }
            }
        }
    }
}

private struct ValueSlider: View {
    let title: String
    let value: String
    let symbol: String
    let accent: Color
    let binding: Binding<Double>
    let range: ClosedRange<Double>
    let step: Double
    @State private var draftValue: Double
    @State private var isEditing = false

    init(
        title: String,
        value: String,
        symbol: String,
        accent: Color,
        binding: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double
    ) {
        self.title = title
        self.value = value
        self.symbol = symbol
        self.accent = accent
        self.binding = binding
        self.range = range
        self.step = step
        _draftValue = State(initialValue: binding.wrappedValue)
    }

    private var displayedValue: String {
        guard isEditing else { return value }
        return title == "Brightness"
            ? "\(Int(draftValue.rounded()))%"
            : "\(Int(draftValue.rounded()))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(title, systemImage: symbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppStyle.text)
                Spacer()
                Text(displayedValue)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(accent)
                    .monospacedDigit()
            }
            Slider(
                value: $draftValue,
                in: range,
                step: step,
                onEditingChanged: { editing in
                    isEditing = editing
                    if !editing {
                        binding.wrappedValue = draftValue
                    }
                }
            )
                .tint(accent)
                .onChange(of: binding.wrappedValue) { _, newValue in
                    if !isEditing {
                        draftValue = newValue
                    }
                }
        }
    }
}

private struct DeviceActionRow: View {
    let actions: [(symbol: String, name: String)]
    let accent: Color
    let handler: (String) -> Void

    var body: some View {
        HStack(spacing: 10) {
            ForEach(actions, id: \.name) { action in
                Button {
                    handler(action.name)
                } label: {
                    Image(systemName: action.symbol)
                        .foregroundStyle(accent)
                        .frame(width: 42, height: 42)
                }
                .buttonStyle(GlassButtonStyle(accent: accent))
                .accessibilityLabel(action.name)
            }
        }
    }
}

private struct CameraEndpointPanel: View {
    let device: SmartDevice
    @EnvironmentObject private var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            ZStack {
                Rectangle()
                    .fill(Color.black.opacity(0.60))
                VStack(spacing: 8) {
                    Image(systemName: "video.fill")
                        .font(.title2)
                        .foregroundStyle(AppStyle.coral)
                    Text(device.isOnline ? "Camera metadata connected" : "Camera offline")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppStyle.secondaryText)
                    Text("A live stream is shown only after a stream transport is authenticated.")
                        .font(.caption2)
                        .foregroundStyle(AppStyle.secondaryText)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(height: 148)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(alignment: .topLeading) {
                HStack(spacing: 6) {
                    StatusDot(color: device.isOnline ? AppStyle.coral : AppStyle.secondaryText)
                    Text(device.isOnline ? "CONNECTED" : "OFFLINE")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(AppStyle.text)
                }
                .padding(10)
            }

            DeviceActionRow(
                actions: [
                    ("camera.fill", "Capture snapshot"),
                    ("speaker.slash.fill", "Mute"),
                    ("arrow.up.left.and.arrow.down.right", "Full screen")
                ],
                accent: AppStyle.coral
            ) { action in
                store.performDeviceAction(action, for: device.id)
            }
        }
    }
}

private struct DeviceReadingsPanel: View {
    let device: SmartDevice

    private let columns = [
        GridItem(.adaptive(minimum: 120), spacing: 9)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 9) {
            if let brightness = device.brightness {
                ReadingCell(
                    title: "Brightness",
                    value: "\(Int(brightness))%",
                    symbol: "sun.max",
                    accent: AppStyle.amber
                )
            }
            if let colorName = device.colorName {
                ReadingCell(
                    title: "Color",
                    value: colorName,
                    symbol: "paintpalette",
                    accent: AppStyle.color(named: colorName)
                )
            }
            if let temperature = device.temperature {
                ReadingCell(
                    title: "Temperature",
                    value: String(format: "%.1f C", temperature),
                    symbol: "thermometer.medium",
                    accent: AppStyle.cyan
                )
            }
            if let humidity = device.humidity {
                ReadingCell(
                    title: "Humidity",
                    value: "\(Int(humidity))%",
                    symbol: "humidity",
                    accent: AppStyle.violet
                )
            }
            if let lux = device.lux {
                ReadingCell(
                    title: "Light",
                    value: "\(Int(lux)) lx",
                    symbol: "sun.max",
                    accent: AppStyle.amber
                )
            }
            if let airQualityIndex = device.airQualityIndex {
                ReadingCell(
                    title: "Air",
                    value: "AQI \(airQualityIndex)",
                    symbol: "wind",
                    accent: AppStyle.mint
                )
            }
            if let batteryLevel = device.batteryLevel {
                ReadingCell(
                    title: "Battery",
                    value: "\(batteryLevel)%",
                    symbol: "battery.75percent",
                    accent: AppStyle.mint
                )
            }
            if let fanSpeed = device.fanSpeed {
                ReadingCell(
                    title: "Fan speed",
                    value: "\(Int(fanSpeed))",
                    symbol: "fan",
                    accent: AppStyle.mint
                )
            }
            if let targetTemperature = device.targetTemperature {
                ReadingCell(
                    title: "Target",
                    value: "\(Int(targetTemperature)) C",
                    symbol: "thermometer.variable",
                    accent: AppStyle.cyan
                )
            }
        }
    }
}

private struct ReadingCell: View {
    let title: String
    let value: String
    let symbol: String
    let accent: Color

    var body: some View {
        GlassPanel(accent: accent, padding: 13) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: symbol)
                    .foregroundStyle(accent)
                Text(value)
                    .font(.headline)
                    .foregroundStyle(AppStyle.text)
                    .monospacedDigit()
                Text(title)
                    .font(.caption)
                    .foregroundStyle(AppStyle.secondaryText)
            }
        }
    }
}

private struct DeviceConnectionPanel: View {
    let device: SmartDevice
    @EnvironmentObject private var navigation: AppNavigation

    var body: some View {
        GlassPanel(accent: AppStyle.violet) {
            VStack(alignment: .leading, spacing: 14) {
                TagGrid(
                    items: device.protocols.map(\.rawValue),
                    color: AppStyle.violet
                )

                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 0.7)

                TagGrid(
                    items: device.capabilities.map(\.rawValue),
                    color: AppStyle.cyan
                )

                if let externalID = device.externalID {
                    LabeledContent("Endpoint", value: externalID)
                        .font(.caption)
                        .foregroundStyle(AppStyle.secondaryText)
                        .textSelection(.enabled)
                }

                if device.manufacturer.localizedCaseInsensitiveContains("Tapo") {
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 0.7)

                    Button {
                        navigation.selection = .integrations
                    } label: {
                        Label("Open Tapo connection routes", systemImage: "link")
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                    }
                    .buttonStyle(GlassButtonStyle(accent: AppStyle.mint))

                    Link(
                        destination: URL(string: "https://www.tapo.com/en/faq/714/")!
                    ) {
                        Label("Official Tapo compatibility details", systemImage: "arrow.up.right.square")
                    }
                    .font(.caption.weight(.semibold))
                }
            }
        }
    }
}
