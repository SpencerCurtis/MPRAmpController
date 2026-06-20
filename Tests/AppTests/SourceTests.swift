@testable import App
import XCTest

final class SourceTests: XCTestCase {

    func testCatalogFillsDefaultsForMissingNames() {
        let merged = SourceCatalog.merged(savedNames: [2: "Apple TV", 5: "Turntable"])
        XCTAssertEqual(merged.count, 6)
        XCTAssertEqual(merged.map(\.id), [1, 2, 3, 4, 5, 6])
        XCTAssertEqual(merged[0].name, "Source 1")
        XCTAssertEqual(merged[1].name, "Apple TV")
        XCTAssertEqual(merged[4].name, "Turntable")
        XCTAssertEqual(merged[5].name, "Source 6")
    }
}
