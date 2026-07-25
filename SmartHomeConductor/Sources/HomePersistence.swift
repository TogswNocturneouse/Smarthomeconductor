import Foundation
import SwiftData

enum PersistenceMode: String, Sendable {
    case swiftData = "SwiftData"
    case inMemoryRecovery = "In-memory recovery"
    case legacyUserDefaults = "Legacy UserDefaults"
}

struct ModelContainerResult {
    let container: ModelContainer
    let mode: PersistenceMode
}

@MainActor
enum AppModelContainer {
    static func make() -> ModelContainerResult {
        let schema = appSchema
        let persistent = ModelConfiguration("Conductor", schema: schema)

        do {
            return ModelContainerResult(
                container: try ModelContainer(for: schema, configurations: [persistent]),
                mode: .swiftData
            )
        } catch {
            let recovery = ModelConfiguration(
                "ConductorRecovery",
                schema: schema,
                isStoredInMemoryOnly: true
            )
            do {
                return ModelContainerResult(
                    container: try ModelContainer(for: schema, configurations: [recovery]),
                    mode: .inMemoryRecovery
                )
            } catch {
                fatalError("Unable to create persistent or recovery model container: \(error)")
            }
        }
    }

    static func makeInMemory() throws -> ModelContainer {
        let schema = appSchema
        let configuration = ModelConfiguration(
            "ConductorTests",
            schema: schema,
            isStoredInMemoryOnly: true
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private static var appSchema: Schema {
        Schema([
            LearnedRecord.self,
            AssistantMessageRecord.self,
            HomeRecord.self,
            RoomRecord.self,
            DeviceRecord.self,
            DeviceProtocolRecord.self,
            DeviceCapabilityRecord.self,
            DeviceStateRecord.self,
            AutomationRecord.self,
            EventRecord.self,
            PreferenceRecord.self,
            IntegrationRecord.self,
            BridgeCommandRecord.self,
            CommandAuditEntity.self
        ])
    }
}

@Model
final class HomeRecord {
    var id: UUID
    var name: String
    var schemaVersion: Int
    var updatedAt: Date

    init(
        id: UUID = UUID(uuidString: "6C3350CE-3D85-4D06-BCB5-68C24AA65A0A")!,
        name: String = "My Home",
        schemaVersion: Int = HomeExportPackage.currentSchemaVersion,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.schemaVersion = schemaVersion
        self.updatedAt = updatedAt
    }
}

@Model
final class RoomRecord {
    var id: UUID
    var name: String

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

@Model
final class DeviceRecord {
    var id: UUID
    var name: String
    var room: String
    var kindRawValue: String
    var manufacturer: String
    var note: String

    init(device: SmartDevice) {
        id = device.id
        name = device.name
        room = device.room
        kindRawValue = device.kind.rawValue
        manufacturer = device.manufacturer
        note = device.note
    }
}

@Model
final class DeviceProtocolRecord {
    var id: UUID
    var deviceID: UUID
    var protocolRawValue: String

    init(deviceID: UUID, deviceProtocol: DeviceProtocol) {
        id = UUID()
        self.deviceID = deviceID
        protocolRawValue = deviceProtocol.rawValue
    }
}

@Model
final class DeviceCapabilityRecord {
    var id: UUID
    var deviceID: UUID
    var capabilityRawValue: String

    init(deviceID: UUID, capability: DeviceCapability) {
        id = UUID()
        self.deviceID = deviceID
        capabilityRawValue = capability.rawValue
    }
}

@Model
final class DeviceStateRecord {
    var id: UUID
    var deviceID: UUID
    var isOnline: Bool
    var isOn: Bool
    var brightness: Double?
    var colorName: String?
    var temperature: Double?
    var humidity: Double?
    var lux: Double?
    var airQualityIndex: Int?
    var fanSpeed: Double?
    var targetTemperature: Double?
    var mode: String?
    var batteryLevel: Int?
    var lastUpdated: Date

    init(device: SmartDevice) {
        id = UUID()
        deviceID = device.id
        isOnline = device.isOnline
        isOn = device.isOn
        brightness = device.brightness
        colorName = device.colorName
        temperature = device.temperature
        humidity = device.humidity
        lux = device.lux
        airQualityIndex = device.airQualityIndex
        fanSpeed = device.fanSpeed
        targetTemperature = device.targetTemperature
        mode = device.mode
        batteryLevel = device.batteryLevel
        lastUpdated = device.lastUpdated
    }
}

@Model
final class AutomationRecord {
    var id: UUID
    var title: String
    var condition: String
    var action: String
    var isEnabled: Bool
    var lastRun: Date?

    init(rule: AutomationRule) {
        id = rule.id
        title = rule.title
        condition = rule.condition
        action = rule.action
        isEnabled = rule.isEnabled
        lastRun = rule.lastRun
    }
}

@Model
final class EventRecord {
    var id: UUID
    var title: String
    var confidence: Double
    var source: String
    var action: String
    var symbol: String
    var timestamp: Date
    var isAcknowledged: Bool

    init(event: SignalEvent) {
        id = event.id
        title = event.title
        confidence = event.confidence
        source = event.source
        action = event.action
        symbol = event.symbol
        timestamp = event.timestamp
        isAcknowledged = event.isAcknowledged
    }
}

@Model
final class PreferenceRecord {
    var id: UUID
    var localProcessingOnly: Bool
    var hapticsEnabled: Bool
    var showOfflineDevices: Bool
    var reducedGlow: Bool
    var assistantLightControlAllowed: Bool

    init(
        id: UUID = UUID(uuidString: "1B85A284-50C1-42B1-9DA3-E6476685F460")!,
        preferences: AppPreferences
    ) {
        self.id = id
        localProcessingOnly = preferences.localProcessingOnly
        hapticsEnabled = preferences.hapticsEnabled
        showOfflineDevices = preferences.showOfflineDevices
        reducedGlow = preferences.reducedGlow
        assistantLightControlAllowed = preferences.assistantLightControlAllowed
    }
}

@Model
final class IntegrationRecord {
    var id: UUID
    var brand: String
    var ecosystem: String
    var stageRawValue: String
    var deviceKinds: String
    var connectionPlan: String
    var nextAction: String
    var symbol: String
    var isEnabled: Bool
    var discoveredDevices: Int
    var lastSync: Date?
    var isScanning: Bool

    init(adapter: BrandAdapterPlan) {
        id = adapter.id
        brand = adapter.brand
        ecosystem = adapter.ecosystem
        stageRawValue = adapter.stage.rawValue
        deviceKinds = adapter.deviceKinds.map(\.rawValue).joined(separator: Self.separator)
        connectionPlan = adapter.connectionPlan
        nextAction = adapter.nextAction
        symbol = adapter.symbol
        isEnabled = adapter.isEnabled
        discoveredDevices = adapter.discoveredDevices
        lastSync = adapter.lastSync
        isScanning = false
    }

    static let separator = "\u{1F}"
}

@Model
final class BridgeCommandRecord {
    var id: UUID
    var name: String
    var transportRawValue: String
    var target: String
    var payload: String
    var safetyNote: String
    var lastRun: Date?
    var lastResult: String?

    init(command: BridgeCommand) {
        id = command.id
        name = command.name
        transportRawValue = command.transport.rawValue
        target = command.target
        payload = command.payload
        safetyNote = command.safetyNote
        lastRun = command.lastRun
        lastResult = command.lastResult
    }
}

@Model
final class CommandAuditEntity {
    var id: UUID
    var deviceID: UUID
    var deviceName: String
    var command: String
    var originRawValue: String
    var riskRawValue: String
    var outcomeRawValue: String
    var detail: String
    var timestamp: Date

    init(record: CommandAuditRecord) {
        id = record.id
        deviceID = record.deviceID
        deviceName = record.deviceName
        command = record.command
        originRawValue = record.origin.rawValue
        riskRawValue = record.risk.rawValue
        outcomeRawValue = record.outcome.rawValue
        detail = record.detail
        timestamp = record.timestamp
    }
}

struct HomePersistenceSnapshot {
    var devices: [SmartDevice]
    var signals: [SignalEvent]
    var rules: [AutomationRule]
    var brandAdapters: [BrandAdapterPlan]
    var bridgeCommands: [BridgeCommand]
    var preferences: AppPreferences
    var commandAudits: [CommandAuditRecord]
}

struct HomeExportPackage: Codable, Sendable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var exportedAt: Date
    var devices: [SmartDevice]
    var signals: [SignalEvent]
    var rules: [AutomationRule]
    var brandAdapters: [BrandAdapterPlan]
    var bridgeCommands: [BridgeCommand]
    var preferences: AppPreferences
    var commandAudits: [CommandAuditRecord]

    init(snapshot: HomePersistenceSnapshot) {
        schemaVersion = Self.currentSchemaVersion
        exportedAt = .now
        devices = snapshot.devices
        signals = snapshot.signals
        rules = snapshot.rules
        brandAdapters = snapshot.brandAdapters
        bridgeCommands = snapshot.bridgeCommands
        preferences = snapshot.preferences
        commandAudits = snapshot.commandAudits
    }

    var snapshot: HomePersistenceSnapshot {
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
}

enum HomeImportError: LocalizedError {
    case unsupportedSchema(Int)

    var errorDescription: String? {
        switch self {
        case let .unsupportedSchema(version):
            "This configuration uses unsupported schema version \(version)."
        }
    }
}

@MainActor
final class HomePersistenceStore {
    private let context: ModelContext

    init(container: ModelContainer) {
        context = ModelContext(container)
    }

    func load() throws -> HomePersistenceSnapshot? {
        guard try context.fetch(FetchDescriptor<HomeRecord>()).first != nil else {
            return nil
        }

        let deviceRecords = try context.fetch(FetchDescriptor<DeviceRecord>())
        let protocolRecords = try context.fetch(FetchDescriptor<DeviceProtocolRecord>())
        let capabilityRecords = try context.fetch(FetchDescriptor<DeviceCapabilityRecord>())
        let stateRecords = try context.fetch(FetchDescriptor<DeviceStateRecord>())
        let stateByDevice = Dictionary(uniqueKeysWithValues: stateRecords.map { ($0.deviceID, $0) })

        let devices = deviceRecords.map { record in
            let state = stateByDevice[record.id]
            return SmartDevice(
                id: record.id,
                name: record.name,
                room: record.room,
                kind: DeviceKind(rawValue: record.kindRawValue) ?? .normalLight,
                manufacturer: record.manufacturer,
                protocols: protocolRecords
                    .filter { $0.deviceID == record.id }
                    .compactMap { DeviceProtocol(rawValue: $0.protocolRawValue) },
                capabilities: capabilityRecords
                    .filter { $0.deviceID == record.id }
                    .compactMap { DeviceCapability(rawValue: $0.capabilityRawValue) },
                isOnline: state?.isOnline ?? false,
                isOn: state?.isOn ?? false,
                brightness: state?.brightness,
                colorName: state?.colorName,
                temperature: state?.temperature,
                humidity: state?.humidity,
                lux: state?.lux,
                airQualityIndex: state?.airQualityIndex,
                note: record.note,
                fanSpeed: state?.fanSpeed,
                targetTemperature: state?.targetTemperature,
                mode: state?.mode,
                batteryLevel: state?.batteryLevel,
                lastUpdated: state?.lastUpdated ?? .now
            )
        }

        let rules = try context.fetch(FetchDescriptor<AutomationRecord>()).map {
            AutomationRule(
                id: $0.id,
                title: $0.title,
                condition: $0.condition,
                action: $0.action,
                isEnabled: $0.isEnabled,
                lastRun: $0.lastRun
            )
        }
        let signals = try context.fetch(FetchDescriptor<EventRecord>()).map {
            SignalEvent(
                id: $0.id,
                title: $0.title,
                confidence: $0.confidence,
                source: $0.source,
                action: $0.action,
                symbol: $0.symbol,
                timestamp: $0.timestamp,
                isAcknowledged: $0.isAcknowledged
            )
        }
        let adapters = try context.fetch(FetchDescriptor<IntegrationRecord>()).map {
            BrandAdapterPlan(
                id: $0.id,
                brand: $0.brand,
                ecosystem: $0.ecosystem,
                stage: AdapterStage(rawValue: $0.stageRawValue) ?? .planned,
                deviceKinds: $0.deviceKinds
                    .components(separatedBy: IntegrationRecord.separator)
                    .compactMap(DeviceKind.init(rawValue:)),
                connectionPlan: $0.connectionPlan,
                nextAction: $0.nextAction,
                symbol: $0.symbol,
                isEnabled: $0.isEnabled,
                discoveredDevices: $0.discoveredDevices,
                lastSync: $0.lastSync,
                isScanning: false
            )
        }
        let bridgeCommands = try context.fetch(FetchDescriptor<BridgeCommandRecord>()).map {
            BridgeCommand(
                id: $0.id,
                name: $0.name,
                transport: DeviceProtocol(rawValue: $0.transportRawValue) ?? .localWifi,
                target: $0.target,
                payload: $0.payload,
                safetyNote: $0.safetyNote,
                lastRun: $0.lastRun,
                lastResult: $0.lastResult
            )
        }
        let preferences = try context.fetch(FetchDescriptor<PreferenceRecord>()).first.map {
            AppPreferences(
                localProcessingOnly: $0.localProcessingOnly,
                hapticsEnabled: $0.hapticsEnabled,
                showOfflineDevices: $0.showOfflineDevices,
                reducedGlow: $0.reducedGlow,
                assistantLightControlAllowed: $0.assistantLightControlAllowed
            )
        } ?? AppPreferences()
        let audits = try context.fetch(FetchDescriptor<CommandAuditEntity>()).map {
            CommandAuditRecord(
                id: $0.id,
                deviceID: $0.deviceID,
                deviceName: $0.deviceName,
                command: $0.command,
                origin: CommandOrigin(rawValue: $0.originRawValue) ?? .userInterface,
                risk: CommandRisk(rawValue: $0.riskRawValue) ?? .ordinary,
                outcome: CommandAuditOutcome(rawValue: $0.outcomeRawValue) ?? .rejected,
                detail: $0.detail,
                timestamp: $0.timestamp
            )
        }

        return HomePersistenceSnapshot(
            devices: devices.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending },
            signals: signals.sorted { $0.timestamp > $1.timestamp },
            rules: rules.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending },
            brandAdapters: adapters,
            bridgeCommands: bridgeCommands,
            preferences: preferences,
            commandAudits: audits.sorted { $0.timestamp > $1.timestamp }
        )
    }

    func save(_ snapshot: HomePersistenceSnapshot) throws {
        try deleteAll(HomeRecord.self)
        try deleteAll(RoomRecord.self)
        try deleteAll(DeviceRecord.self)
        try deleteAll(DeviceProtocolRecord.self)
        try deleteAll(DeviceCapabilityRecord.self)
        try deleteAll(DeviceStateRecord.self)
        try deleteAll(AutomationRecord.self)
        try deleteAll(EventRecord.self)
        try deleteAll(PreferenceRecord.self)
        try deleteAll(IntegrationRecord.self)
        try deleteAll(BridgeCommandRecord.self)
        try deleteAll(CommandAuditEntity.self)

        context.insert(HomeRecord())
        Set(snapshot.devices.map(\.room)).sorted().forEach {
            context.insert(RoomRecord(name: $0))
        }
        snapshot.devices.forEach { device in
            context.insert(DeviceRecord(device: device))
            context.insert(DeviceStateRecord(device: device))
            device.protocols.forEach {
                context.insert(DeviceProtocolRecord(deviceID: device.id, deviceProtocol: $0))
            }
            device.capabilities.forEach {
                context.insert(DeviceCapabilityRecord(deviceID: device.id, capability: $0))
            }
        }
        snapshot.rules.forEach { context.insert(AutomationRecord(rule: $0)) }
        snapshot.signals.forEach { context.insert(EventRecord(event: $0)) }
        snapshot.brandAdapters.forEach { context.insert(IntegrationRecord(adapter: $0)) }
        snapshot.bridgeCommands.forEach { context.insert(BridgeCommandRecord(command: $0)) }
        snapshot.commandAudits.forEach { context.insert(CommandAuditEntity(record: $0)) }
        context.insert(PreferenceRecord(preferences: snapshot.preferences))

        try context.save()
    }

    private func deleteAll<T: PersistentModel>(_ type: T.Type) throws {
        for model in try context.fetch(FetchDescriptor<T>()) {
            context.delete(model)
        }
    }
}
