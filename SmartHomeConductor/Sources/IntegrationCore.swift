import Foundation
@preconcurrency import CoreBluetooth
@preconcurrency import HomeKit
@preconcurrency import Network

struct AdapterAuthenticationRequest: Sendable {
    let credentialReference: String?
    let parameters: [String: String]
}

struct AdapterSessionInfo: Sendable {
    let adapter: String
    let authenticatedAt: Date
    let expiresAt: Date?
}

struct AdapterDeviceState: Sendable {
    let deviceID: String
    let values: [String: String]
    let observedAt: Date
}

struct AdapterUpdate: Sendable {
    let deviceID: String
    let state: AdapterDeviceState
}

enum AdapterHealthStatus: String, Sendable {
    case healthy
    case degraded
    case disconnected
    case authenticationRequired
}

struct AdapterHealth: Sendable {
    let status: AdapterHealthStatus
    let detail: String
    let checkedAt: Date
}

protocol BrandDeviceAdapter: Sendable {
    var brand: String { get }
    func discover() async throws -> [DiscoveredAccessory]
    func authenticate(_ request: AdapterAuthenticationRequest) async throws -> AdapterSessionInfo
    func readState(deviceID: String) async throws -> AdapterDeviceState
    func execute(_ command: DeviceCommand, deviceID: String) async throws -> AdapterDeviceState
    func updates(deviceID: String) -> AsyncStream<AdapterUpdate>
    func reconnect() async throws
    func healthCheck() async -> AdapterHealth
    func disconnect() async
}

actor AdapterRegistry {
    static let live = AdapterRegistry(adapters: [])

    private let adapters: [String: any BrandDeviceAdapter]

    init(adapters: [any BrandDeviceAdapter]) {
        self.adapters = Dictionary(uniqueKeysWithValues: adapters.map { ($0.brand, $0) })
    }

    func discover(brand: String) async -> [DiscoveredAccessory] {
        guard let adapter = adapters[brand] else { return [] }
        do {
            return try await adapter.discover()
        } catch {
            return []
        }
    }

    func health(brand: String) async -> AdapterHealth {
        guard let adapter = adapters[brand] else {
            return AdapterHealth(
                status: .disconnected,
                detail: "No production adapter is registered.",
                checkedAt: .now
            )
        }
        return await adapter.healthCheck()
    }
}

enum DiscoverySource: String, Sendable {
    case appleHome = "Apple Home"
    case bluetooth = "Bluetooth"
    case localNetwork = "Local network"

    var symbol: String {
        switch self {
        case .appleHome: "house"
        case .bluetooth: "dot.radiowaves.left.and.right"
        case .localNetwork: "network"
        }
    }
}

struct DiscoveryCandidate: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let detail: String
    let source: DiscoverySource
    let kind: DeviceKind
    let manufacturer: String
    let protocols: [DeviceProtocol]
    let capabilities: [DeviceCapability]
    let isReachable: Bool
    let room: String

    func makeDevice() -> SmartDevice {
        SmartDevice(
            name: name,
            room: room,
            kind: kind,
            manufacturer: manufacturer,
            protocols: protocols,
            capabilities: capabilities,
            isOnline: source == .appleHome && isReachable,
            isOn: false,
            brightness: capabilities.contains(.brightness) ? 0 : nil,
            colorName: capabilities.contains(.color) ? "White" : nil,
            temperature: nil,
            humidity: nil,
            lux: nil,
            airQualityIndex: nil,
            note: source == .appleHome
                ? "Imported from Apple Home."
                : "Discovered nearby. Authentication or commissioning is still required.",
            fanSpeed: capabilities.contains(.fanSpeed) ? 0 : nil,
            targetTemperature: kind == .airConditioner ? 24 : nil,
            mode: [.purifier, .airConditioner].contains(kind) ? "Auto" : nil
        )
    }
}

final class LocalDiscoveryController: NSObject, ObservableObject, @unchecked Sendable {
    @Published private(set) var candidates: [DiscoveryCandidate] = []
    @Published private(set) var isScanning = false
    @Published private(set) var status = "Ready to scan"

