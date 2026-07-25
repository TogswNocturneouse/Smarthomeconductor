import Foundation
import SwiftData

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
    @Published private(set) var commandAudits: [CommandAuditRecord]
    @Published private(set) var persistenceIssue: String?
    @Published private(set) var lastCommandMessage: String?

    let persistenceMode: PersistenceMode
    let homeAssistant: HomeAssistantController

    private let defaults: UserDefaults
    private let storageKey = "conductor.user.home.v3"
    private let registry: AdapterRegistry
    private let homePersistence: HomePersistenceStore?
    private let commandPolicy = CommandAuthorizationPolicy()

    init(
        defaults: UserDefaults = .standard,
        registry: AdapterRegistry = .live,
        modelContainer: ModelContainer? = nil,
        persistenceMode: PersistenceMode = .legacyUserDefaults,
        homeAssistant: HomeAssistantController = HomeAssistantController()
    ) {
        self.defaults = defaults
        self.registry = registry
        self.persistenceMode = persistenceMode
        self.homeAssistant = homeAssistant
        let persistence = modelContainer.map(HomePersistenceStore.init(container:))
        homePersistence = persistence

        var loadedSnapshot: HomePersistenceSnapshot?
        var loadIssue: String?
        if let persistence {
            do {
                loadedSnapshot = try persistence.load()
            } catch {
                loadIssue = "SwiftData load failed: \(error.localizedDescription)"
            }
        }

        let legacyState: PersistedState? = if
            let data = defaults.data(forKey: storageKey),
            let state = try? JSONDecoder().decode(PersistedState.self, from: data)
        {
            state
        } else {
            nil
        }

        if let snapshot = loadedSnapshot {
            devices = snapshot.devices
            signals = snapshot.signals
            rules = snapshot.rules
            brandAdapters = snapshot.brandAdapters
            bridgeCommands = snapshot.bridgeCommands
            preferences = snapshot.preferences
            commandAudits = snapshot.commandAudits
        } else if let state = legacyState {
            devices = state.devices
            signals = state.signals
            rules = state.rules
            brandAdapters = state.brandAdapters
            bridgeCommands = state.bridgeCommands
            preferences = state.preferences
            commandAudits = state.commandAudits ?? []
        } else {
            devices = SampleData.devices
            signals = SampleData.signals
            rules = SampleData.rules
            brandAdapters = SampleData.brandAdapters
            bridgeCommands = SampleData.bridgeCommands
            preferences = AppPreferences()
            commandAudits = []
        }

        frameworks = SampleData.frameworks
        classifierSlots = SampleData.classifierSlots
        activeScene = nil
        persistenceIssue = loadIssue
        lastCommandMessage = nil

        let knownBrands = Set(brandAdapters.map(\.brand))
        let missingAdapters = SampleData.brandAdapters.filter {
            !knownBrands.contains($0.brand)
        }
        brandAdapters.append(contentsOf: missingAdapters)
        var refreshedConnectionCopy = false
        for sample in SampleData.brandAdapters where
            sample.brand == "TP-Link / Tapo" || sample.brand == "Home Assistant"
        {
            guard let index = brandAdapters.firstIndex(where: { $0.brand == sample.brand }) else {
                continue
            }
            if brandAdapters[index].connectionPlan != sample.connectionPlan ||
                brandAdapters[index].nextAction != sample.nextAction
            {
                brandAdapters[index].connectionPlan = sample.connectionPlan
                brandAdapters[index].nextAction = sample.nextAction
                refreshedConnectionCopy = true
            }
        }

        if persistence != nil,
            loadedSnapshot == nil || !missingAdapters.isEmpty || refreshedConnectionCopy
        {
            persist()
        }

        for index in devices.indices where
            devices[index].integrationID == HomeAssistantController.integrationID
        {
            devices[index].isOnline = false
            devices[index].note = "Saved Home Assistant entity. Waiting for a live refresh."
        }
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

    func importHomeAssistantDevices(_ importedDevices: [SmartDevice]) {
        for imported in importedDevices {
            if let index = devices.firstIndex(where: {
                $0.integrationID == HomeAssistantController.integrationID &&
                $0.externalID == imported.externalID
            }) {
                var updated = imported
                updated.id = devices[index].id
                if updated.room == "Unassigned", devices[index].room != "Unassigned" {
                    updated.room = devices[index].room
                }
                devices[index] = updated
            } else {
                devices.append(imported)
            }
        }

        let importedIDs = Set(importedDevices.compactMap(\.externalID))
        for index in devices.indices where
            devices[index].integrationID == HomeAssistantController.integrationID &&
            !importedIDs.contains(devices[index].externalID ?? "")
        {
            devices[index].isOnline = false
            devices[index].note = "Home Assistant did not return this entity during the latest sync."
        }

        devices.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        updateAdapterAfterHomeAssistantImport(importedDevices)
        recordEvent(
            title: "Home Assistant sync",
            confidence: 1,
            source: "Authenticated local API",
            action: "\(importedDevices.count) supported entities synchronized",
            symbol: "homekit"
        )
        persist()
    }

    func refreshHomeAssistantIfConfigured() async {
        guard !homeAssistant.savedAddress.isEmpty else { return }
        do {
            let imported = try await homeAssistant.reconnectAndImport()
            importHomeAssistantDevices(imported)
        } catch {
            for index in devices.indices where
                devices[index].integrationID == HomeAssistantController.integrationID
            {
                devices[index].isOnline = false
                devices[index].note = "Home Assistant refresh failed: \(error.localizedDescription)"
            }
            lastCommandMessage = error.localizedDescription
            persist()
        }
    }

    func disconnectHomeAssistant() {
        homeAssistant.disconnect()
        for index in devices.indices where
            devices[index].integrationID == HomeAssistantController.integrationID
        {
            devices[index].isOnline = false
            devices[index].note = "Home Assistant is disconnected."
        }
        if let index = brandAdapters.firstIndex(where: { $0.brand == "Home Assistant" }) {
            brandAdapters[index].isEnabled = false
            brandAdapters[index].stage = .scaffolded
            brandAdapters[index].nextAction = "Connect the local URL and a long-lived access token."
        }
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

    @discardableResult
    func executeCommand(
        _ command: DeviceCommand,
        for id: UUID,
        origin: CommandOrigin = .userInterface,
        confirmed: Bool = false
    ) -> CommandExecutionResult {
        guard let device = device(id: id) else {
            return CommandExecutionResult(
                outcome: .rejected,
                message: "The target device no longer exists."
            )
        }

        let risk = commandPolicy.risk(for: command, device: device)
        guard device.isOnline else {
            let message = "\(device.name) is offline. No command was sent."
            recordCommandAudit(
                device: device,
                command: command.summary,
                origin: origin,
                risk: risk,
                outcome: .rejected,
                detail: message
            )
            return CommandExecutionResult(outcome: .rejected, message: message)
        }

        let decision = commandPolicy.evaluate(
            command: command,
            device: device,
            origin: origin,
            isConfirmed: confirmed,
            assistantLightControlAllowed: preferences.assistantLightControlAllowed
        )
        switch decision {
        case let .deny(reason):
            recordCommandAudit(
                device: device,
                command: command.summary,
                origin: origin,
                risk: risk,
                outcome: .rejected,
                detail: reason
            )
            return CommandExecutionResult(outcome: .rejected, message: reason)
        case let .requireConfirmation(reason):
            recordCommandAudit(
                device: device,
                command: command.summary,
                origin: origin,
                risk: risk,
                outcome: .confirmationRequired,
                detail: reason
            )
            return CommandExecutionResult(
                outcome: .confirmationRequired,
                message: reason
            )
        case .allow:
            break
        }

        updateDevice(id, persistAfterUpdate: false) {
            apply(command, to: &$0)
        }
        activeScene = nil

        let message = "\(command.summary) was recorded locally for \(device.name). The device adapter must confirm physical execution."
        recordCommandAudit(
            device: device,
            command: command.summary,
            origin: origin,
            risk: risk,
            outcome: .localStateUpdated,
            detail: message,
            persistAfterInsert: false
        )
        persist()
        return CommandExecutionResult(outcome: .localStateUpdated, message: message)
    }

    func setPower(_ isOn: Bool, for id: UUID) {
        routeCommand(.setPower(isOn), for: id)
    }

    func setBrightness(_ brightness: Double, for id: UUID) {
        routeCommand(.setBrightness(brightness), for: id)
    }

    func setColor(_ color: String, for id: UUID) {
        routeCommand(.setColor(color), for: id)
    }

    func setFanSpeed(_ speed: Double, for id: UUID) {
        routeCommand(.setFanSpeed(speed), for: id)
    }

    func setTargetTemperature(_ temperature: Double, for id: UUID) {
        routeCommand(.setTargetTemperature(temperature), for: id)
    }

    func setMode(_ mode: String, for id: UUID) {
        routeCommand(.setMode(mode), for: id)
    }

    private func routeCommand(
        _ command: DeviceCommand,
        for id: UUID,
        origin: CommandOrigin = .userInterface,
        confirmed: Bool = false
    ) {
        guard let device = device(id: id) else { return }
        if device.integrationID == HomeAssistantController.integrationID {
            Task {
                await executeHomeAssistantCommand(
                    command,
                    for: id,
                    origin: origin,
                    confirmed: confirmed
                )
            }
        } else {
            lastCommandMessage = executeCommand(
                command,
                for: id,
                origin: origin,
                confirmed: confirmed
            ).message
        }
    }

    @discardableResult
    func executeHomeAssistantCommand(
        _ command: DeviceCommand,
        for id: UUID,
        origin: CommandOrigin = .userInterface,
        confirmed: Bool = false
    ) async -> CommandExecutionResult {
        guard let device = device(id: id) else {
            return CommandExecutionResult(
                outcome: .rejected,
                message: "The target device no longer exists."
            )
        }
        let risk = commandPolicy.risk(for: command, device: device)
        guard device.isOnline else {
            let message = "\(device.name) is offline. No command was sent."
            recordCommandAudit(
                device: device,
                command: command.summary,
                origin: origin,
                risk: risk,
                outcome: .rejected,
                detail: message
            )
            lastCommandMessage = message
            return CommandExecutionResult(outcome: .rejected, message: message)
        }

        let decision = commandPolicy.evaluate(
            command: command,
            device: device,
            origin: origin,
            isConfirmed: confirmed,
            assistantLightControlAllowed: preferences.assistantLightControlAllowed
        )
        switch decision {
        case let .deny(reason):
            recordCommandAudit(
                device: device,
                command: command.summary,
                origin: origin,
                risk: risk,
                outcome: .rejected,
                detail: reason
            )
            lastCommandMessage = reason
            return CommandExecutionResult(outcome: .rejected, message: reason)
        case let .requireConfirmation(reason):
            recordCommandAudit(
                device: device,
                command: command.summary,
                origin: origin,
                risk: risk,
                outcome: .confirmationRequired,
                detail: reason
            )
            lastCommandMessage = reason
            return CommandExecutionResult(outcome: .confirmationRequired, message: reason)
        case .allow:
            break
        }

        do {
            let confirmedDevice = try await homeAssistant.execute(command, device: device)
            guard let index = devices.firstIndex(where: { $0.id == id }) else {
                throw HomeAssistantError.invalidResponse
            }
            devices[index] = confirmedDevice
            let message = "\(command.summary) confirmed by Home Assistant for \(device.name)."
            recordCommandAudit(
                device: confirmedDevice,
                command: command.summary,
                origin: origin,
                risk: risk,
                outcome: .deviceConfirmed,
                detail: message,
                persistAfterInsert: false
            )
            lastCommandMessage = message
            persist()
            return CommandExecutionResult(outcome: .deviceConfirmed, message: message)
        } catch {
            let message = "\(device.name): \(error.localizedDescription)"
            recordCommandAudit(
                device: device,
                command: command.summary,
                origin: origin,
                risk: risk,
                outcome: .transportUnavailable,
                detail: message
            )
            lastCommandMessage = message
            return CommandExecutionResult(outcome: .transportUnavailable, message: message)
        }
    }

    func performDeviceAction(_ action: String, for id: UUID) {
        guard let device = device(id: id), device.isOnline else { return }
        let detail = "Blocked because \(action) has no registered typed adapter command."
        recordCommandAudit(
            device: device,
            command: action,
            origin: .userInterface,
            risk: .elevated,
            outcome: .transportUnavailable,
            detail: detail
        )
        recordEvent(
            title: "\(device.name): \(action)",
            confidence: 1,
            source: device.manufacturer,
            action: detail,
            symbol: device.kind.symbol
        )
    }

    @discardableResult
    func runScene(
        _ scene: ScenePreset,
        origin: CommandOrigin = .userInterface,
        confirmed: Bool = false
    ) -> SceneExecutionReport {
        let planned = devices.compactMap { device -> (SmartDevice, DeviceCommand)? in
            guard device.isOnline, let command = sceneCommand(scene, device: device) else {
                return nil
            }
            return (device, command)
        }
        var allowedCommands: [UUID: DeviceCommand] = [:]

        for (device, command) in planned {
            let risk = commandPolicy.risk(for: command, device: device)
            let decision = commandPolicy.evaluate(
                command: command,
                device: device,
                origin: origin,
                isConfirmed: confirmed,
                assistantLightControlAllowed: preferences.assistantLightControlAllowed
            )
            switch decision {
            case .allow:
                allowedCommands[device.id] = command
            case let .deny(reason):
                recordCommandAudit(
                    device: device,
                    command: "Run \(scene.rawValue) scene: \(command.summary)",
                    origin: origin,
                    risk: risk,
                    outcome: .rejected,
                    detail: reason,
                    persistAfterInsert: false
                )
            case let .requireConfirmation(reason):
                recordCommandAudit(
                    device: device,
                    command: "Run \(scene.rawValue) scene: \(command.summary)",
                    origin: origin,
                    risk: risk,
                    outcome: .confirmationRequired,
                    detail: reason,
                    persistAfterInsert: false
                )
            }
        }

        mutateDevices { device in
            guard let command = allowedCommands[device.id] else { return }
            apply(command, to: &device)
        }

        let report = SceneExecutionReport(
            scene: scene,
            eligibleDevices: planned.count,
            updatedDevices: allowedCommands.count,
            blockedDevices: planned.count - allowedCommands.count
        )
        if !allowedCommands.isEmpty {
            activeScene = scene
            for id in allowedCommands.keys {
                guard let device = device(id: id) else { continue }
                recordCommandAudit(
                    device: device,
                    command: "Run \(scene.rawValue) scene",
                    origin: .userInterface,
                    risk: commandPolicy.risk(for: .setPower(device.isOn), device: device),
                    outcome: .localStateUpdated,
                    detail: report.message,
                    persistAfterInsert: false
                )
            }
        }
        recordEvent(
            title: "\(scene.rawValue) scene",
            confidence: 1,
            source: "Scene controller",
            action: report.message,
            symbol: scene.symbol
        )
        persist()
        return report
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

    private func updateAdapterAfterHomeAssistantImport(_ importedDevices: [SmartDevice]) {
        if let index = brandAdapters.firstIndex(where: { $0.brand == "Home Assistant" }) {
            brandAdapters[index].isEnabled = true
            brandAdapters[index].discoveredDevices = importedDevices.count
            brandAdapters[index].lastSync = .now
            brandAdapters[index].stage = .ready
            brandAdapters[index].nextAction = "Connected. Refresh to synchronize live entity state."
        }
        let tapoCount = importedDevices.filter {
            $0.manufacturer == "TP-Link / Tapo"
        }.count
        if let index = brandAdapters.firstIndex(where: { $0.brand == "TP-Link / Tapo" }) {
            brandAdapters[index].discoveredDevices = tapoCount
            brandAdapters[index].lastSync = .now
            if tapoCount > 0 {
                brandAdapters[index].isEnabled = true
                brandAdapters[index].stage = .ready
                brandAdapters[index].nextAction = "\(tapoCount) Tapo entities connected through Home Assistant."
            }
        }
    }

    func executeBridgeCommand(_ id: UUID) {
        guard let index = bridgeCommands.firstIndex(where: { $0.id == id }) else { return }
        bridgeCommands[index].lastRun = .now
        bridgeCommands[index].lastResult = "Blocked: no authenticated bridge transport"
        let command = bridgeCommands[index]

        recordEvent(
            title: command.name,
            confidence: 1,
            source: "\(command.transport.rawValue) bridge",
            action: "Blocked until an authenticated, typed bridge adapter is registered",
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
        commandAudits = []
        preferences = AppPreferences()
        activeScene = nil
        persist()
    }

    func clearCommandAudits() {
        commandAudits = []
        persist()
    }

    func exportConfiguration() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(HomeExportPackage(snapshot: homeSnapshot))
    }

    func importConfiguration(_ data: Data) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let package = try decoder.decode(HomeExportPackage.self, from: data)
        guard package.schemaVersion <= HomeExportPackage.currentSchemaVersion else {
            throw HomeImportError.unsupportedSchema(package.schemaVersion)
        }

        let snapshot = package.snapshot
        devices = snapshot.devices
        signals = snapshot.signals
        rules = snapshot.rules
        brandAdapters = snapshot.brandAdapters
        bridgeCommands = snapshot.bridgeCommands
        preferences = snapshot.preferences
        commandAudits = snapshot.commandAudits
        activeScene = nil
        persist()
    }

    func executeLocalAssistantCommand(_ text: String) -> String? {
        let command = text.lowercased()

        if command.contains("all off") || command.contains("turn everything off") {
            return runScene(.allOff, origin: .assistant).message
        }
        if command.contains("focus") {
            return runScene(.focus, origin: .assistant).message
        }
        if command.contains("air") && (
            command.contains("care") ||
            command.contains("clean") ||
            command.contains("quality")
        ) {
            return runScene(.airCare, origin: .assistant).message
        }
        if command.contains("arrive") || command.contains("home scene") {
            return runScene(.arrive, origin: .assistant).message
        }
        if command.contains("status") || command.contains("attention") {
            let summary = environmentalSummary
            let offline = devices.filter { !$0.isOnline }.count
            return "\(summary.healthLabel). \(onlineDeviceCount) devices are online, \(offline) are offline, and \(enabledRuleCount) automations are enabled."
        }

        for device in devices {
            guard command.contains(device.name.lowercased()) else { continue }
            if command.contains("turn on") || command.hasSuffix(" on") {
                return executeCommand(
                    .setPower(true),
                    for: device.id,
                    origin: .assistant
                ).message
            }
            if command.contains("turn off") || command.hasSuffix(" off") {
                return executeCommand(
                    .setPower(false),
                    for: device.id,
                    origin: .assistant
                ).message
            }
            guard device.isOnline else {
                return "\(device.name) is in your inventory but is not connected. Open Devices, select it, and add a compatible local or account route."
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
            return "I will not ask you to enable Third-Party Compatibility again. Open Integrations > TP-Link / Tapo to test Apple Home Matter bridging for H100/T310 or connect Home Assistant for live lights, plugs, sensors, cameras, and commands. [Official Tapo compatibility details](https://www.tapo.com/en/faq/714/)"
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

    private func updateDevice(
        _ id: UUID,
        persistAfterUpdate: Bool = true,
        update: (inout SmartDevice) -> Void
    ) {
        guard let index = devices.firstIndex(where: { $0.id == id }) else { return }
        update(&devices[index])
        if persistAfterUpdate {
            persist()
        }
    }

    private func mutateDevices(_ update: (inout SmartDevice) -> Void) {
        for index in devices.indices {
            update(&devices[index])
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

    private func apply(_ command: DeviceCommand, to device: inout SmartDevice) {
        switch command {
        case let .setPower(isOn):
            device.isOn = isOn
        case let .setBrightness(value):
            device.brightness = value
            device.isOn = value > 0
        case let .setColor(value):
            device.colorName = value
            device.isOn = true
        case let .setFanSpeed(value):
            device.fanSpeed = value
            device.isOn = value > 0
        case let .setTargetTemperature(value):
            device.targetTemperature = value
        case let .setMode(value):
            device.mode = value
        }
        device.lastUpdated = .now
    }

    private func sceneCommand(
        _ scene: ScenePreset,
        device: SmartDevice
    ) -> DeviceCommand? {
        switch scene {
        case .arrive:
            if [.normalLight, .dimmerLight, .colorLight].contains(device.kind) {
                return device.capabilities.contains(.brightness)
                    ? .setBrightness(58)
                    : .setPower(true)
            }
            if device.kind == .purifier {
                return .setFanSpeed(2)
            }
        case .focus:
            if device.room == "Studio", device.capabilities.contains(.brightness) {
                return .setBrightness(72)
            }
            if device.kind == .smartTV {
                return .setPower(false)
            }
        case .airCare:
            if device.kind == .purifier {
                return .setFanSpeed(4)
            }
            if device.kind == .airConditioner {
                return .setTargetTemperature(23)
            }
        case .allOff:
            if device.capabilities.contains(.power) {
                return .setPower(false)
            }
        }
        return nil
    }

    private func recordCommandAudit(
        device: SmartDevice,
        command: String,
        origin: CommandOrigin,
        risk: CommandRisk,
        outcome: CommandAuditOutcome,
        detail: String,
        persistAfterInsert: Bool = true
    ) {
        commandAudits.insert(
            CommandAuditRecord(
                deviceID: device.id,
                deviceName: device.name,
                command: command,
                origin: origin,
                risk: risk,
                outcome: outcome,
                detail: detail
            ),
            at: 0
        )
        commandAudits = Array(commandAudits.prefix(500))
        if persistAfterInsert {
            persist()
        }
    }

    private func persist() {
        if let homePersistence {
            do {
                try homePersistence.save(homeSnapshot)
                persistenceIssue = nil
            } catch {
                persistenceIssue = "SwiftData save failed: \(error.localizedDescription)"
            }
            return
        }

        let state = PersistedState(snapshot: homeSnapshot)
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private var homeSnapshot: HomePersistenceSnapshot {
        HomePersistenceSnapshot(
            devices: devices,
            signals: signals,
            rules: rules,
            brandAdapters: brandAdapters,
            bridgeCommands: bridgeCommands,
            preferences: preferences,
            commandAudits: commandAudits
        )
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
    var commandAudits: [CommandAuditRecord]?

    init(snapshot: HomePersistenceSnapshot) {
        devices = snapshot.devices
        signals = snapshot.signals
        rules = snapshot.rules
        brandAdapters = snapshot.brandAdapters
        bridgeCommands = snapshot.bridgeCommands
        preferences = snapshot.preferences
        commandAudits = snapshot.commandAudits
    }
}
