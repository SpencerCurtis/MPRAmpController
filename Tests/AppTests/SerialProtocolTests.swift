@testable import App
import XCTest

final class SerialProtocolTests: XCTestCase {

    // MARK: - Zone status parsing

    func testParseSingleZoneStatus() throws {
        // #>11 00 01 00 00 19 07 07 10 02 (00) — id, pa, power, mute, dnd, vol, treble, bass, balance, source
        let zone = try XCTUnwrap(SerialProtocol.parseZoneStatus(from: "#>1100010000190707100200\r\r\n"))
        XCTAssertEqual(zone.id, 11)
        XCTAssertEqual(zone.pa, 0)
        XCTAssertEqual(zone.power, 1)
        XCTAssertEqual(zone.mute, 0)
        XCTAssertEqual(zone.doNotDisturb, 0)
        XCTAssertEqual(zone.volume, 19)
        XCTAssertEqual(zone.treble, 7)
        XCTAssertEqual(zone.bass, 7)
        XCTAssertEqual(zone.balance, 10)
        XCTAssertEqual(zone.source, 2)
    }

    func testParseZoneStatusRejectsNonNumericField() {
        // Surfaces a malformed reply instead of silently decoding it as zeros.
        XCTAssertNil(SerialProtocol.parseZoneStatus(from: "#>11xx010000"))
    }

    func testParseAllZoneStatus() {
        let reply = "#>1100010000190707100200\r\r\n#>1200000000100505100100\r\r\n"
        let zones = SerialProtocol.parseAllZoneStatus(from: reply)
        XCTAssertEqual(zones.count, 2)
        XCTAssertEqual(zones[0].id, 11)
        XCTAssertEqual(zones[1].id, 12)
        XCTAssertEqual(zones[1].volume, 10)
        XCTAssertEqual(zones[1].source, 1)
    }

    // MARK: - Attribute status parsing

    func testParseAttributeStatus() throws {
        let update = try XCTUnwrap(SerialProtocol.parseAttributeStatus("<11vo15"))
        XCTAssertEqual(update.zoneID, 11)
        XCTAssertEqual(update.attribute, .volume)
        XCTAssertEqual(update.value, 15)
    }

    func testParseAttributeStatusRejectsShortInput() {
        XCTAssertNil(SerialProtocol.parseAttributeStatus("<11v"))
    }

    func testParseAttributeStatusRejectsUnknownAttribute() {
        XCTAssertNil(SerialProtocol.parseAttributeStatus("<11zz15"))
    }

    // MARK: - Command building

    func testCommandBuilders() {
        XCTAssertEqual(SerialProtocol.queryAllZonesCommand(), Data("?10\r".utf8))
        XCTAssertEqual(SerialProtocol.querySingleZoneCommand(zoneID: 11), Data("?11\r".utf8))
        XCTAssertEqual(
            SerialProtocol.attributeCommand(zoneID: "11", attribute: "vo", value: "15"),
            Data("<11vo15\r".utf8)
        )
    }
}
