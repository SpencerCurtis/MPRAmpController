//
//  SerialController.swift
//
//
//  Created by Spencer Curtis on 6/30/20.
//

import Foundation
import Vapor
import Fluent

final class SerialController: RouteCollection {

    private let transport: SerialTransport

    /// All live zone state lives behind this actor (see ZoneStore) so the serial
    /// transport and the async route handlers can't race on it.
    let store = ZoneStore(zoneIDs: [11, 12, 13, 14, 15, 16])

    init(transport: SerialTransport) {
        self.transport = transport
    }

    // MARK: - Routing

    func boot(routes: RoutesBuilder) throws {
        routes.get("zones", use: getAllZones)
        routes.get("zones", ":zoneid", use: getSingleZone)
        routes.post("zones", ":zoneid", ":attribute", ":value", use: changeZoneAttributes)
    }

    // MARK: - Core (hardware via the injected transport; no HTTP or DB — unit testable)

    /// Queries every zone, merges the replies into the store, and returns them.
    @discardableResult
    func refreshAllZones() async throws -> [Zone] {
        let data = try await transport.send(
            // TODO: Support multiple chained amps (the matcher is hardcoded to 6 zones / 1 amp).
            SerialProtocol.queryAllZonesCommand(),
            matching: .regex(pattern: "(#>.+\r\r\n{0,}){6}#", maxLength: 200)
        )
        let parsed = SerialProtocol.parseAllZoneStatus(from: String(decoding: data, as: UTF8.self))
        return await store.merge(parsed)
    }

    /// Queries one zone, merges the reply, and returns the stored zone.
    @discardableResult
    func refreshZone(id: Int) async throws -> Zone {
        let data = try await transport.send(
            SerialProtocol.querySingleZoneCommand(zoneID: id),
            matching: .prefixSuffix(prefix: "#>", suffix: "\n", maxLength: 30)
        )
        let text = String(decoding: data, as: UTF8.self)
        guard let cleanStatus = text.components(separatedBy: ">").last,
            let parsed = SerialProtocol.parseZoneStatus(from: cleanStatus),
            let zone = await store.merge(parsed) else {
                throw Abort(.notFound)
        }
        return zone
    }

    /// Sets one attribute on one zone, applies the amp's echo, and returns the zone.
    @discardableResult
    func setAttribute(zoneID: String, attribute: String, value: String) async throws -> Zone {
        let data = try await transport.send(
            SerialProtocol.attributeCommand(zoneID: zoneID, attribute: attribute, value: value),
            matching: .regex(pattern: "<.{6}", maxLength: 8)
        )
        guard let update = SerialProtocol.parseAttributeStatus(String(decoding: data, as: UTF8.self)),
            let zone = await store.apply(update) else {
                throw Abort(.badGateway, reason: "Amplifier did not echo a usable result")
        }
        return zone
    }

    // MARK: - Routes

    func getAllZones(_ req: Request) async throws -> [Zone] {
        try await refreshAllZones()
        await loadZoneNames(on: req.db)
        return await store.allZones()
    }

    func getSingleZone(req: Request) async throws -> Zone {
        guard let zoneID = req.parameters.get("zoneid", as: Int.self) else {
            throw Abort(.preconditionFailed)
        }
        try await refreshZone(id: zoneID)
        await loadZoneNames(on: req.db)
        guard let zone = await store.zone(for: zoneID) else { throw Abort(.notFound) }
        return zone
    }

    func changeZoneAttributes(req: Request) async throws -> Zone {
        guard let zoneID = req.parameters.get("zoneid"),
            let attributeString = req.parameters.get("attribute"),
            let value = req.parameters.get("value"),
            let attribute = ZoneAttributeIdentifier(rawValue: attributeString.lowercased()) else {
                throw Abort(.preconditionFailed)
        }

        if attribute == .name {
            try await setName(zoneID: zoneID, name: value, on: req.db)
            return try await getSingleZone(req: req)
        }

        return try await setAttribute(zoneID: zoneID, attribute: attribute.rawValue, value: value)
    }

    // MARK: - Zone Names (persistence)

    private func loadZoneNames(on database: Database) async {
        do {
            let fetched = try await ZoneName.query(on: database).all()
            for zoneName in fetched {
                await store.setName(zoneName.name, for: zoneName.zoneID)
            }
        } catch {
            database.logger.error("Zone names could not be fetched: \(error)")
        }
    }

    private func setName(zoneID: String, name: String, on database: Database) async throws {
        guard let zoneID = Int(zoneID) else { throw Abort(.preconditionFailed) }

        let zoneName = try await ZoneName.query(on: database)
            .filter(\.$zoneID == zoneID)
            .first() ?? ZoneName()
        zoneName.zoneID = zoneID
        zoneName.name = name
        try await zoneName.save(on: database)

        await store.setName(name, for: zoneID)
    }
}
