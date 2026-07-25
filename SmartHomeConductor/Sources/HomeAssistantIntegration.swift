import Foundation

enum HomeAssistantError: LocalizedError, Equatable {
    case invalidURL
    case insecureRemoteURL
    case notConfigured
    case unauthorized
    case unavailable(Int)
    case invalidResponse
    case unsupportedCommand

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Enter a valid Home Assistant address, such as http://homeassistant.local:8123."
        case .insecureRemoteURL:
            "Plain HTTP is allowed only for local-network addresses. Use HTTPS for a remote address."
        case .notConfigured:
            "Connect Home Assistant before importing or controlling devices."
        case .unauthorized:
            "Home Assistant rejected the token. Create a new long-lived access token in your Home Assistant profile."
        case let .unavailable(status):
            "Home Assistant returned HTTP \(status)."
        case .invalidResponse:
            "Home Assistant returned an unreadable response."
        case .unsupportedCommand:
            "This Home Assistant entity does not support that command."
        }
    }
}

struct HomeAssistantState: Decodable, Sendable {
    struct Attributes: Decodable, Sendable {
        var friendlyName: String? = nil
        var deviceClass: String? = nil
        var areaName: String? = nil
        var brightness: Double? = nil
        var rgbColor: [Double]? = nil
        var colorMode: String? = nil
        var supportedColorModes: [String]? = nil
        var currentTemperature: Double? = nil
        var temperature: Double? = nil
        var currentHumidity: Double? = nil
        var humidity: Double? = nil
        var percentage: Double? = nil
        var batteryLevel: Double? = nil
        var unitOfMeasurement: String? = nil

        private enum CodingKeys: String, CodingKey {
            case friendlyName = "friendly_name"
            case deviceClass = "device_class"
            case areaName = "area_name"
            case brightness
            case rgbColor = "rgb_color"
            case colorMode = "color_mode"
            case supportedColorModes = "supported_color_modes"
            case currentTemperature = "current_temperature"
            case temperature
            case currentHumidity = "current_humidity"
            case humidity
            case percentage
            case batteryLevel = "battery_level"
            case unitOfMeasurement = "unit_of_measurement"
        }
    }

    let entityID: String
    let state: String
    let attributes: Attributes
    let lastUpdated: Date?

    private enum CodingKeys: String, CodingKey {
        case entityID = "entity_id"
        case state
        case attributes
        case lastUpdated = "last_updated"
    }

    init(
        entityID: String,
        state: String,
        attributes: Attributes,
        lastUpdated: Date?
    ) {
        self.entityID = entityID
        self.state = state
        self.attributes = attributes
        self.lastUpdated = lastUpdated
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        entityID = try values.decode(String.self, forKey: .entityID)
        state = try values.decode(String.self, forKey: .state)
        attributes = try values.decodeIfPresent(Attributes.self, forKey: .attributes)
            ?? Attributes()
        if let text = try values.decodeIfPresent(String.self, forKey: .lastUpdated) {
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            lastUpdated = fractional.date(from: text) ?? ISO8601DateFormatter().date(from: text)
        } else {
            lastUpdated = nil
        }
    }
}

struct HomeAssistantAPI: @unchecked Sendable {
    var session: URLSession
    var credentialStore: any IntegrationCredentialStore
    var defaults: UserDefaults

    static let baseURLKey = "conductor.integration.homeassistant.baseURL"
    static let tokenReference = "homeassistant.long-lived-token"

    init(
        session: URLSession = .shared,
        credentialStore: any IntegrationCredentialStore = KeychainCredentialStore(),
        defaults: UserDefaults = .standard
    ) {
        self.session = session
        self.credentialStore = credentialStore
        self.defaults = defaults
    }

    func normalizedBaseURL(_ value: String) throws -> URL {
        var text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw HomeAssistantError.invalidURL }
        if !text.contains("://") {
            text = "http://\(text)"
        }

        guard
            var components = URLComponents(string: text),
            let scheme = components.scheme?.lowercased(),
            ["http", "https"].contains(scheme),
            let host = components.host,
            !host.isEmpty
        else {
            throw HomeAssistantError.invalidURL
        }

        if scheme == "http", !Self.isLocalHost(host) {
            throw HomeAssistantError.insecureRemoteURL
        }

