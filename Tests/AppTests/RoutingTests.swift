@testable import App
import XCTVapor

final class RoutingTests: XCTestCase {

    /// Boots a test app with an in-memory DB and a fake transport, registering the
    /// real route collection. Registration itself would crash on a RoutingKit
    /// parameter-name collision, so just building this catches that class of bug.
    private func makeApp() async throws -> Application {
        let app = Application(.testing)
        app.databases.use(.sqlite(.memory), as: .sqlite)
        app.migrations.add(CreateZone())
        app.migrations.add(CreatePreset())
        app.migrations.add(CreateSourceName())
        try await app.autoMigrate().get()

        let transport = FakeSerialTransport { command in
            let text = String(decoding: command, as: UTF8.self)
            if text.hasPrefix("?") {
                // a zone-status query
                return Data("#>1100010000190707100200\r\r\n".utf8)
            }
            // an attribute-set command is its own echo
            return Data(text.replacingOccurrences(of: "\r", with: "").utf8)
        }
        try app.register(collection: SerialController(transport: transport))
        return app
    }

    func testRoutesRegisterWithoutCollision() async throws {
        let app = try await makeApp()
        app.shutdown()
    }

    func testCoreRoutesRespond() async throws {
        let app = try await makeApp()
        defer { app.shutdown() }

        try app.test(.GET, "sources") { XCTAssertEqual($0.status, .ok) }
        try app.test(.GET, "presets") { XCTAssertEqual($0.status, .ok) }
        try app.test(.GET, "zones") { XCTAssertEqual($0.status, .ok) }
        try app.test(.GET, "zones/11") { XCTAssertEqual($0.status, .ok) }
        try app.test(.POST, "zones/all/vo/10") { XCTAssertEqual($0.status, .ok) }
        try app.test(.POST, "zones/11/vo/99") { XCTAssertEqual($0.status, .badRequest) }
        try app.test(.POST, "presets?name=test") { XCTAssertEqual($0.status, .ok) }
    }
}