    private var centralManager: CBCentralManager?
    private var browsers: [NWBrowser] = []
    private var homeManager: HMHomeManager?
    private var wantsBluetoothScan = false

    func scanNearby() {
        stop()
        candidates.removeAll { $0.source != .appleHome }
        isScanning = true
        status = "Listening for Bluetooth and Bonjour advertisements"
        wantsBluetoothScan = true

        if centralManager == nil {
            centralManager = CBCentralManager(delegate: self, queue: .main)
        } else {
            startBluetoothIfReady()
        }

        startBonjour()
    }

    func importAppleHome() {
        candidates.removeAll { $0.source == .appleHome }
        status = "Requesting access to Apple Home"
        let manager = HMHomeManager()
        manager.delegate = self
        homeManager = manager
    }

    func stop() {
        centralManager?.stopScan()
        browsers.forEach { $0.cancel() }
        browsers.removeAll()
        wantsBluetoothScan = false
        isScanning = false
        if status.contains("Listening") {
            status = candidates.isEmpty
                ? "No compatible advertisements found"
                : "\(candidates.count) candidates found"
        }
    }

    private func startBluetoothIfReady() {
        guard wantsBluetoothScan, centralManager?.state == .poweredOn else { return }
        centralManager?.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }

    private func startBonjour() {
        let serviceTypes = [
            "_hap._tcp",
            "_matter._tcp",
            "_shelly._tcp",
            "_http._tcp",
            "_rtsp._tcp",
            "_mqtt._tcp"
        ]

        for serviceType in serviceTypes {
            let browser = NWBrowser(
                for: .bonjour(type: serviceType, domain: nil),
                using: .tcp
            )
            browser.browseResultsChangedHandler = { [weak self] results, _ in
                guard let self else { return }
                for result in results {
                    guard case let .service(name, type, _, _) = result.endpoint else {
                        continue
                    }
                    let displayName = self.displayName(for: name, type: type)
                    let inferredKind = self.inferKind(from: "\(displayName) \(type)")
                    self.addCandidate(
                        DiscoveryCandidate(
                            id: "bonjour:\(type):\(name)",
                            name: displayName,
                            detail: "\(type) service; pairing may still be required",
                            source: .localNetwork,
                            kind: inferredKind,
                            manufacturer: self.inferManufacturer(from: displayName),
                            protocols: self.protocols(forBonjourType: type),
                            capabilities: self.capabilities(for: inferredKind),
                            isReachable: false,
                            room: "Unassigned"
                        )
                    )
                }
            }
            browser.start(queue: .main)
            browsers.append(browser)
        }
    }

