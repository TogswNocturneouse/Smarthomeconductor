import Foundation

enum DeviceKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case normalLight = "Normal light"
    case dimmerLight = "Dimmer light"
    case colorLight = "Multicolor light"
    case smartPlug = "Smart plug"
    case climateSensor = "Temperature humidity"
    case lightSensor = "Light sensor"
    case smartHub = "IoT smart hub"
    case smartTV = "Smart TV"
    case camera = "Wi-Fi camera"
    case purifier = "Smart purifier"
    case airConditioner = "Smart AC"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .normalLight: "lightbulb"
        case .dimmerLight: "lightbulb.max"
        case .colorLight: "paintpalette"
        case .smartPlug: "powerplug"
        case .climateSensor: "thermometer.medium"
        case .lightSensor: "sun.max"
        case .smartHub: "network"
        case .smartTV: "tv"
        case .camera: "video"
        case .purifier: "wind"
        case .airConditioner: "snowflake"
        }
    }
}

enum DeviceCapability: String, CaseIterable, Identifiable, Codable, Sendable {
    case power = "Power"
    case brightness = "Brightness"
    case color = "Color"
    case whiteTemperature = "White temp"
    case temperatureReading = "Temperature"
    case humidityReading = "Humidity"
    case lightReading = "Light"
    case hubBridge = "Hub bridge"
    case mediaControl = "Media"
    case cameraStream = "Camera"
    case airQuality = "Air quality"
    case fanSpeed = "Fan speed"
    case coolingMode = "Cooling"
    case localNetwork = "Local network"
    case bluetooth = "Bluetooth"
    case soundTrigger = "Sound trigger"

    var id: String { rawValue }
}

enum DeviceProtocol: String, CaseIterable, Identifiable, Codable, Sendable {
    case homeKit = "HomeKit"
    case matter = "Matter"
    case mqtt = "MQTT"
    case localWifi = "Local Wi-Fi"
    case bluetooth = "Bluetooth"
    case infrared = "IR"
    case radioFrequency = "RF"
    case vendorCloud = "Vendor cloud"

    var id: String { rawValue }
}

struct SmartDevice: Identifiable, Hashable, Codable, Sendable {
    var id = UUID()
    var name: String
    var room: String
    var kind: DeviceKind
    var manufacturer: String
    var protocols: [DeviceProtocol]
    var capabilities: [DeviceCapability]
    var isOnline: Bool
    var isOn: Bool
    var brightness: Double?
    var colorName: String?
    var temperature: Double?
    var humidity: Double?
    var lux: Double?
    var airQualityIndex: Int?
    var note: String
    var fanSpeed: Double? = nil
    var targetTemperature: Double? = nil
    var mode: String? = nil
    var batteryLevel: Int? = nil
    var lastUpdated: Date = .now
}

struct SignalEvent: Identifiable, Hashable, Codable, Sendable {
    var id = UUID()
    var title: String
    var confidence: Double
    var source: String
    var action: String
    var symbol: String
    var timestamp: Date = .now
    var isAcknowledged = false
}

struct AutomationRule: Identifiable, Hashable, Codable, Sendable {
    var id = UUID()
    var title: String
    var condition: String
    var action: String
    var isEnabled: Bool
    var lastRun: Date? = nil
}

struct FrameworkPlan: Identifiable, Hashable, Codable, Sendable {
    var id = UUID()
    var name: String
    var purpose: String
    var status: String
    var symbol: String
}

enum AdapterStage: String, Identifiable, Hashable, Codable, Sendable {
    case ready = "Ready"
    case scaffolded = "Available"
    case planned = "Needs login"

    var id: String { rawValue }
}

struct BrandAdapterPlan: Identifiable, Hashable, Codable, Sendable {
    var id = UUID()
    var brand: String
    var ecosystem: String
    var stage: AdapterStage
    var deviceKinds: [DeviceKind]
    var connectionPlan: String
    var nextAction: String
    var symbol: String
    var isEnabled = false
    var discoveredDevices = 0
    var lastSync: Date? = nil
    var isScanning = false
}

struct BridgeCommand: Identifiable, Hashable, Codable, Sendable {
    var id = UUID()
    var name: String
    var transport: DeviceProtocol
    var target: String
    var payload: String
    var safetyNote: String
    var lastRun: Date? = nil
    var lastResult: String? = nil
}

struct ClassifierSlot: Identifiable, Hashable, Codable, Sendable {
    var id = UUID()
    var name: String
    var modelFile: String
    var input: String
    var outputs: [String]
    var nextAction: String
}

struct AppPreferences: Codable, Equatable, Sendable {
    var localProcessingOnly = true
    var hapticsEnabled = true
    var showOfflineDevices = true
    var reducedGlow = false
}

struct EnvironmentalSummary: Equatable, Sendable {
    var temperature: Double?
    var humidity: Double?
    var illuminance: Double?
    var airQualityIndex: Int?
    var onlineSensors: Int
    var updatedAt: Date?

    var healthLabel: String {
        guard onlineSensors > 0 else { return "No sensor data" }
        if let airQualityIndex, airQualityIndex > 100 { return "Air needs attention" }
        if let humidity, !(35...65).contains(humidity) { return "Humidity needs attention" }
        if let temperature, !(18...27).contains(temperature) { return "Temperature needs attention" }
        return "Environment stable"
    }

    var isHealthy: Bool {
        healthLabel == "Environment stable"
    }
}

enum ScenePreset: String, CaseIterable, Identifiable, Sendable {
    case arrive = "Arrive"
    case focus = "Focus"
    case airCare = "Air care"
    case allOff = "All off"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .arrive: "door.left.hand.open"
        case .focus: "scope"
        case .airCare: "wind"
        case .allOff: "power"
        }
    }

    var detail: String {
        switch self {
        case .arrive: "Lights and comfort"
        case .focus: "Studio at 72%"
        case .airCare: "Purifier and climate"
        case .allOff: "Power down"
        }
    }
}

struct DiscoveredAccessory: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let kind: DeviceKind
}
