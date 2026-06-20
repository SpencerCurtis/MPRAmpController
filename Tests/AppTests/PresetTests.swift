@testable import App
import Foundation
import XCTest

final class PresetTests: XCTestCase {

    /// An attribute-set command (`<11vo10\r`) is itself a valid attribute echo, so
    /// echoing the command back (minus the carriage return) makes `setAttribute` succeed.
    private func echoTransport() -> FakeSerialTransport {
        FakeSerialTransport { command in
            Data(String(decoding: command, as: UTF8.self).replacingOccurrences(of: "\r", with: "").utf8)
        }
    }

    func testSetAllZonesSetsEveryZone() async throws {
        let transport = echoTransport()
        let controller = SerialController(transport: transport)

        let zones = try await controller.setAllZones(attribute: "vo", value: "10")

        XCTAssertEqual(zones.count, 6)
        XCTAssertTrue(zones.allSatisfy { $0.volume == 10 })
        XCTAssertEqual(transport.sentCommands.count, 6)   // one per zone
    }

    func testApplyPresetSendsPowerSourceVolumePerZone() async throws {
        let transport = echoTransport()
        let controller = SerialController(transport: transport)
        let preset = Preset(name: "Movie", zones: [
            PresetZone(zone: 11, power: 1, source: 3, volume: 20),
            PresetZone(zone: 12, power: 0, source: 1, volume: 5)
        ])

        let zones = try await controller.apply(preset)

        XCTAssertEqual(transport.sentCommands.count, 6)   // 3 attributes * 2 zones
        XCTAssertEqual(zones.first(where: { $0.id == 11 })?.volume, 20)
        XCTAssertEqual(zones.first(where: { $0.id == 11 })?.source, 3)
        XCTAssertEqual(zones.first(where: { $0.id == 12 })?.power, 0)
    }

    func testCaptureCurrentStateSnapshotsPowerSourceVolume() async throws {
        // zone 11: id pa power mu dnd vol tr bs bl source = 11 01 01 00 00 20 07 07 10 03
        let transport = FakeSerialTransport { _ in Data("#>11010100002007071003\r\r\n".utf8) }
        let controller = SerialController(transport: transport)

        let snapshot = try await controller.captureCurrentState()

        XCTAssertEqual(snapshot.count, 6)
        let zone11 = snapshot.first(where: { $0.zone == 11 })
        XCTAssertEqual(zone11?.power, 1)
        XCTAssertEqual(zone11?.source, 3)
        XCTAssertEqual(zone11?.volume, 20)
    }

    func testPresetZonesRoundTripThroughJSON() {
        let preset = Preset(name: "X", zones: [PresetZone(zone: 11, power: 1, source: 2, volume: 3)])
        let decoded = preset.zones
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded.first?.zone, 11)
        XCTAssertEqual(decoded.first?.volume, 3)
    }
}