    private func addCandidate(_ candidate: DiscoveryCandidate) {
        guard !candidates.contains(where: { $0.id == candidate.id }) else { return }
        candidates.append(candidate)
        candidates.sort {
            if $0.source != $1.source {
                return $0.source.rawValue < $1.source.rawValue
            }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
        status = "\(candidates.count) candidates found"
    }

    private func inferManufacturer(from value: String) -> String {
        let text = value.lowercased()
        if text.contains("tapo") || text.contains("tp-link") { return "TP-Link / Tapo" }
        if text.contains("xiaomi") || text.contains("zhimi") { return "Xiaomi" }
        if text.contains("samsung") { return "Samsung" }
        if text.contains("midea") || text.contains("mdv") { return "MDV / Midea" }
        if text.contains("electrolux") { return "Electrolux" }
        if text.contains("shelly") { return "Shelly" }
        return "Unknown manufacturer"
    }

    private func displayName(for serviceName: String, type: String) -> String {
        let compact = serviceName.replacingOccurrences(of: "-", with: "")
        let isOpaque = compact.count >= 16 &&
            compact.unicodeScalars.allSatisfy {
                CharacterSet(charactersIn: "0123456789abcdefABCDEF").contains($0)
            }
        guard isOpaque else { return serviceName }
        if type.contains("_matter") { return "Matter accessory" }
        if type.contains("_hap") { return "HomeKit accessory" }
        return "Local network accessory"
    }

    private func inferKind(from value: String) -> DeviceKind {
        let text = value.lowercased()
        if text.contains("camera") || text.contains("c220") || text.contains("tc71") || text.contains("rtsp") {
            return .camera
        }
        if text.contains("purifier") || text.contains("airp") { return .purifier }
        if text.contains("tv") || text.contains("samsung") { return .smartTV }
        if text.contains("ac") || text.contains("midea") || text.contains("mdv") { return .airConditioner }
        if text.contains("sensor") || text.contains("t310") { return .climateSensor }
        if text.contains("hub") || text.contains("h100") { return .smartHub }
        if text.contains("l530") || text.contains("l930") || text.contains("strip") { return .colorLight }
        if text.contains("l510") || text.contains("dimmer") { return .dimmerLight }
        if text.contains("p100") || text.contains("plug") || text.contains("outlet") {
            return .smartPlug
        }
        if text.contains("shelly") { return .smartPlug }
        return .normalLight
    }

    private func protocols(forBonjourType type: String) -> [DeviceProtocol] {
        if type.contains("_hap") { return [.homeKit, .localWifi] }
        if type.contains("_matter") { return [.matter, .localWifi] }
        if type.contains("_shelly") { return [.localWifi] }
        if type.contains("_mqtt") { return [.mqtt, .localWifi] }
        return [.localWifi]
    }

    private func capabilities(for kind: DeviceKind) -> [DeviceCapability] {
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

extension LocalDiscoveryController: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            startBluetoothIfReady()
        } else if central.state == .unauthorized {
            status = "Bluetooth access is not authorized"
        } else if central.state == .poweredOff {
            status = "Bluetooth is turned off"
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let advertisedName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let name = advertisedName ?? peripheral.name ?? "Unnamed Bluetooth accessory"
        let kind = inferKind(from: name)
        addCandidate(
            DiscoveryCandidate(
                id: "bluetooth:\(peripheral.identifier.uuidString)",
                name: name,
                detail: "Bluetooth advertisement, RSSI \(RSSI.intValue) dBm",
                source: .bluetooth,
                kind: kind,
                manufacturer: inferManufacturer(from: name),
                protocols: [.bluetooth],
                capabilities: capabilities(for: kind),
                isReachable: false,
                room: "Unassigned"
            )
        )
    }
}

extension LocalDiscoveryController: HMHomeManagerDelegate {
    func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        guard manager.authorizationStatus.contains(.authorized) else {
            status = "Apple Home access is not authorized"
            return
        }

        for home in manager.homes {
            for accessory in home.accessories {
                let kind = kind(for: accessory.category.categoryType)
                addCandidate(
                    DiscoveryCandidate(
                        id: "homekit:\(accessory.uniqueIdentifier.uuidString)",
                        name: accessory.name,
                        detail: accessory.model ?? "HomeKit accessory",
                        source: .appleHome,
                        kind: kind,
                        manufacturer: accessory.manufacturer ?? "Apple Home accessory",
                        protocols: [.homeKit],
                        capabilities: capabilities(for: kind),
                        isReachable: accessory.isReachable,
                        room: accessory.room?.name ?? home.name
                    )
                )
            }
        }
        status = candidates.contains(where: { $0.source == .appleHome })
            ? "Apple Home accessories are ready to import"
            : "Apple Home contains no accessories"
    }

    private func kind(for category: String) -> DeviceKind {
        switch category {
        case HMAccessoryCategoryTypeLightbulb:
            .dimmerLight
        case HMAccessoryCategoryTypeIPCamera, HMAccessoryCategoryTypeVideoDoorbell:
            .camera
        case HMAccessoryCategoryTypeTelevision:
            .smartTV
        case HMAccessoryCategoryTypeAirPurifier:
            .purifier
        case HMAccessoryCategoryTypeAirConditioner:
            .airConditioner
        case HMAccessoryCategoryTypeBridge, HMAccessoryCategoryTypeOther:
            .smartHub
        case HMAccessoryCategoryTypeSensor:
            .climateSensor
        default:
            .normalLight
        }
    }
}
