import XCTest
@testable import SmartHomeConductor

final class AppStoreTests: XCTestCase {
    @MainActor
    func testSceneDoesNotClaimExecutionWithoutConnectedEndpoints() {
        let store = makeStore()

        let report = store.runScene(.allOff)

        XCTAssertEqual(report.eligibleDevices, 0)
        XCTAssertEqual(report.updatedDevices, 0)
        XCTAssertEqual(report.blockedDevices, 0)
        XCTAssertNil(store.activeScene)
        XCTAssertTrue(report.message.contains("was not run"))
    }

    @MainActor
    func testInventoryContainsNoFakeOnlineDevices() {
        let store = makeStore()

        XCTAssertEqual(store.devices.count, 13)
        XCTAssertTrue(store.devices.allSatisfy { !$0.isOnline })
        XCTAssertTrue(store.devices.contains { $0.name == "Xiaomi Air Purifier 4 Compact" })
        XCTAssertEqual(store.devices.filter { $0.name.hasPrefix("Tapo P100") }.count, 2)
    }

    @MainActor
    func testEnvironmentalSummaryIsEmptyUntilSensorsConnect() {
        let store = makeStore()
        let summary = store.environmentalSummary

        XCTAssertNil(summary.temperature)
        XCTAssertNil(summary.humidity)
        XCTAssertNil(summary.illuminance)
        XCTAssertNil(summary.airQualityIndex)
        XCTAssertEqual(summary.onlineSensors, 0)
    }

    @MainActor
    func testLocalAssistantRefusesDisconnectedControl() throws {
        let store = makeStore()
        let device = try XCTUnwrap(store.devices.first { $0.name == "Tapo L530" })

        let response = store.executeLocalAssistantCommand("Turn Tapo L530 on")

        XCTAssertTrue(response?.contains("offline") == true)
        XCTAssertTrue(response?.contains("No command was sent") == true)
        XCTAssertFalse(store.device(id: device.id)?.isOn ?? true)
        XCTAssertEqual(store.commandAudits.first?.outcome, .rejected)
    }

    @MainActor
    func testManualDeviceCanBeAddedAndDeleted() throws {
        let store = makeStore()

        store.addDevice(
            name: "Workshop relay",
            room: "Workshop",
            kind: .smartPlug,
            manufacturer: "DIY"
        )

        let device = try XCTUnwrap(store.devices.first { $0.name == "Workshop relay" })
        XCTAssertEqual(device.room, "Workshop")
        XCTAssertFalse(device.isOnline)

        store.deleteDevice(device.id)
        XCTAssertNil(store.device(id: device.id))
    }

    @MainActor
    func testAssistantLightControlRequiresPermissionOrConfirmation() throws {
        let store = makeStore()
        let device = onlineLight()
        store.addDevice(device)

        let result = store.executeCommand(
            .setPower(true),
            for: device.id,
            origin: .assistant
        )

        XCTAssertEqual(result.outcome, .confirmationRequired)
        XCTAssertFalse(try XCTUnwrap(store.device(id: device.id)).isOn)
        XCTAssertEqual(store.commandAudits.first?.outcome, .confirmationRequired)
    }

    @MainActor
    func testConfirmedAssistantLightControlWithoutTransportIsBlocked() throws {
        let store = makeStore()
        let device = onlineLight()
        store.addDevice(device)

        let result = store.executeCommand(
            .setPower(true),
            for: device.id,
            origin: .assistant,
            confirmed: true
        )

        XCTAssertEqual(result.outcome, .transportUnavailable)
        XCTAssertFalse(try XCTUnwrap(store.device(id: device.id)).isOn)
        XCTAssertEqual(store.commandAudits.first?.origin, .assistant)
        XCTAssertEqual(store.commandAudits.first?.outcome, .transportUnavailable)
    }

