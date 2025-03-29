//
//  MockSerialController.swift
//
//
//  Created by Spencer Curtis
//

import Vapor
import ORSSerial
import Dispatch

class MockSerialController: NSObject, RouteCollection {
    private var zones: [Zone] = [Zone(id: 11),
                                Zone(id: 12),
                                Zone(id: 13),
                                Zone(id: 14),
                                Zone(id: 15),
                                Zone(id: 16)]
    
    var application: Application!
    
    // MARK: - Initialization
    
    init(app: Application) {
        self.application = app
        super.init()
        // Initialize with some mock data
        for i in 0..<zones.count {
            zones[i].power = 0
            zones[i].volume = 50
            zones[i].name = "Zone \(zones[i].id)"
        }
    }
    
    // MARK: - Routing
    
    func boot(routes: RoutesBuilder) throws {
        // ADD: Route for web interface
        routes.get { req -> EventLoopFuture<View> in
            return try self.getAllZones(req).flatMap { zones in
                // Convert raw zone data to view context
                let zonesContext = zones.map { zone -> [String: String] in
                    return [
                        "id": String(zone.id),
                        "name": zone.name,
                        "status": zone.power == 1 ? "on" : "off",
                        "volume": String(zone.volume)
                    ]
                }
                
                let context = ["zones": zonesContext]
                return req.view.render("zones", context)
            }
        }

        routes.get("zones", use: getAllZones)
        routes.get("zones", ":zoneid", use: getSingleZone)
        routes.post("zones", ":zoneid", ":attribute", ":value", use: changeZoneAttributes)
        routes.get("bedroom", use: bedroomOn)
        routes.get("bathroom", use: bathroomOn)
    }
    
    // MARK: - GET Endpoints
    
    func getAllZones(_ req: Request) throws -> EventLoopFuture<[Zone]> {
        return req.eventLoop.makeSucceededFuture(zones)
    }
    
    func getSingleZone(req: Request) throws -> EventLoopFuture<Zone> {
        guard let zoneIDString = req.parameters.get("zoneid"),
              let zoneID = Int(zoneIDString),
              let index = indexOfZone(for: zoneID) else {
            throw Abort(.notFound)
        }
        
        return req.eventLoop.makeSucceededFuture(zones[index])
    }
    
    // MARK: - POST Endpoints
    
    func changeZoneAttributes(req: Request) throws -> EventLoopFuture<Zone> {
        guard let zoneID = req.parameters.get("zoneid"),
              let attributeString = req.parameters.get("attribute"),
              let value = req.parameters.get("value"),
              let attribute = ZoneAttributeIdentifier(rawValue: attributeString.lowercased()) else {
            throw Abort(.preconditionFailed)
        }
        
        if attribute == .name {
            return try setNameForZone(req, zoneID: zoneID, name: value).flatMap { success -> EventLoopFuture<Zone> in
                if success {
                    return try! self.getSingleZone(req: req)
                } else {
                    return req.eventLoop.makeFailedFuture(Abort(.internalServerError))
                }
            }
        }
        
        guard let zoneIDInt = Int(zoneID),
              let valueInt = Int(value),
              let index = indexOfZone(for: zoneIDInt) else {
            throw Abort(.badRequest)
        }
        
        // Update the zone attribute
        switch attribute {
        case .pa:
            zones[index].pa = valueInt
        case .power:
            zones[index].power = valueInt
        case .mute:
            zones[index].mute = valueInt
        case .doNotDisturb:
            zones[index].doNotDisturb = valueInt
        case .volume:
            zones[index].volume = valueInt
        case .treble:
            zones[index].treble = valueInt
        case .bass:
            zones[index].bass = valueInt
        case .balance:
            zones[index].balance = valueInt
        case .source:
            zones[index].source = valueInt
        case .name:
            break
        }
        
        return req.eventLoop.makeSucceededFuture(zones[index])
    }
    
    // MARK: - Special Endpoints
    
    func bedroomOn(req: Request) throws -> String {
        if let index = indexOfZone(for: 11) {
            zones[index].power = 1
        }
        if let index = indexOfZone(for: 12) {
            zones[index].power = 0
        }
        return "OK"
    }
    
    func bathroomOn(req: Request) throws -> String {
        if let index = indexOfZone(for: 11) {
            zones[index].power = 0
        }
        if let index = indexOfZone(for: 12) {
            zones[index].power = 1
        }
        return "OK"
    }
    
    // MARK: - Private Helpers
    
    private func indexOfZone(for id: Int) -> Int? {
        return zones.firstIndex(where: { $0.id == id })
    }
    
    private func setNameForZone(_ req: Request, zoneID: String, name: String) throws -> EventLoopFuture<Bool> {
        guard let zoneID = Int(zoneID),
              let index = indexOfZone(for: zoneID) else {
            return req.eventLoop.makeSucceededFuture(false)
        }
        
        return ZoneName.query(on: req.db)
            .filter(\.$zoneID, .equal, zoneID)
            .first()
            .flatMap { zoneName -> EventLoopFuture<Bool> in
                let zoneNameToSave: ZoneName
                if let existingZoneName = zoneName {
                    existingZoneName.name = name
                    zoneNameToSave = existingZoneName
                } else {
                    let newZoneName = ZoneName()
                    newZoneName.zoneID = zoneID
                    newZoneName.name = name
                    zoneNameToSave = newZoneName
                }
                
                return zoneNameToSave.save(on: req.db).map {
                    self.zones[index].name = name
                    return true
                }
            }
    }
}