        components.path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.query = nil
        components.fragment = nil
        guard let url = components.url else { throw HomeAssistantError.invalidURL }
        return url
    }

    func validate(baseURL: URL, token: String) async throws {
        _ = try await request(
            baseURL: baseURL,
            token: token,
            path: "/api/",
            method: "GET",
            body: nil
        )
    }

    func states(baseURL: URL, token: String) async throws -> [HomeAssistantState] {
        let data = try await request(
            baseURL: baseURL,
            token: token,
            path: "/api/states",
            method: "GET",
            body: nil
        )
        let decoder = JSONDecoder()
        guard let states = try? decoder.decode([HomeAssistantState].self, from: data) else {
            throw HomeAssistantError.invalidResponse
        }
        return states
    }

    func state(baseURL: URL, token: String, entityID: String) async throws -> HomeAssistantState {
        let encoded = entityID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
            ?? entityID
        let data = try await request(
            baseURL: baseURL,
            token: token,
            path: "/api/states/\(encoded)",
            method: "GET",
            body: nil
        )
        let decoder = JSONDecoder()
        guard let state = try? decoder.decode(HomeAssistantState.self, from: data) else {
            throw HomeAssistantError.invalidResponse
        }
        return state
    }

    func execute(
        baseURL: URL,
        token: String,
        entityID: String,
        command: DeviceCommand
    ) async throws -> HomeAssistantState {
        let domain = entityID.split(separator: ".", maxSplits: 1).first.map(String.init) ?? ""
        let action = try Self.action(for: command, domain: domain)
        var payload = action.payload
        payload["entity_id"] = entityID
        let body = try JSONSerialization.data(withJSONObject: payload)
        _ = try await request(
            baseURL: baseURL,
            token: token,
            path: "/api/services/\(domain)/\(action.service)",
            method: "POST",
            body: body
        )
        try await Task.sleep(for: .milliseconds(180))
        return try await state(baseURL: baseURL, token: token, entityID: entityID)
    }

    private func request(
        baseURL: URL,
        token: String,
        path: String,
        method: String,
        body: Data?
    ) async throws -> Data {
        guard let url = URL(string: path, relativeTo: baseURL)?.absoluteURL else {
            throw HomeAssistantError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.timeoutInterval = 12
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw HomeAssistantError.invalidResponse
        }
        if response.statusCode == 401 {
            throw HomeAssistantError.unauthorized
        }
        guard (200...299).contains(response.statusCode) else {
            throw HomeAssistantError.unavailable(response.statusCode)
        }
        return data
    }

    private static func action(
        for command: DeviceCommand,
        domain: String
    ) throws -> (service: String, payload: [String: Any]) {
        switch command {
        case let .setPower(isOn):
            guard ["light", "switch", "fan", "climate", "media_player"].contains(domain) else {
                throw HomeAssistantError.unsupportedCommand
            }
            return (isOn ? "turn_on" : "turn_off", [:])
        case let .setBrightness(value):
            guard domain == "light" else { throw HomeAssistantError.unsupportedCommand }
            return ("turn_on", ["brightness_pct": Int(value.rounded())])
        case let .setColor(name):
            guard domain == "light" else { throw HomeAssistantError.unsupportedCommand }
            return ("turn_on", ["rgb_color": rgb(for: name)])
        case let .setFanSpeed(value):
            guard domain == "fan" else { throw HomeAssistantError.unsupportedCommand }
            return ("set_percentage", ["percentage": Int((value * 20).rounded())])
        case let .setTargetTemperature(value):
            guard domain == "climate" else { throw HomeAssistantError.unsupportedCommand }
            return ("set_temperature", ["temperature": value])
        case let .setMode(mode):
            guard domain == "climate" else { throw HomeAssistantError.unsupportedCommand }
            let value = mode.lowercased() == "fan" ? "fan_only" : mode.lowercased()
            return ("set_hvac_mode", ["hvac_mode": value])
        }
    }

    private static func rgb(for name: String) -> [Int] {
        switch name.lowercased() {
        case "amber": [255, 166, 38]
        case "blue": [52, 132, 255]
        case "green": [66, 214, 118]
        case "rose": [255, 80, 124]
        case "violet": [151, 96, 255]
        default: [255, 255, 255]
        }
    }

    private static func isLocalHost(_ host: String) -> Bool {
        let value = host.lowercased()
        if value == "localhost" || value.hasSuffix(".local") { return true }
        if value == "::1" { return true }
        let octets = value.split(separator: ".").compactMap { Int($0) }
        guard octets.count == 4, octets.allSatisfy({ (0...255).contains($0) }) else {
            return false
        }
        return octets[0] == 10 ||
            octets[0] == 127 ||
            (octets[0] == 192 && octets[1] == 168) ||
            (octets[0] == 172 && (16...31).contains(octets[1]))
    }
}

