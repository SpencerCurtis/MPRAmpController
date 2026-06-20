//
//  MockSerialTransport.swift
//
//
//  A hardware-free SerialTransport that lets the whole server (and web UI) run
//  with no amplifier attached — set USE_MOCK_CONTROLLER=true (see routes.swift).
//  Unlike the test-only FakeSerialTransport, this keeps mutable per-zone state so
//  writes persist and subsequent reads reflect them, making the UI interactive.
//

import Foundation

final class MockSerialTransport: SerialTransport {

    /// One field array per zone: [id, pa, power, mute, dnd, vol, treble, bass, balance, source].
    private let state = MockState()

    func send(_ command: Data, matching matcher: SerialResponseMatcher) async throws -> Data {
        let text = String(decoding: command, as: UTF8.self).replacingOccurrences(of: "\r", with: "")

        if text.hasPrefix("?") {
            let arg = String(text.dropFirst())
            if arg == "10" {
                return Data((await state.allRecords()).utf8)
            }
            if let id = Int(arg) {
                return Data((await state.record(for: id)).utf8)
            }
        } else if text.hasPrefix("<") {
            // `<11vo15` — set an attribute; echo it back like the amp does.
            if let update = SerialProtocol.parseAttributeStatus(text) {
                await state.apply(update)
            }
            return Data(text.utf8)
        }
        return Data()
    }
}

/// Serializes the mock's in-memory zone state.
private actor MockState {
    // Field indices: 0 id, 1 pa, 2 power, 3 mute, 4 dnd, 5 vol, 6 treble, 7 bass, 8 balance, 9 source.
    private var zones: [Int: [Int]]

    init() {
        var seed: [Int: [Int]] = [:]
        for (offset, id) in (11...16).enumerated() {
            let power = offset % 2            // alternate on/off
            let volume = 8 + offset * 4       // 8, 12, 16, …
            let source = (offset % 6) + 1
            seed[id] = [id, 0, power, 0, 0, volume, 7, 7, 10, source]
        }
        zones = seed
    }

    private let attributeIndex: [String: Int] = [
        "pa": 1, "pr": 2, "mu": 3, "dt": 4, "vo": 5, "tr": 6, "bs": 7, "bl": 8, "ch": 9
    ]

    func apply(_ update: ZoneAttributeUpdate) {
        guard var fields = zones[update.zoneID],
            let index = attributeIndex[update.attribute.rawValue] else { return }
        fields[index] = update.value
        zones[update.zoneID] = fields
    }

    func record(for id: Int) -> String {
        guard let fields = zones[id] else { return "" }
        return "#>" + fields.map { String(format: "%02d", $0) }.joined() + "\r\r\n"
    }

    func allRecords() -> String {
        zones.keys.sorted().map { record(for: $0) }.joined()
    }
}
