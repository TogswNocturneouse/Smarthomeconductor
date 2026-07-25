import Foundation

enum SampleData {
    static let devices: [SmartDevice] = [
        inventoryDevice(
            "Electrolux Wellbeing A5",
            kind: .purifier,
            manufacturer: "Electrolux",
            capabilities: [.power, .fanSpeed, .airQuality],
            protocols: [.localWifi, .vendorCloud]
        ),
        inventoryDevice(
            "Xiaomi Air Purifier 4 Compact",
            kind: .purifier,
            manufacturer: "Xiaomi",
            capabilities: [.power, .fanSpeed, .airQuality, .temperatureReading, .humidityReading],
            protocols: [.localWifi, .vendorCloud]
        ),
        inventoryDevice(
            "Tapo L530",
            kind: .colorLight,
            manufacturer: "TP-Link / Tapo",
            capabilities: [.power, .brightness, .color, .whiteTemperature],
            protocols: [.localWifi, .vendorCloud]
        ),
        inventoryDevice(
            "Tapo L510",
            kind: .dimmerLight,
            manufacturer: "TP-Link / Tapo",
            capabilities: [.power, .brightness],
            protocols: [.localWifi, .vendorCloud]
        ),
        inventoryDevice(
            "Tapo L930",
            kind: .colorLight,
            manufacturer: "TP-Link / Tapo",
            capabilities: [.power, .brightness, .color, .whiteTemperature],
            protocols: [.localWifi, .vendorCloud]
        ),
        inventoryDevice(
            "Tapo C220",
            kind: .camera,
            manufacturer: "TP-Link / Tapo",
            capabilities: [.cameraStream, .localNetwork, .soundTrigger],
            protocols: [.localWifi, .vendorCloud]
        ),
        inventoryDevice(
            "Tapo TC71",
            kind: .camera,
            manufacturer: "TP-Link / Tapo",
            capabilities: [.cameraStream, .localNetwork, .soundTrigger],
            protocols: [.localWifi, .vendorCloud]
        ),
        inventoryDevice(
            "Tapo H100",
            kind: .smartHub,
            manufacturer: "TP-Link / Tapo",
            capabilities: [.hubBridge, .localNetwork],
            protocols: [.localWifi, .vendorCloud]
        ),
        inventoryDevice(
            "Tapo T310",
            kind: .climateSensor,
            manufacturer: "TP-Link / Tapo",
            capabilities: [.temperatureReading, .humidityReading],
            protocols: [.localWifi, .vendorCloud]
        ),
        inventoryDevice(
            "Tapo P100 - 1",
            kind: .smartPlug,
            manufacturer: "TP-Link / Tapo",
            capabilities: [.power, .localNetwork],
            protocols: [.localWifi, .vendorCloud]
        ),
        inventoryDevice(
            "Tapo P100 - 2",
            kind: .smartPlug,
            manufacturer: "TP-Link / Tapo",
            capabilities: [.power, .localNetwork],
            protocols: [.localWifi, .vendorCloud]
        ),
        inventoryDevice(
            "MDV Split AC",
            kind: .airConditioner,
            manufacturer: "MDV / Midea",
            capabilities: [.power, .coolingMode, .fanSpeed, .temperatureReading],
            protocols: [.localWifi, .vendorCloud, .infrared]
        ),
        inventoryDevice(
            "Samsung Smart TV",
            kind: .smartTV,
            manufacturer: "Samsung",
            capabilities: [.power, .mediaControl, .hubBridge, .lightReading],
            protocols: [.localWifi, .vendorCloud, .infrared]
        )
    ]

    static let signals: [SignalEvent] = []
    static let rules: [AutomationRule] = []
    static let bridgeCommands: [BridgeCommand] = []

    static let frameworks: [FrameworkPlan] = [
        FrameworkPlan(name: "SwiftUI", purpose: "Adaptive iPhone and Mac Catalyst interface", status: "Active", symbol: "rectangle.stack"),
        FrameworkPlan(name: "HomeKit", purpose: "Import Apple Home rooms and accessories", status: "Import", symbol: "house"),
        FrameworkPlan(name: "MatterSupport", purpose: "System commissioning for compatible accessories", status: "Foundation", symbol: "point.3.connected.trianglepath.dotted"),
        FrameworkPlan(name: "AccessorySetupKit", purpose: "Privacy-preserving accessory setup", status: "Foundation", symbol: "sensor.tag.radiowaves.forward"),
        FrameworkPlan(name: "Core Bluetooth", purpose: "Nearby BLE discovery with user consent", status: "Active", symbol: "dot.radiowaves.left.and.right"),
        FrameworkPlan(name: "Network", purpose: "Bonjour discovery and local transports", status: "Active", symbol: "network"),
        FrameworkPlan(name: "Core ML", purpose: "On-device intelligence and classification", status: "Active", symbol: "brain"),
        FrameworkPlan(name: "Sound Analysis", purpose: "Local acoustic event processing", status: "Active", symbol: "waveform"),
        FrameworkPlan(name: "App Intents", purpose: "Shortcuts and Siri-ready actions", status: "Foundation", symbol: "command")
    ]

