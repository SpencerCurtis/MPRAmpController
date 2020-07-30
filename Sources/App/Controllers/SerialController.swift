//
//  File.swift
//  
//
//  Created by Spencer Curtis on 6/30/20.
//

import Vapor
import SwiftSerial
import Dispatch

class SerialController: RouteCollection {
    
    private var sleepTime: UInt32 = 100
    private var isWriting = false
    private var portIsOpen = false
    private var hasLoadedZoneNames = false
    var application: Application!
    
    init(app: Application) {
        self.application = app
        currentSettings = defaultSettings
        closePortTimer = DispatchSource.makeTimerSource()
        getZoneNames()
        setUpTimer()
        updatePort()
    }
    
    var currentSettings: PortSettings!
    var port: SerialPort!
    var portCloseTime = CFAbsoluteTimeGetCurrent()
    
    
    
    var zones: [Zone] = [Zone(id: 11),
                         Zone(id: 12),
                         Zone(id: 13),
                         Zone(id: 14),
                         Zone(id: 15),
                         Zone(id: 16)]
    
    
    private var validBaudRates: [Int] = [9600, 19200,
                                         38400, 57600,
                                         115200, 230400]
    
    private var defaultSettings: PortSettings = {
        #if os(OSX)
        let path = "/dev/cu.usbserial-1430"
        #elseif os(Linux)
        let path = "/dev/ttyUSB0"
        #endif
        
        return PortSettings(path: path,
                            receiveRate: .baud9600,
                            transmitRate: .baud9600,
                            minimumBytesToRead: 0)
    }()
    
    var closePortTimer: DispatchSourceTimer
    
    // Initialization and Setup
    