@MainActor
final class HomeAssistantController: ObservableObject {
    static let integrationID = "homeassistant"

    @Published private(set) var isWorking = false
    @Published private(set) var isConnected = false
    @Published private(set) var status = "Not connected"
    @Published private(set) var lastError: String?
    @Published private(set) var lastImportCount = 0

    private let api: HomeAssistantAPI

    var savedAddress: String {
        api.defaults.string(forKey: HomeAssistantAPI.baseURLKey) ?? ""
    }

    init(api: HomeAssistantAPI = HomeAssistantAPI()) {
        self.api = api
        let hasAddress = api.defaults.string(forKey: HomeAssistantAPI.baseURLKey) != nil
        let hasToken = (try? api.credentialStore.read(
            reference: HomeAssistantAPI.tokenReference
        )) != nil
        if hasAddress, hasToken {
            status = "Saved connection ready"
        }
    }

    func connect(address: String, token: String) async throws -> [SmartDevice] {
        isWorking = true
        lastError = nil
        defer { isWorking = false }

        do {
            let baseURL = try api.normalizedBaseURL(address)
            let cleanToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanToken.isEmpty else { throw HomeAssistantError.unauthorized }
            try await api.validate(baseURL: baseURL, token: cleanToken)
            let states = try await api.states(baseURL: baseURL, token: cleanToken)
            try api.credentialStore.save(
                Data(cleanToken.utf8),
                reference: HomeAssistantAPI.tokenReference
            )
            api.defaults.set(baseURL.absoluteString, forKey: HomeAssistantAPI.baseURLKey)
            isConnected = true
            let devices = Self.devices(from: states)
            lastImportCount = devices.count
            status = "Connected - \(devices.count) supported entities found"
            return devices
        } catch {
            isConnected = false
            lastError = error.localizedDescription
            status = error.localizedDescription
            throw error
        }
    }

    func reconnectAndImport() async throws -> [SmartDevice] {
        isWorking = true
        lastError = nil
        defer { isWorking = false }

        do {
            let (baseURL, token) = try configuration()
            try await api.validate(baseURL: baseURL, token: token)
            let states = try await api.states(baseURL: baseURL, token: token)
            let devices = Self.devices(from: states)
            isConnected = true
            lastImportCount = devices.count
            status = "Connected - \(devices.count) supported entities found"
            return devices
        } catch {
            isConnected = false
            lastError = error.localizedDescription
            status = error.localizedDescription
            throw error
        }
    }

    func execute(_ command: DeviceCommand, device: SmartDevice) async throws -> SmartDevice {
        guard
            device.integrationID == Self.integrationID,
            let entityID = device.externalID
        else {
            throw HomeAssistantError.unsupportedCommand
        }
        let (baseURL, token) = try configuration()
        let state = try await api.execute(
            baseURL: baseURL,
            token: token,
            entityID: entityID,
            command: command
        )
        isConnected = true
        status = "Connected"
        return Self.device(from: state, existing: device)
    }

    func disconnect() {
        try? api.credentialStore.delete(reference: HomeAssistantAPI.tokenReference)
        api.defaults.removeObject(forKey: HomeAssistantAPI.baseURLKey)
        isConnected = false
        lastImportCount = 0
        lastError = nil
        status = "Not connected"
    }

    private func configuration() throws -> (URL, String) {
        guard
            let address = api.defaults.string(forKey: HomeAssistantAPI.baseURLKey),
            let data = try api.credentialStore.read(
                reference: HomeAssistantAPI.tokenReference
            ),
            let token = String(data: data, encoding: .utf8)
        else {
            throw HomeAssistantError.notConfigured
        }
        return (try api.normalizedBaseURL(address), token)
    }

