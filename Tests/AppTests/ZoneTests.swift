@testable import App
import XCTest

final class ZoneTests: XCTestCase {

    // MARK: - apply(_:)  (regression for the zoneID-instead-of-value bug)

    func testApplyWritesValueNotZoneID() {
        var zone = Zone(id: 11)
        zone.apply(ZoneAttributeUpdate(zoneID: 11, attribute: .volume, value: 25))
        XCTAssertEqual(zone.volume, 25)   // previously this wrote the zone id (11)
        XCTAssertEqual(zone.id, 11)
    }

    func testApplyTargetsCorrectFields() {
        var zone = Zone(id: 11)
        zone.apply(ZoneAttributeUpdate(zoneID: 11, attribute: .power, value: 1))
        zone.apply(ZoneAttributeUpdate(zoneID: 11, attribute: .mute, value: 1))
        zone.apply(ZoneAttributeUpdate(zoneID: 11, attribute: .bass, value: 9))
        XCTAssertEqual(zone.power, 1)
        XCTAssertEqual(zone.mute, 1)
        XCTAssertEqual(zone.bass, 9)
        XCTAssertEqual(zone.volume, -1)   // untouched fields keep their initial value
    }

    func testApplyNameIsNoOp() {
        var zone = Zone(id: 11)
        zone.name = "Kitchen"
        zone.apply(ZoneAttributeUpdate(zoneID: 11, attribute: .name, value: 0))
        XCTAssertEqual(zone.name, "Kitchen")
    }

    // MARK: - Encoding

    func testEncodingZeroPadsSingleDigits() throws {
        var zone = Zone(id: 5)
        zone.volume = 7
        let data = try JSONEncoder().encode(zone)
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: String])
        XCTAssertEqual(json["zone"], "05")
        XCTAssertEqual(json["vo"], "07")
    }
}