    func setUpTimer() {
        closePortTimer.setEventHandler {
            self.checkToClosePort()
        }
        
        closePortTimer.schedule(deadline: .now() + 2, repeating: 2)
        if #available(OSX 10.14.3,  *) {
            closePortTimer.activate()
        }
    }
    
    // MARK: - Routing
    func boot(routes: RoutesBuilder) throws {
        routes.get("zones", use: getAllZones)
        routes.get("zones", ":zoneid", use: getSingleZone)
        
        routes.post("zones", ":zoneid", ":attribute", ":value", use: changeZoneAttributes)
        routes.post("settings", use: changeSettings)
        routes.post("reset", use: resetPort)
    }
    
    // MARK: - POST
    
    func changeSettings(req: Request) throws -> HTTPResponseStatus {
        guard let settingsDictionary = try? req.content.decode([String: String].self) else {
            return HTTPResponseStatus.badRequest
        }
        
        var status: HTTPResponseStatus = .ok
        
        for (key, value) in settingsDictionary {
            
            guard let identifier = SettingIdentifier(rawValue: key) else { continue }
            
            switch identifier {
            case .path:
                currentSettings.path = value
                
            case .receiveRate, .transmitRate:
                guard let value = Int(value),
                    validBaudRates.contains(value),
                    let rate = BaudRate(rawValue: value) else {
                        status = .badRequest
                        break
                }
                
                if identifier == .receiveRate {
                    currentSettings.receiveRate = rate
                } else {
                    currentSettings.transmitRate = rate
                }
                
                let output = writeString("<\(rate)\r")
                print(output)
            }
        }
        updatePortCloseTime()
        return status
    }
    
    func resetPort(req: Request) throws -> HTTPResponseStatus {
        currentSettings = defaultSettings
        updatePort()
        
        if updatePort() {
            return .ok
        } else {
            return .internalServerError
        }
    }
    
    
    func changeZoneAttributes(req: Request) throws -> EventLoopFuture<Zone> {

        defer {
            updatePortCloseTime()
        }
        
        guard !isWriting else {
            throw Abort(.internalServerError)
        }
        
        isWriting = true
        
        guard let zoneID = req.parameters.get("zoneid"),
            let attribute = req.parameters.get("attribute"),
            let value = req.parameters.get("value") else { throw Abort(.preconditionFailed) }
        
        
        guard ZoneAttributeIdentifier(rawValue: attribute.lowercased()) != nil else {
            usleep(sleepTime)
            isWriting = false
            return try getSingleZone(req: req)
        }
        
        if attribute == ZoneAttributeIdentifier.name.rawValue {
            return try setNameForZone(req, zoneID: zoneID, name: value).flatMap({
                do {
                    return try self.getSingleZone(req: req)
                } catch {
                    fatalError()
                }
            })
        }
        
        try openPort()
        writeString("<\(zoneID)\(attribute)\(value)\r")
        usleep(sleepTime)
        
        return try getSingleZone(req: req)
    }
    
    // MARK: - GET
    
    func getSingleZone(req: Request) throws -> EventLoopFuture<Zone> {
        //        _ = checkForAndLoadZoneNames(req)
        defer {
            isWriting = false
            updatePortCloseTime()
        }
        
        isWriting = true
        guard let zoneIDString = req.parameters.get("zoneid"),
            let zoneID = Int(zoneIDString) else {
                isWriting = false
                throw Abort(.preconditionFailed)
        }
        try openPort()
        writeString("?\(zoneID)\r")
        
        
        var zoneParsedSuccessfully = false
        
        var count = 0
        
        while !zoneParsedSuccessfully {
            let status = try port.readLine()
            NSLog("status: \(status), count: \(count)")
            count += 1
            usleep(10000)
            guard let cleanStatus = status.components(separatedBy: ">").last else { throw Abort(.internalServerError) }
            zoneParsedSuccessfully = parseZoneStatus(from: cleanStatus, for: zoneID)
        }
        
        guard let index = indexOfZone(for: zoneID) else { throw Abort(.notFound) }
        
        return req.eventLoop.future(zones[index])
    }
    
    func getAllZones(_ req: Request) throws -> [Zone] {
        // TODO: Keep track of how many amps are connected.
        
        defer {
            updatePortCloseTime()
            isWriting = false
        }
        try openPort()
        writeString("?10\r")
        do {
            var zoneString = ""
            
            var currentZone = 11
            var loopCount = 0
            while currentZone < 17 {
                let newLine = try port.readLine()
                if newLine.contains(">\(currentZone)") &&
                    newLine.count >= 22 {
                    //                    NSLog("FOUND \(newLine)")
                    zoneString += newLine
                    currentZone += 1
                }
                loopCount += 1
                NSLog(loopCount.description)
            }
            
            return parseAllZoneStatus(from: zoneString)
        } catch {
            NSLog("Error getting all zones: \(error)")
            throw Abort(.internalServerError)
        }
    }
    
    // MARK: - Private
    
    func indexOfZone(for id: Int) -> Int? {
        guard let zone = zones.filter({ $0.id == id }).first else { return nil }
        return zones.firstIndex(of: zone)
    }
    
    @discardableResult private func updatePort() -> Bool {
        closePort()
        let port = SerialPort(path: currentSettings.path)
        port.setSettings(receiveRate: currentSettings.receiveRate,
                         transmitRate: currentSettings.transmitRate,
                         minimumBytesToRead: currentSettings.minimumBytesToRead)
        
        do {
            self.port = port
            try openPort()
            return true
        } catch {
            NSLog("Error updating port: \(error)")
            return false
        }
    }
    
    func checkToClosePort() {
        let now = CFAbsoluteTimeGetCurrent()
        
        if now > portCloseTime {
            if portIsOpen {
                NSLog("Closing port after inactivity")
                closePort()
            }
        }
    }
    
    private func updatePortCloseTime() {
        portCloseTime = CFAbsoluteTimeGetCurrent() + 2
    }
    
    private func openPort() throws {
        if !portIsOpen {
            try port.openPort()
            usleep(100000)
            portIsOpen = true
        }
    }
    
    private func closePort() {
        guard port != nil else { return }
        port.closePort()
        portIsOpen = false
    }
    
    private func getZoneNames() {
        
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
    
    private func setNameForZone(_ req: Request, zoneID: String, name: String) throws -> EventLoopFuture<Void> {
        
        guard let zoneID = Int(zoneID) else {
            return req.eventLoop.makeSucceededFuture(Void())
        }
        
        return ZoneName
            .query(on: req.db)
            .filter(\.$zoneID, .equal, zoneID)
            .first()
            .flatMap { (zoneName) in
                var zoneNameToSave: ZoneName!
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
                        if let index = self.indexOfZone(for: zoneNameToSave.zoneID) {
                            self.zones[index].name = name
                        }
                        return req.eventLoop.makeSucceededFuture(Void())
                    })
        }
    }
    
    // MARK: - String Parsing From Serial Connection
    
    @discardableResult func parseZoneStatus(from string: String, for zoneID: Int? = nil) -> Bool {
        var zoneString = string
        
        zoneString = zoneString
            .replacingOccurrences(of: "\r\r", with: "")
            .replacingOccurrences(of: "\n#", with: "")
        
        var substrings: [Int] = []
        
        var currentSubstring = ""
        
        for char in zoneString {
            if currentSubstring.count == 0 {
                currentSubstring.append(char)
            } else if currentSubstring.count == 1 {
                currentSubstring.append(char)
                substrings.append(Int(currentSubstring) ?? 0)
                currentSubstring = ""
            }
        }
        
        var zone = Zone()
        
        for (index, string) in substrings.enumerated() {
            
            switch index {
            case 0:
                zone.id = string
            case 1 :
                zone.pa = string
            case 2:
                zone.power = string
            case 3:
                zone.mute = string
            case 4:
                zone.doNotDisturb = string
            case 5:
                zone.volume = string
            case 6:
                zone.treble = string
            case 7:
                zone.bass = string
            case 8:
                zone.balance = string
            case 9:
                zone.source = string
            default:
                break
            }
        }
        
        guard let index = indexOfZone(for: zone.id) else { return false }
        zones[index].updateWith(zone)
        return true
    }
    
    func parseAllZoneStatus(from string: String) -> [Zone] {
        
        var zoneStrings = string.components(separatedBy: "#>")
        zoneStrings.removeFirst()
        
        for zoneString in zoneStrings {
            parseZoneStatus(from: zoneString)
        }
        
        return zones
    }
    
    @discardableResult private func writeString(_ string: String) -> String {
        do {
            let result = try port.writeData(string.data(using: .ascii)!)
            return result.description
        } catch {
            let error = "ERROR: \(error)"
            NSLog(error)
            return error
        }
    }
}
