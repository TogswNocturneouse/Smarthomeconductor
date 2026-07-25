import XCTest
@testable import SmartHomeConductor

final class AppStoreTests: XCTestCase {
    @MainActor
    func testAllOffSceneUpdatesPowerEndpoints() {
        let store = makeStore()

        store.runScene(.allOff)

        XCTAssertTrue(
            store.devices
                .filter { $0.capabilities.contains(.power) }
                .allSatisfy { !$0.isOn }
        )
        XCTAssertEqual(store.activeScene, .allOff)
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

        XCTAssertTrue(response?.contains("not connected") == true)
        XCTAssertFalse(store.device(id: device.id)?.isOn ?? true)
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
    private func makeStore() -> AppStore {
        let suiteName = "AppStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return AppStore(defaults: defaults)
    }
}
