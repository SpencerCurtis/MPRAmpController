//
//  ZoneStore.swift
//
//
//  Serializes all access to the live, in-memory zone state. The amplifier's
//  replies arrive on ORSSerialPort's delegate thread while Vapor's async route
//  handlers read the same state on event-loop threads; routing every mutation
//  and read through an actor removes that data race.
//

import Foundation

actor ZoneStore {

    private var zones: [Zone]

    init(zoneIDs: [Int]) {
        zones = zoneIDs.map { Zone(id: $0) }
    }

    func allZones() -> [Zone] { zones }

    func zone(for id: Int) -> Zone? {
        guard let index = index(for: id) else { return nil }
        return zones[index]
    }

    /// Merges a freshly parsed zone status, returning the stored zone (its name is preserved).
    @discardableResult
    func merge(_ parsed: Zone) -> Zone? {
        guard let index = index(for: parsed.id) else { return nil }
        zones[index].updateWith(parsed)
        return zones[index]
    }

    /// Merges several parsed zones, returning the full current set.
    func merge(_ parsedZones: [Zone]) -> [Zone] {
        for parsed in parsedZones { merge(parsed) }
        return zones
    }

    /// Applies a single attribute change, returning the updated zone.
    func apply(_ update: ZoneAttributeUpdate) -> Zone? {
        guard let index = index(for: update.zoneID) else { return nil }
        zones[index].apply(update)
        return zones[index]
    }

    func setName(_ name: String, for id: Int) {
        guard let index = index(for: id) else { return }
        zones[index].name = name
    }

    private func index(for id: Int) -> Int? {
        zones.firstIndex(where: { $0.id == id })
    }
}