    @MainActor
    func testAssistantSceneCannotBypassSmartPlugConfirmation() throws {
        let store = makeStore()
        let plug = SmartDevice(
            name: "Connected test plug",
            room: "Lab",
            kind: .smartPlug,
            manufacturer: "Test",
            protocols: [.localWifi],
            capabilities: [.power],
            isOnline: true,
            isOn: true,
            brightness: nil,
            colorName: nil,
            temperature: nil,
            humidity: nil,
            lux: nil,
            airQualityIndex: nil,
            note: "Test endpoint"
        )
        store.addDevice(plug)
        let previousUpdate = plug.lastUpdated

        let report = store.runScene(.allOff, origin: .assistant)

        XCTAssertEqual(report.eligibleDevices, 1)
        XCTAssertEqual(report.updatedDevices, 0)
        XCTAssertEqual(report.blockedDevices, 1)
        XCTAssertTrue(try XCTUnwrap(store.device(id: plug.id)).isOn)
        XCTAssertEqual(
            try XCTUnwrap(store.device(id: plug.id)).lastUpdated,
            previousUpdate
        )
        XCTAssertEqual(store.commandAudits.first?.outcome, .confirmationRequired)
    }

    @MainActor
    func testUserSceneDoesNotFakeStateWithoutSceneTransport() throws {
        let store = makeStore()
        let light = onlineLight()
        store.addDevice(light)

        let report = store.runScene(.arrive)

        XCTAssertEqual(report.eligibleDevices, 1)
        XCTAssertEqual(report.updatedDevices, 0)
        XCTAssertEqual(report.blockedDevices, 1)
        XCTAssertFalse(try XCTUnwrap(store.device(id: light.id)).isOn)
        XCTAssertEqual(store.commandAudits.first?.outcome, .transportUnavailable)
    }

    @MainActor
    func testHVACExtremeRequiresConfirmation() {
        let policy = CommandAuthorizationPolicy()
        var device = SmartDevice(
            name: "Test AC",
            room: "Lab",
            kind: .airConditioner,
            manufacturer: "Test",
            protocols: [.localWifi],
            capabilities: [.power, .coolingMode],
            isOnline: true,
            isOn: true,
            brightness: nil,
            colorName: nil,
            temperature: 23,
            humidity: nil,
            lux: nil,
            airQualityIndex: nil,
            note: "Test endpoint"
        )
        device.targetTemperature = 23

        let decision = policy.evaluate(
            command: .setTargetTemperature(12),
            device: device,
            origin: .assistant,
            isConfirmed: false,
            assistantLightControlAllowed: false
        )

        guard case .requireConfirmation = decision else {
            return XCTFail("Expected sensitive HVAC command to require confirmation")
        }
    }

    @MainActor
    func testConfigurationExportImportRoundTrip() throws {
        let store = makeStore()
        store.addDevice(
            name: "Exported relay",
            room: "Utility",
            kind: .smartPlug,
            manufacturer: "DIY"
        )
        let exported = try store.exportConfiguration()

        store.clearHome()
        XCTAssertTrue(store.devices.isEmpty)

        try store.importConfiguration(exported)
        XCTAssertTrue(store.devices.contains { $0.name == "Exported relay" })
        XCTAssertEqual(store.devices.count, 14)
    }

    @MainActor
    func testSwiftDataStateSurvivesStoreRecreation() throws {
        let container = try AppModelContainer.makeInMemory()
        let suiteName = "AppStoreTests.Persistence.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)

        let first = AppStore(
            defaults: defaults,
            modelContainer: container,
            persistenceMode: .swiftData
        )
        first.addDevice(
            name: "Persistent meter",
            room: "Panel",
            kind: .climateSensor,
            manufacturer: "Test"
        )

        let second = AppStore(
            defaults: defaults,
            modelContainer: container,
            persistenceMode: .swiftData
        )

        XCTAssertTrue(second.devices.contains { $0.name == "Persistent meter" })
        XCTAssertEqual(second.persistenceMode, .swiftData)
    }

    func testInMemoryCredentialStoreRoundTrip() throws {
        let store = InMemoryCredentialStore()
        let secret = Data("secret".utf8)

        try store.save(secret, reference: "adapter/test")
        XCTAssertEqual(try store.read(reference: "adapter/test"), secret)

        try store.delete(reference: "adapter/test")
        XCTAssertNil(try store.read(reference: "adapter/test"))
    }

