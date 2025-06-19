import Vapor
import Foundation

/// Mock implementation of ZoneControllerProtocol for local development and testing
class MockZoneController: BaseZoneController, ZoneControllerProtocol {
    
    private let simulateDelay: Bool
    private let simulateErrors: Bool
    
    init(app: Application, simulateDelay: Bool = true, simulateErrors: Bool = false) {
        self.simulateDelay = simulateDelay
        self.simulateErrors = simulateErrors
        super.init(app: app)
        
        // Initialize zones with some realistic mock data
        initializeMockZones()
    }
    
    required init(app: Application) {
        self.simulateDelay = true
        self.simulateErrors = false
        super.init(app: app)
        initializeMockZones()
    }
    
    // MARK: - RouteCollection
    
    func boot(routes: RoutesBuilder) throws {
        routes.get("zones", use: getAllZones)
        routes.get("zones", ":zoneid", use: getSingleZone)
        routes.post("zones", ":zoneid", ":attribute", ":value", use: changeZoneAttributes)
        routes.post("settings", use: changeSettings)
        
        NSLog("🎭 Mock Zone Controller initialized - hardware simulation enabled")
    }
    
    // MARK: - ZoneControllerProtocol Implementation
    
    func getAllZones(_ req: Request) throws -> EventLoopFuture<[Zone]> {
        let promise = req.eventLoop.makePromise(of: [Zone].self)
        
        // Simulate serial communication delay
        if simulateDelay {
            req.eventLoop.scheduleTask(in: .milliseconds(100)) {
                self.getZoneNames()
                promise.succeed(self.zones)
            }
        } else {
            getZoneNames()
            promise.succeed(zones)
        }
        
        return promise.futureResult
    }
    
    func getSingleZone(req: Request) throws -> EventLoopFuture<Zone> {
        guard let zoneIDString = req.parameters.get("zoneid"),
              let zoneID = Int(zoneIDString),
              let index = indexOfZone(for: zoneID) else {
            throw Abort(.preconditionFailed)
        }
        
        let promise = req.eventLoop.makePromise(of: Zone.self)
        
        // Simulate occasional errors if enabled
        if simulateErrors && Int.random(in: 1...10) == 1 {
            promise.fail(ZoneControllerError.communicationTimeout)
            return promise.futureResult
        }
        
        // Simulate serial communication delay
        if simulateDelay {
            req.eventLoop.scheduleTask(in: .milliseconds(50)) {
                self.getZoneNames()
                promise.succeed(self.zones[index])
            }
        } else {
            getZoneNames()
            promise.succeed(zones[index])
        }
        
        return promise.futureResult
    }
    
    func changeZoneAttributes(req: Request) throws -> EventLoopFuture<Zone> {
        guard let zoneIDString = req.parameters.get("zoneid"),
              let attributeString = req.parameters.get("attribute"),
              let valueString = req.parameters.get("value"),
              let zoneID = Int(zoneIDString),
              let attribute = ZoneAttributeIdentifier(rawValue: attributeString.lowercased()),
              let index = indexOfZone(for: zoneID) else {
            throw Abort(.preconditionFailed)
        }
        
        // Handle name changes specially
        if attribute == .name {
            return try setNameForZone(req, zoneID: zoneIDString, name: valueString).flatMap { success in
                if success {
                    return req.eventLoop.makeSucceededFuture(self.zones[index])
                } else {
                    let promise = req.eventLoop.makePromise(of: Zone.self)
                    promise.fail(ZoneControllerError.invalidRequest)
                    return promise.futureResult
                }
            }
        }
        
        // For non-name attributes, convert value to Int
        guard let value = Int(valueString) else {
            throw Abort(.preconditionFailed)
        }
        
        let promise = req.eventLoop.makePromise(of: Zone.self)
        
        // Simulate occasional errors if enabled
        if simulateErrors && Int.random(in: 1...20) == 1 {
            promise.fail(ZoneControllerError.communicationTimeout)
            return promise.futureResult
        }
        
        // Update the zone attribute
        let success = updateZoneAttribute(index: index, attribute: attribute, value: value)
        
        if simulateDelay {
            req.eventLoop.scheduleTask(in: .milliseconds(75)) {
                if success {
                    promise.succeed(self.zones[index])
                } else {
                    promise.fail(ZoneControllerError.invalidRequest)
                }
            }
        } else {
            if success {
                promise.succeed(zones[index])
            } else {
                promise.fail(ZoneControllerError.invalidRequest)
            }
        }
        
        return promise.futureResult
    }
    
    func changeSettings(req: Request) throws -> HTTPResponseStatus {
        guard let settingsDictionary = try? req.content.decode([String: String].self) else {
            return HTTPResponseStatus.badRequest
        }
        
        // Mock settings validation
        for (key, value) in settingsDictionary {
            NSLog("🎭 Mock: Would change setting \(key) to \(value)")
            
            // Simulate basic validation
            if key == "path" && value.isEmpty {
                return .badRequest
            }
        }
        
        return .ok
    }
    
    // MARK: - Private Mock Methods
    
    private func initializeMockZones() {
        // Set up zones with realistic default values
        for i in 0..<zones.count {
            zones[i].pa = 0
            zones[i].power = i % 2  // Alternate power states
            zones[i].mute = 0
            zones[i].doNotDisturb = 0
            zones[i].volume = Int.random(in: 10...25)  // Random volume between 10-25
            zones[i].treble = Int.random(in: 8...12)   // Random treble around neutral
            zones[i].bass = Int.random(in: 8...12)     // Random bass around neutral
            zones[i].balance = 10  // Neutral balance
            zones[i].source = Int.random(in: 1...6)    // Random source
        }
        
        NSLog("🎭 Mock zones initialized with realistic data")
    }
    
    private func updateZoneAttribute(index: Int, attribute: ZoneAttributeIdentifier, value: Int) -> Bool {
        guard index >= 0 && index < zones.count else { return false }
        
        // Validate value ranges for different attributes
        switch attribute {
        case .power, .mute, .doNotDisturb, .pa:
            guard value >= 0 && value <= 1 else { return false }
        case .volume:
            guard value >= 0 && value <= 38 else { return false }  // Typical amp range
        case .treble, .bass:
            guard value >= 0 && value <= 20 else { return false }  // Typical EQ range
        case .balance:
            guard value >= 0 && value <= 20 else { return false }  // Balance range
        case .source:
            guard value >= 1 && value <= 6 else { return false }   // Source inputs
        case .name:
            return false  // Names are handled separately
        }
        
        // Apply the change
        switch attribute {
        case .pa:
            zones[index].pa = value
        case .power:
            zones[index].power = value
        case .mute:
            zones[index].mute = value
        case .doNotDisturb:
            zones[index].doNotDisturb = value
        case .volume:
            zones[index].volume = value
        case .treble:
            zones[index].treble = value
        case .bass:
            zones[index].bass = value
        case .balance:
            zones[index].balance = value
        case .source:
            zones[index].source = value
        case .name:
            break
        }
        
        NSLog("🎭 Mock: Changed zone \(zones[index].id ?? 0) \(attribute.rawValue) to \(value)")
        return true
    }
} 