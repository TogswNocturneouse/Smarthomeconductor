import Foundation
import SwiftUI

enum DeviceKind: String, CaseIterable, Identifiable {
    case normalLight = "Normal light"
    case dimmerLight = "Dimmer light"
    case colorLight = "Multicolor light"
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
        case .dimmerLight: "slider.horizontal.3"
        case .colorLight: "paintpalette"
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

enum DeviceCapability: String, CaseIterable, Identifiable {
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

enum DeviceProtocol: String, CaseIterable, Identifiable {
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

struct SmartDevice: Identifiable, Hashable {
    let id = UUID()
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
}

struct SignalEvent: Identifiable, Hashable {
    let id = UUID()
    var title: String
    var confidence: Double
    var source: String
    var action: String
    var symbol: String
}

struct AutomationRule: Identifiable, Hashable {
    let id = UUID()
    var title: String
    var condition: String
    var action: String
    var isEnabled: Bool
}

struct FrameworkPlan: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var purpose: String
    var status: String
    var symbol: String
}

final class AppStore: ObservableObject {
    @Published var devices: [SmartDevice] = SampleData.devices
    @Published var signals: [SignalEvent] = SampleData.signals
    @Published var rules: [AutomationRule] = SampleData.rules
    @Published var frameworks: [FrameworkPlan] = SampleData.frameworks

    var onlineDeviceCount: Int {
        devices.filter(\.isOnline).count
    }

    var activeDeviceCount: Int {
        devices.filter(\.isOn).count
    }

    var rooms: [String] {
        Array(Set(devices.map(\.room))).sorted()
    }

    func devices(in room: String) -> [SmartDevice] {
        devices.filter { $0.room == room }
    }
}
