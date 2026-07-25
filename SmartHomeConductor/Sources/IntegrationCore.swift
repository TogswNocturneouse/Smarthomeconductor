import Foundation

protocol BrandDeviceAdapter: Sendable {
    var brand: String { get }
    func discover() async -> [DiscoveredAccessory]
}

struct PreviewBrandAdapter: BrandDeviceAdapter {
    let brand: String
    let accessories: [DiscoveredAccessory]

    func discover() async -> [DiscoveredAccessory] {
        try? await Task.sleep(for: .milliseconds(650))
        return accessories
    }
}

actor AdapterRegistry {
    static let preview = AdapterRegistry(adapters: [
        PreviewBrandAdapter(
            brand: "TP-Link / Tapo",
            accessories: [
                DiscoveredAccessory(id: "tapo-l530", name: "Tapo color light", kind: .colorLight),
                DiscoveredAccessory(id: "tapo-cam", name: "Tapo camera", kind: .camera)
            ]
        ),
        PreviewBrandAdapter(
            brand: "MDV / Midea",
            accessories: [
                DiscoveredAccessory(id: "midea-ac", name: "Midea climate", kind: .airConditioner)
            ]
        ),
        PreviewBrandAdapter(
            brand: "Xiaomi",
            accessories: [
                DiscoveredAccessory(id: "xiaomi-sensor", name: "Xiaomi climate sensor", kind: .climateSensor),
                DiscoveredAccessory(id: "xiaomi-purifier", name: "Xiaomi purifier", kind: .purifier)
            ]
        ),
        PreviewBrandAdapter(
            brand: "Electrolux",
            accessories: [
                DiscoveredAccessory(id: "electrolux-air", name: "Electrolux air care", kind: .purifier)
            ]
        ),
        PreviewBrandAdapter(
            brand: "Samsung",
            accessories: [
                DiscoveredAccessory(id: "samsung-tv", name: "Samsung Smart TV", kind: .smartTV),
                DiscoveredAccessory(id: "smartthings-hub", name: "SmartThings Hub", kind: .smartHub)
            ]
        ),
        PreviewBrandAdapter(
            brand: "Shelly",
            accessories: [
                DiscoveredAccessory(id: "shelly-dimmer", name: "Shelly Dimmer", kind: .dimmerLight),
                DiscoveredAccessory(id: "shelly-relay", name: "Shelly Relay", kind: .normalLight)
            ]
        )
    ])

    private let adapters: [String: any BrandDeviceAdapter]

    init(adapters: [any BrandDeviceAdapter]) {
        self.adapters = Dictionary(uniqueKeysWithValues: adapters.map { ($0.brand, $0) })
    }

    func discover(brand: String) async -> [DiscoveredAccessory] {
        guard let adapter = adapters[brand] else { return [] }
        return await adapter.discover()
    }
}