    static func devices(from states: [HomeAssistantState]) -> [SmartDevice] {
        states.compactMap { state in
            guard supportedDomains.contains(domain(of: state.entityID)) else { return nil }
            return device(from: state)
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    static func device(
        from state: HomeAssistantState,
        existing: SmartDevice? = nil
    ) -> SmartDevice {
        let domain = domain(of: state.entityID)
        let kind = kind(for: state, domain: domain)
        let capabilities = capabilities(for: state, domain: domain)
        let isOnline = !["unavailable", "unknown"].contains(state.state.lowercased())
        let brightness = state.attributes.brightness.map {
            min(max(($0 / 255) * 100, 0), 100)
        }
        let sensorValue = Double(state.state)
        let deviceClass = state.attributes.deviceClass?.lowercased()

        return SmartDevice(
            id: existing?.id ?? UUID(),
            name: state.attributes.friendlyName ?? state.entityID,
            room: existing?.room ?? state.attributes.areaName ?? "Unassigned",
            kind: kind,
            manufacturer: manufacturer(for: state),
            protocols: [.localWifi],
            capabilities: capabilities,
            isOnline: isOnline,
            isOn: ["on", "playing", "cool", "heat", "auto", "dry", "fan_only"]
                .contains(state.state.lowercased()),
            brightness: brightness,
            colorName: existing?.colorName,
            temperature: deviceClass == "temperature"
                ? sensorValue
                : state.attributes.currentTemperature,
            humidity: deviceClass == "humidity"
                ? sensorValue
                : state.attributes.currentHumidity ?? state.attributes.humidity,
            lux: deviceClass == "illuminance" ? sensorValue : nil,
            airQualityIndex: ["aqi", "air_quality_index"].contains(deviceClass ?? "")
                ? sensorValue.map(Int.init)
                : nil,
            note: "Live Home Assistant entity: \(state.entityID)",
            fanSpeed: state.attributes.percentage.map { $0 / 20 },
            targetTemperature: state.attributes.temperature,
            mode: domain == "climate" ? state.state.capitalized : nil,
            batteryLevel: deviceClass == "battery"
                ? sensorValue.map(Int.init)
                : state.attributes.batteryLevel.map(Int.init),
            lastUpdated: state.lastUpdated ?? .now,
            integrationID: integrationID,
            externalID: state.entityID
        )
    }

    private static let supportedDomains: Set<String> = [
        "light", "switch", "sensor", "binary_sensor", "fan", "climate",
        "camera", "media_player"
    ]

    private static func domain(of entityID: String) -> String {
        entityID.split(separator: ".", maxSplits: 1).first.map(String.init) ?? ""
    }

    private static func kind(for state: HomeAssistantState, domain: String) -> DeviceKind {
        switch domain {
        case "light":
            let modes = state.attributes.supportedColorModes ?? []
            if modes.contains(where: { ["rgb", "rgbw", "rgbww", "hs", "xy"].contains($0) }) {
                return .colorLight
            }
            return .dimmerLight
        case "switch":
            return .smartPlug
        case "fan":
            return .purifier
        case "climate":
            return .airConditioner
        case "camera":
            return .camera
        case "media_player":
            return .smartTV
        case "sensor":
            if state.attributes.deviceClass == "illuminance" { return .lightSensor }
            return .climateSensor
        default:
            return .climateSensor
        }
    }

    private static func capabilities(
        for state: HomeAssistantState,
        domain: String
    ) -> [DeviceCapability] {
        switch domain {
        case "light":
            var values: [DeviceCapability] = [.power, .brightness, .localNetwork]
            let modes = state.attributes.supportedColorModes ?? []
            if modes.contains(where: { ["rgb", "rgbw", "rgbww", "hs", "xy"].contains($0) }) {
                values.append(.color)
            }
            if modes.contains("color_temp") { values.append(.whiteTemperature) }
            return values
        case "switch":
            return [.power, .localNetwork]
        case "fan":
            return [.power, .fanSpeed, .airQuality, .localNetwork]
        case "climate":
            return [.power, .coolingMode, .temperatureReading, .fanSpeed, .localNetwork]
        case "camera":
            return [.cameraStream, .localNetwork]
        case "media_player":
            return [.power, .mediaControl, .localNetwork]
        case "sensor":
            switch state.attributes.deviceClass {
            case "temperature": return [.temperatureReading, .localNetwork]
            case "humidity": return [.humidityReading, .localNetwork]
            case "illuminance": return [.lightReading, .localNetwork]
            case "aqi", "air_quality_index": return [.airQuality, .localNetwork]
            default: return [.localNetwork]
            }
        default:
            return [.localNetwork]
        }
    }

    private static func manufacturer(for state: HomeAssistantState) -> String {
        let text = "\(state.entityID) \(state.attributes.friendlyName ?? "")".lowercased()
        if text.contains("tapo") || text.contains("tp_link") { return "TP-Link / Tapo" }
        if text.contains("xiaomi") || text.contains("zhimi") { return "Xiaomi" }
        if text.contains("midea") || text.contains("mdv") { return "MDV / Midea" }
        if text.contains("electrolux") { return "Electrolux" }
        if text.contains("samsung") { return "Samsung" }
        if text.contains("shelly") { return "Shelly" }
        return "Home Assistant"
    }
}
