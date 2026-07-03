import Foundation

enum SampleData {
    static let devices: [SmartDevice] = [
        SmartDevice(
            name: "Ceiling light",
            room: "Living",
            kind: .normalLight,
            manufacturer: "Generic relay",
            protocols: [.matter, .localWifi],
            capabilities: [.power],
            isOnline: true,
            isOn: true,
            brightness: nil,
            colorName: nil,
            temperature: nil,
            humidity: nil,
            lux: nil,
            airQualityIndex: nil,
            note: "Basic on/off lighting endpoint."
        ),
        SmartDevice(
            name: "Desk dimmer",
            room: "Studio",
            kind: .dimmerLight,
            manufacturer: "Shelly style",
            protocols: [.homeKit, .mqtt],
            capabilities: [.power, .brightness],
            isOnline: true,
            isOn: true,
            brightness: 74,
            colorName: nil,
            temperature: nil,
            humidity: nil,
            lux: nil,
            airQualityIndex: nil,
            note: "Brightness control without color."
        ),
        SmartDevice(
            name: "Mood strip",
            room: "Living",
            kind: .colorLight,
            manufacturer: "Hue style",
            protocols: [.homeKit, .matter],
            capabilities: [.power, .brightness, .color, .whiteTemperature],
            isOnline: true,
            isOn: true,
            brightness: 62,
            colorName: "Amber",
            temperature: nil,
            humidity: nil,
            lux: nil,
            airQualityIndex: nil,
            note: "RGB and white temperature lighting."
        ),
        SmartDevice(
            name: "Climate puck",
            room: "Bedroom",
            kind: .climateSensor,
            manufacturer: "Aqara style",
            protocols: [.matter, .bluetooth],
            capabilities: [.temperatureReading, .humidityReading],
            isOnline: true,
            isOn: true,
            brightness: nil,
            colorName: nil,
            temperature: 23.4,
            humidity: 48,
            lux: nil,
            airQualityIndex: nil,
            note: "Temperature and humidity sensor."
        ),
        SmartDevice(
            name: "Window lux",
            room: "Studio",
            kind: .lightSensor,
            manufacturer: "DIY ESP32",
            protocols: [.mqtt, .localWifi],
            capabilities: [.lightReading],
            isOnline: true,
            isOn: true,
            brightness: nil,
            colorName: nil,
            temperature: nil,
            humidity: nil,
            lux: 318,
            airQualityIndex: nil,
            note: "Ambient light level for adaptive scenes."
        ),
        SmartDevice(
            name: "Main bridge",
            room: "Utility",
            kind: .smartHub,
            manufacturer: "Conductor bridge",
            protocols: [.homeKit, .matter, .mqtt, .infrared, .radioFrequency],
            capabilities: [.hubBridge, .localNetwork, .bluetooth],
            isOnline: true,
            isOn: true,
            brightness: nil,
            colorName: nil,
            temperature: nil,
            humidity: nil,
            lux: nil,
            airQualityIndex: nil,
            note: "Planned RF/IR bridge and local device router."
        ),
        SmartDevice(
            name: "Smart TV",
            room: "Living",
            kind: .smartTV,
            manufacturer: "SmartHub TV",
            protocols: [.localWifi, .infrared, .vendorCloud],
            capabilities: [.power, .mediaControl, .hubBridge],
            isOnline: true,
            isOn: false,
            brightness: nil,
            colorName: nil,
            temperature: nil,
            humidity: nil,
            lux: nil,
            airQualityIndex: nil,
            note: "TV plus smart-hub style control surface."
        ),
        SmartDevice(
            name: "Entry camera",
            room: "Entry",
            kind: .camera,
            manufacturer: "Wi-Fi camera",
            protocols: [.localWifi, .vendorCloud],
            capabilities: [.cameraStream, .soundTrigger, .localNetwork],
            isOnline: true,
            isOn: true,
            brightness: nil,
            colorName: nil,
            temperature: nil,
            humidity: nil,
            lux: nil,
            airQualityIndex: nil,
            note: "Camera stream placeholder."
        ),
        SmartDevice(
            name: "Air purifier",
            room: "Bedroom",
            kind: .purifier,
            manufacturer: "Smart purifier",
            protocols: [.matter, .localWifi],
            capabilities: [.power, .fanSpeed, .airQuality],
            isOnline: true,
            isOn: true,
            brightness: nil,
            colorName: nil,
            temperature: nil,
            humidity: nil,
            lux: nil,
            airQualityIndex: 31,
            note: "Air cleaning and air-quality feedback."
        ),
        SmartDevice(
            name: "Wall AC",
            room: "Bedroom",
            kind: .airConditioner,
            manufacturer: "AC style",
            protocols: [.infrared, .localWifi],
            capabilities: [.power, .coolingMode, .fanSpeed, .temperatureReading],
            isOnline: false,
            isOn: false,
            brightness: nil,
            colorName: nil,
            temperature: 24,
            humidity: nil,
            lux: nil,
            airQualityIndex: nil,
            note: "IR/local Wi-Fi control target."
        )
    ]

    static let signals: [SignalEvent] = [
        SignalEvent(title: "Fan vibration", confidence: 0.88, source: "Sound classifier", action: "Check purifier or AC fan speed", symbol: "waveform"),
        SignalEvent(title: "Doorbell pattern", confidence: 0.76, source: "Microphone", action: "Show entry camera", symbol: "bell"),
        SignalEvent(title: "Low light", confidence: 0.93, source: "Lux sensor", action: "Raise studio dimmer", symbol: "sun.min")
    ]

    static let rules: [AutomationRule] = [
        AutomationRule(title: "Doorbell camera", condition: "Doorbell sound or entry motion", action: "Show camera, lower media, notify phone", isEnabled: true),
        AutomationRule(title: "Healthy sleep air", condition: "Bedroom AQI above 50", action: "Start purifier and lower AC fan", isEnabled: true),
        AutomationRule(title: "Adaptive studio light", condition: "Lux below 220 while present", action: "Set desk dimmer to 72%", isEnabled: true),
        AutomationRule(title: "Legacy AC control", condition: "Bedroom above 25 C", action: "Send IR cooling command", isEnabled: false)
    ]

    static let frameworks: [FrameworkPlan] = [
        FrameworkPlan(name: "SwiftUI", purpose: "Native iPhone interface and navigation", status: "Active", symbol: "rectangle.stack"),
        FrameworkPlan(name: "HomeKit", purpose: "Apple Home accessories and rooms", status: "Planned", symbol: "house"),
        FrameworkPlan(name: "Matter", purpose: "Cross-manufacturer device control", status: "Planned", symbol: "point.3.connected.trianglepath.dotted"),
        FrameworkPlan(name: "Core ML", purpose: "On-device model execution", status: "Planned", symbol: "brain"),
        FrameworkPlan(name: "Sound Analysis", purpose: "Audio classifier pipeline", status: "Planned", symbol: "waveform"),
        FrameworkPlan(name: "Core Bluetooth", purpose: "Hub and sensor discovery", status: "Planned", symbol: "dot.radiowaves.left.and.right"),
        FrameworkPlan(name: "Network", purpose: "Local bridge, camera, MQTT, WebSocket", status: "Planned", symbol: "network")
    ]
}
