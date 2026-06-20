@testable import App
import XCTest

final class MockSerialTransportTests: XCTestCase {

    func testReturnsSixZonesForQueryAll() async throws {
        let mock = MockSerialTransport()
        let controller = SerialController(transport: mock)
        let zones = try await controller.refreshAllZones()
        XCTAssertEqual(zones.count, 6)
        XCTAssertEqual(Set(zones.map(\.id)), Set(11...16))
    }

    func testWriteThenReadReflectsState() async throws {
        let mock = MockSerialTransport()
        let controller = SerialController(transport: mock)

        _ = try await controller.setAttribute(zoneID: "11", attribute: "vo", value: "27")
        let zone = try await controller.refreshZone(id: 11)

        XCTAssertEqual(zone.volume, 27)   // the mock persisted the write
    }

    func testStatefulAcrossSeparateReads() async throws {
        let mock = MockSerialTransport()
        let controller = SerialController(transport: mock)

        _ = try await controller.setAttribute(zoneID: "12", attribute: "ch", value: "04")
        let all = try await controller.refreshAllZones()
        XCTAssertEqual(all.first(where: { $0.id == 12 })?.source, 4)
    }
}
