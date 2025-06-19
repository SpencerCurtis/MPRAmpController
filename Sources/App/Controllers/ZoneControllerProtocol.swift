import Vapor
import Foundation

/// Protocol defining the interface for zone controllers
/// Allows for both real serial communication and mock implementations
protocol ZoneControllerProtocol: RouteCollection {
    /// The zones managed by this controller
    var zones: [Zone] { get set }
    
    /// The application instance
    var application: Application! { get set }
    
    /// Initialize with an application instance
    init(app: Application)
    
    /// Get all zones with their current status
    func getAllZones(_ req: Request) throws -> EventLoopFuture<[Zone]>
    
    /// Get a single zone by ID
    func getSingleZone(req: Request) throws -> EventLoopFuture<Zone>
    
    /// Change zone attributes (volume, power, etc.)
    func changeZoneAttributes(req: Request) throws -> EventLoopFuture<Zone>
    
    /// Change controller settings
    func changeSettings(req: Request) throws -> HTTPResponseStatus
}

/// Base implementation providing common functionality
class BaseZoneController {
    var zones: [Zone] = [Zone(id: 11),
                         Zone(id: 12),
                         Zone(id: 13),
                         Zone(id: 14),
                         Zone(id: 15),
                         Zone(id: 16)]
    
    var application: Application!
    
    required init(app: Application) {
        self.application = app
    }
    
    /// Find the index of a zone by its ID
    func indexOfZone(for id: Int?) -> Int? {
        guard let id = id,
              let zone = zones.filter({ $0.id == id }).first else { return nil }
        return zones.firstIndex(of: zone)
    }
    
    /// Load zone names from the database
    func getZoneNames() {
        ZoneName.query(on: application.db(.sqlite)).all().whenComplete { (result) in
            do {
                let fetchedZones = try result.get()
                
                for fetchedZone in fetchedZones {
                    guard let index = self.indexOfZone(for: fetchedZone.zoneID) else {
                        NSLog("No zone with index \(fetchedZone.zoneID) found")
                        continue
                    }
                    self.zones[index].name = fetchedZone.name
                }
            } catch {
                NSLog("Zone names were unable to be fetched: \(error)")
            }
        }
    }
    
    /// Set a custom name for a zone
    func setNameForZone(_ req: Request, zoneID: String, name: String) throws -> EventLoopFuture<Bool> {
        guard let zoneID = Int(zoneID) else {
            return req.eventLoop.makeSucceededFuture(false)
        }
        
        return ZoneName
            .query(on: req.db)
            .filter(\.$zoneID, .equal, zoneID)
            .first()
            .flatMap { (zoneName) in
                var zoneNameToSave: ZoneName
                if let zoneName = zoneName {
                    zoneName.name = name
                    zoneNameToSave = zoneName
                } else {
                    let zoneName = ZoneName()
                    zoneName.zoneID = zoneID
                    zoneName.name = name
                    zoneNameToSave = zoneName
                }
                
                return zoneNameToSave.save(on: req.db)
                    .flatMap({
                        var success = false
                        if let index = self.indexOfZone(for: zoneNameToSave.zoneID) {
                            self.zones[index].name = name
                            success = true
                        }
                        return req.eventLoop.makeSucceededFuture(success)
                    })
        }
    }
}

/// Error types for zone controller operations
enum ZoneControllerError: Error {
    case noZone
    case noResults
    case noPort
    case invalidRequest
    case communicationTimeout
} 