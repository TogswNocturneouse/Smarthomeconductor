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
    func testDeviceControlPersistsInSharedState() throws {
        let store = makeStore()
        let device = try XCTUnwrap(
            store.devices.first { $0.capabilities.contains(.brightness) }
        )

        store.setBrightness(37, for: device.id)

        XCTAssertEqual(store.device(id: device.id)?.brightness, 37)
        XCTAssertEqual(store.device(id: device.id)?.isOn, true)
    }

    @MainActor
    func testEnvironmentalSummaryAggregatesAvailableSensors() {
        let store = makeStore()
        let summary = store.environmentalSummary

        XCTAssertNotNil(summary.temperature)
        XCTAssertNotNil(summary.humidity)
        XCTAssertNotNil(summary.illuminance)
        XCTAssertNotNil(summary.airQualityIndex)
        XCTAssertGreaterThan(summary.onlineSensors, 0)
    }

    @MainActor
    func testLocalAssistantRunsScene() {
        let store = makeStore()

        let response = store.executeLocalAssistantCommand("Run focus scene")

        XCTAssertNotNil(response)
        XCTAssertEqual(store.activeScene, .focus)
    }

    @MainActor
    private func makeStore() -> AppStore {
        let suiteName = "AppStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return AppStore(defaults: defaults)
    }
}
