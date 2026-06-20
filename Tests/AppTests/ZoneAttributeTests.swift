@testable import App
import XCTest

final class ZoneAttributeTests: XCTestCase {

    func testValidRanges() {
        XCTAssertEqual(ZoneAttributeIdentifier.volume.validRange, 0...38)
        XCTAssertEqual(ZoneAttributeIdentifier.source.validRange, 1...6)
        XCTAssertEqual(ZoneAttributeIdentifier.power.validRange, 0...1)
        XCTAssertEqual(ZoneAttributeIdentifier.treble.validRange, 0...14)
        XCTAssertEqual(ZoneAttributeIdentifier.bass.validRange, 0...14)
        XCTAssertEqual(ZoneAttributeIdentifier.balance.validRange, 0...20)
        XCTAssertNil(ZoneAttributeIdentifier.name.validRange)
    }

    func testRangeBoundaries() {
        XCTAssertTrue(ZoneAttributeIdentifier.volume.validRange!.contains(0))
        XCTAssertTrue(ZoneAttributeIdentifier.volume.validRange!.contains(38))
        XCTAssertFalse(ZoneAttributeIdentifier.volume.validRange!.contains(39))
        XCTAssertFalse(ZoneAttributeIdentifier.source.validRange!.contains(0))
        XCTAssertTrue(ZoneAttributeIdentifier.source.validRange!.contains(6))
        XCTAssertFalse(ZoneAttributeIdentifier.source.validRange!.contains(7))
    }
}
