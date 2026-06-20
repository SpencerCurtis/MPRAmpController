@testable import App
import XCTest

final class ZoneStoreTests: XCTestCase {

    func testApplyUpdatesAndReturnsZone() async {
        let store = ZoneStore(zoneIDs: [11, 12])
        let updated = await store.apply(ZoneAttributeUpdate(zoneID: 11, attribute: .volume, value: 30))
        XCTAssertEqual(updated?.volume, 30)
        let fetched = await store.zone(for: 11)
        XCTAssertEqual(fetched?.volume, 30)
    }

    func testMergePreservesName() async {
        let store = ZoneStore(zoneIDs: [11])
        await store.setName("Kitchen", for: 11)

        var parsed = Zone(id: 11)
        parsed.volume = 5
        let merged = await store.merge(parsed)

        XCTAssertEqual(merged?.name, "Kitchen")   // updateWith leaves the name intact
        XCTAssertEqual(merged?.volume, 5)
    }

    func testUnknownZoneReturnsNil() async {
        let store = ZoneStore(zoneIDs: [11])
        let applied = await store.apply(ZoneAttributeUpdate(zoneID: 99, attribute: .volume, value: 1))
        XCTAssertNil(applied)
        let fetched = await store.zone(for: 99)
        XCTAssertNil(fetched)
    }
}