    @MainActor
    func testTapoAdviceDoesNotRepeatCompatibilitySwitch() throws {
        let store = makeStore()

        let advice = try XCTUnwrap(store.connectionAdvice(for: "Connect my Tapo devices"))

        XCTAssertFalse(advice.contains("Enable Third-Party Compatibility"))
        XCTAssertTrue(advice.contains("will not ask you to enable"))
        XCTAssertTrue(advice.contains("https://www.tapo.com/en/faq/714/"))
    }

    func testHomeAssistantURLValidationProtectsRemoteCredentials() throws {
        let defaults = try XCTUnwrap(
            UserDefaults(suiteName: "HomeAssistantURLTests.\(UUID().uuidString)")
        )
        let api = HomeAssistantAPI(
            credentialStore: InMemoryCredentialStore(),
            defaults: defaults
        )

        XCTAssertEqual(
            try api.normalizedBaseURL("homeassistant.local:8123").absoluteString,
            "http://homeassistant.local:8123"
        )
        XCTAssertEqual(
            try api.normalizedBaseURL("http://192.168.1.20:8123").host,
            "192.168.1.20"
        )
        XCTAssertThrowsError(try api.normalizedBaseURL("http://example.com:8123")) {
            XCTAssertEqual($0 as? HomeAssistantError, .insecureRemoteURL)
        }
        XCTAssertEqual(
            try api.normalizedBaseURL("https://example.com").scheme,
            "https"
        )
    }

    @MainActor
    func testHomeAssistantMapsLiveTapoLight() throws {
        let state = HomeAssistantState(
            entityID: "light.tapo_l530",
            state: "on",
            attributes: HomeAssistantState.Attributes(
                friendlyName: "Tapo L530",
                deviceClass: nil,
                areaName: "Studio",
                brightness: 128,
                rgbColor: [255, 100, 30],
                colorMode: "rgb",
                supportedColorModes: ["rgb", "color_temp"],
                currentTemperature: nil,
                temperature: nil,
                currentHumidity: nil,
                humidity: nil,
                percentage: nil,
                batteryLevel: nil,
                unitOfMeasurement: nil
            ),
            lastUpdated: .now
        )

        let device = try XCTUnwrap(HomeAssistantController.devices(from: [state]).first)

        XCTAssertEqual(device.name, "Tapo L530")
        XCTAssertEqual(device.manufacturer, "TP-Link / Tapo")
        XCTAssertEqual(device.kind, .colorLight)
        XCTAssertEqual(device.room, "Studio")
        XCTAssertTrue(device.isOnline)
        XCTAssertTrue(device.isOn)
        XCTAssertEqual(device.integrationID, HomeAssistantController.integrationID)
        XCTAssertEqual(device.externalID, "light.tapo_l530")
        XCTAssertTrue(device.capabilities.contains(.color))
    }

    @MainActor
    func testHomeAssistantImportUpdatesSameEntityInsteadOfDuplicating() throws {
        let store = makeStore()
        var first = onlineLight()
        first.name = "Tapo L530"
        first.manufacturer = "TP-Link / Tapo"
        first.integrationID = HomeAssistantController.integrationID
        first.externalID = "light.tapo_l530"

        store.importHomeAssistantDevices([first])
        var refreshed = first
        refreshed.isOn = true
        refreshed.brightness = 62
        store.importHomeAssistantDevices([refreshed])

        let matches = store.devices.filter { $0.externalID == "light.tapo_l530" }
        XCTAssertEqual(matches.count, 1)
        XCTAssertTrue(try XCTUnwrap(matches.first).isOn)
        XCTAssertEqual(try XCTUnwrap(matches.first).brightness, 62)
    }