    static let brandAdapters: [BrandAdapterPlan] = [
        BrandAdapterPlan(
            brand: "Apple Home",
            ecosystem: "HomeKit and Matter accessories shared by Apple Home",
            stage: .ready,
            deviceKinds: DeviceKind.allCases,
            connectionPlan: "Import accessories and rooms after permission; physical writes still require adapter validation.",
            nextAction: "Use Import Apple Home from Add Device.",
            symbol: "house"
        ),
        BrandAdapterPlan(
            brand: "Samsung SmartThings",
            ecosystem: "Samsung TV, hubs, and linked SmartThings devices",
            stage: .scaffolded,
            deviceKinds: [.smartTV, .smartHub, .camera, .airConditioner, .purifier],
            connectionPlan: "Production import uses SmartThings OAuth with read and execute scopes.",
            nextAction: "Register the OAuth app and configure a secure callback service.",
            symbol: "tv"
        ),
        BrandAdapterPlan(
            brand: "TP-Link / Tapo",
            ecosystem: "Local Tapo lights, plugs, cameras, hub, and sensors",
            stage: .scaffolded,
            deviceKinds: [.normalLight, .dimmerLight, .colorLight, .camera, .smartHub, .climateSensor],
            connectionPlan: "Discover on the LAN, then authenticate locally where firmware permits third-party access.",
            nextAction: "Enable Third-Party Compatibility in Tapo where available.",
            symbol: "lightbulb.led"
        ),
        BrandAdapterPlan(
            brand: "Shelly",
            ecosystem: "Local Shelly Gen2+ relays, lights, sensors, and covers",
            stage: .scaffolded,
            deviceKinds: [.smartPlug, .normalLight, .dimmerLight, .climateSensor],
            connectionPlan: "Discover the documented _shelly._tcp service, then use authenticated local RPC.",
            nextAction: "Validate RPC authentication, state, commands, and reconnect on physical Shelly hardware.",
            symbol: "switch.2"
        ),
        BrandAdapterPlan(
            brand: "Xiaomi Home",
            ecosystem: "Xiaomi purifier and MiOT devices",
            stage: .planned,
            deviceKinds: [.purifier, .climateSensor, .lightSensor],
            connectionPlan: "Prefer Matter when exposed; otherwise use a user-authorized bridge.",
            nextAction: "Connect Xiaomi Home through Home Assistant or a supported MiOT route.",
            symbol: "wind"
        ),
        BrandAdapterPlan(
            brand: "Midea SmartHome",
            ecosystem: "MDV and Midea climate appliances",
            stage: .planned,
            deviceKinds: [.airConditioner],
            connectionPlan: "Use Matter when present, a bridge for vendor control, or the planned IR extension.",
            nextAction: "Identify the AC module model and supported local protocol.",
            symbol: "snowflake"
        ),
        BrandAdapterPlan(
            brand: "Electrolux",
            ecosystem: "Wellbeing air-care appliances",
            stage: .planned,
            deviceKinds: [.purifier],
            connectionPlan: "Use a supported account bridge until a public consumer API is available.",
            nextAction: "Validate the Wellbeing A5 account region and bridge compatibility.",
            symbol: "aqi.medium"
        ),
        BrandAdapterPlan(
            brand: "Home Assistant",
            ecosystem: "Optional bridge for vendor ecosystems and local integrations",
            stage: .scaffolded,
            deviceKinds: DeviceKind.allCases,
            connectionPlan: "Import normalized entities from a user-owned Home Assistant instance.",
            nextAction: "Add URL and a long-lived token in a future secure connection flow.",
            symbol: "homekit"
        )
    ]

    static let classifierSlots: [ClassifierSlot] = [
        ClassifierSlot(
            name: "Sound classifier",
            modelFile: "MySoundClassifier.mlmodel",
            input: "Microphone frames processed on device",
            outputs: ["Acoustic event classes"],
            nextAction: "Calibrate labels with real household recordings before automation use."
        )
    ]

    private static func inventoryDevice(
        _ name: String,
        kind: DeviceKind,
        manufacturer: String,
        capabilities: [DeviceCapability],
        protocols: [DeviceProtocol]
    ) -> SmartDevice {
        SmartDevice(
            name: name,
            room: "Unassigned",
            kind: kind,
            manufacturer: manufacturer,
            protocols: protocols,
            capabilities: capabilities,
            isOnline: false,
            isOn: false,
            brightness: capabilities.contains(.brightness) ? 0 : nil,
            colorName: capabilities.contains(.color) ? "White" : nil,
            temperature: nil,
            humidity: nil,
            lux: nil,
            airQualityIndex: nil,
            note: "Inventory record. Connect or import this device to enable live state.",
            fanSpeed: capabilities.contains(.fanSpeed) ? 0 : nil,
            targetTemperature: kind == .airConditioner ? 24 : nil,
            mode: kind == .airConditioner || kind == .purifier ? "Auto" : nil
        )
    }
}
