@testable import App
import Foundation
import XCTest

/// Returns canned replies and records what was sent, so the controller's serial
/// flow can be tested without real hardware.
final class FakeSerialTransport: SerialTransport {
    private let handler: (Data) throws -> Data
    private(set) var sentCommands: [Data] = []

    init(handler: @escaping (Data) throws -> Data) {
        self.handler = handler
    }

    func send(_ command: Data, matching matcher: SerialResponseMatcher) async throws -> Data {
        sentCommands.append(command)
        return try handler(command)
    }
}

final class SerialControllerTests: XCTestCase {

    func testRefreshZoneParsesStoresAndSendsCommand() async throws {
        let transport = FakeSerialTransport { _ in Data("#>1100010000190707100200\r\r\n".utf8) }
        let controller = SerialController(transport: transport)

        let zone = try await controller.refreshZone(id: 11)

        XCTAssertEqual(zone.id, 11)
        XCTAssertEqual(zone.volume, 19)
        XCTAssertEqual(zone.source, 2)
        XCTAssertEqual(transport.sentCommands, [Data("?11\r".utf8)])
    }

    func testRefreshAllZonesMergesEachReply() async throws {
        let reply = "#>1100010000190707100200\r\r\n#>1200000000100505100100\r\r\n"
        let transport = FakeSerialTransport { _ in Data(reply.utf8) }
        let controller = SerialController(transport: transport)

        let zones = try await controller.refreshAllZones()

        XCTAssertEqual(zones.count, 6)
        XCTAssertEqual(zones.first(where: { $0.id == 11 })?.volume, 19)
        XCTAssertEqual(zones.first(where: { $0.id == 12 })?.source, 1)
        XCTAssertEqual(transport.sentCommands, [Data("?10\r".utf8)])
    }

    func testSetAttributeAppliesEcho() async throws {
        let transport = FakeSerialTransport { _ in Data("<11vo15".utf8) }
        let controller = SerialController(transport: transport)

        let zone = try await controller.setAttribute(zoneID: "11", attribute: "vo", value: "15")

        XCTAssertEqual(zone.volume, 15)
        XCTAssertEqual(transport.sentCommands, [Data("<11vo15\r".utf8)])
    }

    func testSetAttributePropagatesTransportError() async {
        struct Boom: Error {}
        let transport = FakeSerialTransport { _ in throw Boom() }
        let controller = SerialController(transport: transport)

        do {
            _ = try await controller.setAttribute(zoneID: "11", attribute: "vo", value: "15")
            XCTFail("expected the transport error to propagate")
        } catch {
            // expected
        }
    }

    func testRefreshZoneThrowsOnUnparseableReply() async {
        let transport = FakeSerialTransport { _ in Data("garbage".utf8) }
        let controller = SerialController(transport: transport)

        do {
            _ = try await controller.refreshZone(id: 11)
            XCTFail("expected an error for an unparseable reply")
        } catch {
            // expected
        }
    }

    // MARK: - ContinuationBox

    func testContinuationBoxResumesOnlyOnce() async throws {
        struct Ignored: Error {}
        let data = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
            let box = ContinuationBox(continuation)
            box.resume(returning: Data([1]))
            box.resume(returning: Data([2]))   // must be ignored (double-resume would crash)
            box.resume(throwing: Ignored())    // must be ignored
        }
        XCTAssertEqual(data, Data([1]))
    }
}