    func testHomeAssistantSendsAuthenticatedCommandAndReadsConfirmedState() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [HomeAssistantURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let defaults = try XCTUnwrap(
            UserDefaults(suiteName: "HomeAssistantTransportTests.\(UUID().uuidString)")
        )
        let api = HomeAssistantAPI(
            session: session,
            credentialStore: InMemoryCredentialStore(),
            defaults: defaults
        )
        HomeAssistantURLProtocol.responder.setHandler { request in
            guard request.value(forHTTPHeaderField: "Authorization") == "Bearer valid-token" else {
                return (401, Data())
            }
            let method = request.httpMethod ?? ""
            let path = request.url?.path ?? ""
            if method == "GET", request.url?.absoluteString.hasSuffix("/api/") == true {
                return (200, Data(#"{"message":"API running."}"#.utf8))
            }
            if method == "POST", path == "/api/services/light/turn_on" {
                let body = try XCTUnwrap(HomeAssistantURLProtocol.bodyData(for: request))
                let payload = try XCTUnwrap(
                    JSONSerialization.jsonObject(with: body) as? [String: Any]
                )
                XCTAssertEqual(payload["entity_id"] as? String, "light.tapo_l530")
                XCTAssertEqual(payload["brightness_pct"] as? Int, 72)
                return (200, Data("[]".utf8))
            }
            if method == "GET", path == "/api/states/light.tapo_l530" {
                return (
                    200,
                    Data(
                        #"""
                        {
                          "entity_id": "light.tapo_l530",
                          "state": "on",
                          "last_updated": "2026-07-25T06:20:10.123456+00:00",
                          "attributes": {
                            "friendly_name": "Tapo L530",
                            "brightness": 184,
                            "supported_color_modes": ["rgb", "color_temp"]
                          }
                        }
                        """#.utf8
                    )
                )
            }
            XCTFail(
                "Unexpected Home Assistant request: [\(method)] [\(path)] \(request.url?.absoluteString ?? "nil")"
            )
            return (404, Data())
        }
        defer { HomeAssistantURLProtocol.responder.setHandler(nil) }

        let baseURL = try api.normalizedBaseURL("http://homeassistant.local:8123")
        try await api.validate(baseURL: baseURL, token: "valid-token")
        let confirmed = try await api.execute(
            baseURL: baseURL,
            token: "valid-token",
            entityID: "light.tapo_l530",
            command: .setBrightness(72)
        )

        XCTAssertEqual(confirmed.entityID, "light.tapo_l530")
        XCTAssertEqual(confirmed.state, "on")
        XCTAssertEqual(confirmed.attributes.brightness, 184)
        XCTAssertNotNil(confirmed.lastUpdated)
    }

    @MainActor
    private func makeStore() -> AppStore {
        let suiteName = "AppStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return AppStore(defaults: defaults)
    }

    private func onlineLight() -> SmartDevice {
        SmartDevice(
            name: "Test connected light",
            room: "Lab",
            kind: .colorLight,
            manufacturer: "Test",
            protocols: [.homeKit],
            capabilities: [.power, .brightness, .color],
            isOnline: true,
            isOn: false,
            brightness: 0,
            colorName: "White",
            temperature: nil,
            humidity: nil,
            lux: nil,
            airQualityIndex: nil,
            note: "Test endpoint"
        )
    }
}

private final class HomeAssistantURLProtocol: URLProtocol, @unchecked Sendable {
    static let responder = Responder()

    final class Responder: @unchecked Sendable {
        typealias Handler = @Sendable (URLRequest) throws -> (Int, Data)

        private let lock = NSLock()
        private var handler: Handler?

        func setHandler(_ handler: Handler?) {
            lock.withLock {
                self.handler = handler
            }
        }

        func response(for request: URLRequest) throws -> (Int, Data) {
            let current = lock.withLock { handler }
            guard let current else {
                return (500, Data())
            }
            return try current(request)
        }
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    static func bodyData(for request: URLRequest) -> Data? {
        if let body = request.httpBody {
            return body
        }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufferSize = 1_024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let count = stream.read(buffer, maxLength: bufferSize)
            guard count >= 0 else { return nil }
            if count == 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }

    override func startLoading() {
        do {
            let (status, data) = try Self.responder.response(for: request)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: status,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
