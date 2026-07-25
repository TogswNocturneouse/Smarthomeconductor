import Foundation

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var devices: [SmartDevice]
    @Published private(set) var signals: [SignalEvent]
    @Published private(set) var rules: [AutomationRule]
    @Published private(set) var frameworks: [FrameworkPlan]
    @Published private(set) var brandAdapters: [BrandAdapterPlan]
    @Published private(set) var bridgeCommands: [BridgeCommand]
    @Published private(set) var classifierSlots: [ClassifierSlot]
    @Published private(set) var preferences: AppPreferences
    @Published private(set) var activeScene: ScenePreset?

    private let defaults: UserDefaults
    private let storageKey = "conductor.user.home.v3"
    private let registry: AdapterRegistry

    init(
        defaults: UserDefaults = .standard,
        registry: AdapterRegistry = .live
    ) {
        self.defaults = defaults
        self.registry = registry

        if
            let data = defaults.data(forKey: storageKey),
            let state = try? JSONDecoder().decode(PersistedState.self, from: data)
        {
            devices = state.devices
            signals = state.signals
            rules = state.rules
            brandAdapters = state.brandAdapters
            bridgeCommands = state.bridgeCommands
            preferences = state.preferences
        } else {
            devices = SampleData.devices
            signals = SampleData.signals
            rules = SampleData.rules
            brandAdapters = SampleData.brandAdapters
            bridgeCommands = SampleData.bridgeCommands
            preferences = AppPreferences()
        }

        frameworks = SampleData.frameworks
        classifierSlots = SampleData.classifierSlots
    }

    var onlineDeviceCount: Int {
        devices.filter(\.isOnline).count
    }

    var activeDeviceCount: Int {
        devices.filter(\.isOn).count
    }

    var enabledRuleCount: Int {
        rules.filter(\.isEnabled).count
    }

    var rooms: [String] {
        Array(Set(devices.map(\.room))).sorted()
    }

    var environmentalSummary: EnvironmentalSummary {
        let sensors = devices.filter {
            $0.isOnline && (
                $0.temperature != nil ||
                $0.humidity != nil ||
                $0.lux != nil ||
                $0.airQualityIndex != nil
            )
        }

        return EnvironmentalSummary(
            temperature: average(sensors.compactMap(\.temperature)),
            humidity: average(sensors.compactMap(\.humidity)),
            illuminance: average(sensors.compactMap(\.lux)),
            airQualityIndex: average(sensors.compactMap(\.airQualityIndex).map(Double.init)).map(Int.init),
            onlineSensors: sensors.count,
            updatedAt: sensors.map(\.lastUpdated).max()
        )
    }

    func device(id: UUID) -> SmartDevice? {
        devices.first { $0.id == id }
    }

    func devices(in room: String) -> [SmartDevice] {
        devices.filter { $0.room == room }
    }

    func addDevice(_ device: SmartDevice) {
        guard !devices.contains(where: {
            $0.name.localizedCaseInsensitiveCompare(device.name) == .orderedSame &&
            $0.manufacturer.localizedCaseInsensitiveCompare(device.manufacturer) == .orderedSame
        }) else {
            return
        }
        devices.append(device)
        devices.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        persist()
    }

    func addDevice(
        name: String,
        room: String,
        kind: DeviceKind,
        manufacturer: String
    ) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedRoom = room.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedManufacturer = manufacturer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedManufacturer.isEmpty else { return }

        addDevice(
            SmartDevice(
                name: trimmedName,
                room: trimmedRoom.isEmpty ? "Unassigned" : trimmedRoom,
                kind: kind,
                manufacturer: trimmedManufacturer,
                protocols: [],
                capabilities: defaultCapabilities(for: kind),
                isOnline: false,
                isOn: false,
                brightness: [.dimmerLight, .colorLight].contains(kind) ? 0 : nil,
                colorName: kind == .colorLight ? "White" : nil,
                temperature: nil,
                humidity: nil,
                lux: nil,
                airQualityIndex: nil,
                note: "Manually added inventory record. Connect a compatible route to enable control.",
                fanSpeed: [.purifier, .airConditioner].contains(kind) ? 0 : nil,
                targetTemperature: kind == .airConditioner ? 24 : nil,
                mode: [.purifier, .airConditioner].contains(kind) ? "Auto" : nil
            )
        )
    }

    func deleteDevice(_ id: UUID) {
        devices.removeAll { $0.id == id }
        persist()
    }

    func setPower(_ isOn: Bool, for id: UUID) {
        updateDevice(id) {
            $0.isOn = isOn
            $0.lastUpdated = .now
        }
        activeScene = nil
    }

    func setBrightness(_ brightness: Double, for id: UUID) {
        updateDevice(id) {
            $0.brightness = brightness
            $0.isOn = brightness > 0
            $0.lastUpdated = .now
        }
        activeScene = nil
    }

    func setColor(_ color: String, for id: UUID) {
        updateDevice(id) {
            $0.colorName = color
            $0.isOn = true
            $0.lastUpdated = .now
        }
        activeScene = nil
    }

    func setFanSpeed(_ speed: Double, for id: UUID) {
        updateDevice(id) {
            $0.fanSpeed = speed
            $0.isOn = speed > 0
            $0.lastUpdated = .now
        }
        activeScene = nil
    }

    func setTargetTemperature(_ temperature: Double, for id: UUID) {
        updateDevice(id) {
            $0.targetTemperature = temperature
            $0.lastUpdated = .now
        }
        activeScene = nil
    }

    func setMode(_ mode: String, for id: UUID) {
        updateDevice(id) {
            $0.mode = mode
            $0.lastUpdated = .now
        }
        activeScene = nil
    }

    func performDeviceAction(_ action: String, for id: UUID) {
        guard let device = device(id: id), device.isOnline else { return }
        recordEvent(
            title: "\(device.name): \(action)",
            confidence: 1,
            source: device.manufacturer,
            action: "Command accepted",
            symbol: device.kind.symbol
        )
    }

    func runScene(_ scene: ScenePreset) {
        switch scene {
        case .arrive:
            mutateDevices { device in
                guard device.isOnline else { return }
                if [.normalLight, .dimmerLight, .colorLight].contains(device.kind) {
                    device.isOn = true
                    if device.brightness != nil {
                        device.brightness = 58
                    }
                }
                if device.kind == .purifier {
                    device.isOn = true
                    device.fanSpeed = 2
                }
            }
        case .focus:
            mutateDevices { device in
                guard device.isOnline else { return }
                if device.room == "Studio", device.capabilities.contains(.brightness) {
                    device.isOn = true
                    device.brightness = 72
                } else if device.kind == .smartTV {
                    device.isOn = false
                }
            }
        case .airCare:
            mutateDevices { device in
                guard device.isOnline else { return }
                if device.kind == .purifier {
                    device.isOn = true
                    device.fanSpeed = 4
                }
                if device.kind == .airConditioner {
                    device.isOn = true
                    device.mode = "Auto"
                    device.targetTemperature = 23
                }
            }
        case .allOff:
            mutateDevices { device in
                if device.capabilities.contains(.power) {
                    device.isOn = false
                }
            }
        }

        activeScene = scene
        recordEvent(
            title: "\(scene.rawValue) scene",
            confidence: 1,
            source: "Scene controller",
            action: scene.detail,
            symbol: scene.symbol
        )
        persist()
    }

    func toggleRule(_ id: UUID) {
        guard let index = rules.firstIndex(where: { $0.id == id }) else { return }
        rules[index].isEnabled.toggle()
        persist()
    }

    func addRule(title: String, condition: String, action: String) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCondition = condition.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAction = action.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !trimmedTitle.isEmpty,
            !trimmedCondition.isEmpty,
            !trimmedAction.isEmpty
        else {
            return
        }

        rules.insert(
            AutomationRule(
                title: trimmedTitle,
                condition: trimmedCondition,
                action: trimmedAction,
                isEnabled: true
            ),
            at: 0
        )
        persist()
    }

    func deleteRule(_ id: UUID) {
        rules.removeAll { $0.id == id }
        persist()
    }

    func runRule(_ id: UUID) {
        guard let index = rules.firstIndex(where: { $0.id == id }) else { return }
        rules[index].lastRun = .now
        let rule = rules[index]
        recordEvent(
            title: rule.title,
            confidence: 1,
            source: "Automation",
            action: rule.action,
            symbol: "point.3.connected.trianglepath.dotted"
        )
        persist()
    }

    func discoverDevices(for adapterID: UUID) {
        guard let index = brandAdapters.firstIndex(where: { $0.id == adapterID }) else { return }
        guard !brandAdapters[index].isScanning else { return }
        brandAdapters[index].isScanning = true
        let brand = brandAdapters[index].brand

        Task {
            let accessories = await registry.discover(brand: brand)
            guard let currentIndex = brandAdapters.firstIndex(where: { $0.id == adapterID }) else { return }
            brandAdapters[currentIndex].isScanning = false
            brandAdapters[currentIndex].discoveredDevices = accessories.count
            brandAdapters[currentIndex].lastSync = .now
            recordEvent(
                title: "\(brand) discovery",
                confidence: 1,
                source: "Adapter registry",
                action: accessories.isEmpty
                    ? "No authenticated endpoints found"
                    : "\(accessories.count) endpoints available",
                symbol: "antenna.radiowaves.left.and.right"
            )
            persist()
        }
    }

    func setAdapterEnabled(_ enabled: Bool, id: UUID) {
        guard let index = brandAdapters.firstIndex(where: { $0.id == id }) else { return }
        brandAdapters[index].isEnabled = enabled
        if enabled {
            brandAdapters[index].lastSync = .now
        }
        persist()
    }

    func executeBridgeCommand(_ id: UUID) {
        guard let index = bridgeCommands.firstIndex(where: { $0.id == id }) else { return }
        bridgeCommands[index].lastRun = .now
        bridgeCommands[index].lastResult = "Sent"
        let command = bridgeCommands[index]

        if let deviceIndex = devices.firstIndex(where: {
            command.target.localizedCaseInsensitiveContains($0.name) ||
            $0.name.localizedCaseInsensitiveContains(command.target)
        }) {
            devices[deviceIndex].isOn = true
            devices[deviceIndex].lastUpdated = .now
        }

        recordEvent(
            title: command.name,
            confidence: 1,
            source: "\(command.transport.rawValue) bridge",
            action: "Command sent to \(command.target)",
            symbol: command.transport == .infrared
                ? "sensor.tag.radiowaves.forward"
                : "dot.radiowaves.left.and.right"
        )
        persist()
    }

    func recordClassification(label: String, confidence: Double) {
        guard confidence >= 0.45 else { return }
        let duplicate = signals.first {
            $0.source == "Core ML sound classifier" &&
            $0.title == label &&
            Date().timeIntervalSince($0.timestamp) < 8
        }
        guard duplicate == nil else { return }

        recordEvent(
            title: label,
            confidence: confidence,
            source: "Core ML sound classifier",
            action: "Available to automation rules",
            symbol: "waveform"
        )
    }

    func acknowledgeSignal(_ id: UUID) {
        guard let index = signals.firstIndex(where: { $0.id == id }) else { return }
        signals[index].isAcknowledged = true
        persist()
    }

    func clearAcknowledgedSignals() {
        signals.removeAll(where: \.isAcknowledged)
        persist()
    }

    func updatePreferences(_ update: (inout AppPreferences) -> Void) {
        update(&preferences)
        persist()
    }

    func clearHome() {
        devices = []
        signals = []
        rules = []
        brandAdapters = SampleData.brandAdapters
        bridgeCommands = []
        preferences = AppPreferences()
        activeScene = nil
        persist()
    }

    func executeLocalAssistantCommand(_ text: String) -> String? {
        let command = text.lowercased()

        if command.contains("all off") || command.contains("turn everything off") {
            runScene(.allOff)
            return "Everything with a power endpoint is off."
        }
        if command.contains("focus") {
            runScene(.focus)
            return "Focus is active. Studio lighting is set to 72% and the TV is off."
        }
        if command.contains("air") && (
            command.contains("care") ||
            command.contains("clean") ||
            command.contains("quality")
        ) {
            runScene(.airCare)
            return "Air care is active. The purifier and climate controls are running."
        }
        if command.contains("arrive") || command.contains("home scene") {
            runScene(.arrive)
            return "Arrival scene is active."
        }
        if command.contains("status") || command.contains("attention") {
            let summary = environmentalSummary
            let offline = devices.filter { !$0.isOnline }.count
            return "\(summary.healthLabel). \(onlineDeviceCount) devices are online, \(offline) are offline, and \(enabledRuleCount) automations are enabled."
        }

        for device in devices {
            guard command.contains(device.name.lowercased()) else { continue }
            guard device.isOnline else {
                return "\(device.name) is in your inventory but is not connected. Open Devices, select it, and add a compatible local or account route."
            }
            if command.contains("turn on") || command.hasSuffix(" on") {
                setPower(true, for: device.id)
                return "\(device.name) is on."
            }
            if command.contains("turn off") || command.hasSuffix(" off") {
                setPower(false, for: device.id)
                return "\(device.name) is off."
            }
        }

        return nil
    }

    func connectionAdvice(for query: String) -> String? {
        let text = query.lowercased()
        if text.contains("discover") || text.contains("find device") || text.contains("scan") {
            return "Open Devices and tap Add. Wi-Fi discovery uses Bonjour on your local network, Bluetooth discovery scans nearby advertisements, and Apple Home import reads accessories you already authorized in Home."
        }
        if text.contains("tapo") || text.contains("tp-link") {
            return "Tapo lights, plugs, cameras, H100, and T310 can often be reached locally after setup in the Tapo app. Some firmware requires Third-Party Compatibility, and cameras need separate camera-account credentials for streams."
        }
        if text.contains("xiaomi") || text.contains("purifier 4") {
            return "Keep the Xiaomi Air Purifier 4 Compact provisioned in Xiaomi Home. Use Matter if the hardware exposes it; otherwise import through a user-owned Home Assistant bridge or a supported MiOT adapter."
        }
        if text.contains("electrolux") || text.contains("wellbeing") {
            return "Keep the Wellbeing A5 configured in the Electrolux app. Direct import needs an authorized vendor API; until that exists, use a Home Assistant bridge and keep the account credential outside this app."
        }
        if text.contains("midea") || text.contains("mdv") || text.contains("air conditioner") {
            return "Identify the MDV Wi-Fi module first. Use Matter if exposed, otherwise connect through a compatible Midea bridge. The planned IR extension remains a fallback for power, mode, fan, and target temperature."
        }
        if text.contains("samsung") || text.contains("smartthings") || text.contains("tv") {
            return "Samsung import should use SmartThings OAuth. It can provide authorized device lists, state, health, and commands; production linking needs a registered SmartThings API app and secure callback service."
        }
        if text.contains("matter") {
            return "Matter devices must be commissioned before control. Use the system Matter setup flow, then map exposed clusters such as On/Off, Level Control, color, temperature, and air quality."
        }
        if text.contains("homekit") || text.contains("apple home") {
            return "Apple Home is the fastest supported import route. Grant Home access, then Conductor can read the shared HomeKit database and add accessories with their existing rooms."
        }
        return nil
    }

    private func updateDevice(_ id: UUID, update: (inout SmartDevice) -> Void) {
        guard let index = devices.firstIndex(where: { $0.id == id }) else { return }
        update(&devices[index])
        persist()
    }

    private func mutateDevices(_ update: (inout SmartDevice) -> Void) {
        for index in devices.indices {
            update(&devices[index])
            devices[index].lastUpdated = .now
        }
    }

    private func recordEvent(
        title: String,
        confidence: Double,
        source: String,
        action: String,
        symbol: String
    ) {
        signals.insert(
            SignalEvent(
                title: title,
                confidence: confidence,
                source: source,
                action: action,
                symbol: symbol
            ),
            at: 0
        )
        signals = Array(signals.prefix(60))
        persist()
    }

    private func persist() {
        let state = PersistedState(
            devices: devices,
            signals: signals,
            rules: rules,
            brandAdapters: brandAdapters,
            bridgeCommands: bridgeCommands,
            preferences: preferences
        )
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private func defaultCapabilities(for kind: DeviceKind) -> [DeviceCapability] {
        switch kind {
        case .normalLight: [.power]
        case .smartPlug: [.power, .localNetwork]
        case .dimmerLight: [.power, .brightness]
        case .colorLight: [.power, .brightness, .color, .whiteTemperature]
        case .climateSensor: [.temperatureReading, .humidityReading]
        case .lightSensor: [.lightReading]
        case .smartHub: [.hubBridge, .localNetwork]
        case .smartTV: [.power, .mediaControl, .hubBridge]
        case .camera: [.cameraStream, .localNetwork]
        case .purifier: [.power, .fanSpeed, .airQuality]
        case .airConditioner: [.power, .fanSpeed, .coolingMode, .temperatureReading]
        }
    }
}

private struct PersistedState: Codable {
    var devices: [SmartDevice]
    var signals: [SignalEvent]
    var rules: [AutomationRule]
    var brandAdapters: [BrandAdapterPlan]
    var bridgeCommands: [BridgeCommand]
    var preferences: AppPreferences
}
