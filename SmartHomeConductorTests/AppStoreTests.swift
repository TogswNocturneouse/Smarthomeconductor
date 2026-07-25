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
    func testConfirmedAssistantLightControlCreatesAudit() throws {
        let store = makeStore()
        let device = onlineLight()
        store.addDevice(device)

        let result = store.executeCommand(
            .setPower(true),
            for: device.id,
            origin: .assistant,
            confirmed: true
        )

        XCTAssertEqual(result.outcome, .localStateUpdated)
        XCTAssertTrue(try XCTUnwrap(store.device(id: device.id)).isOn)
        XCTAssertEqual(store.commandAudits.first?.origin, .assistant)
        XCTAssertEqual(store.commandAudits.first?.outcome, .localStateUpdated)
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
