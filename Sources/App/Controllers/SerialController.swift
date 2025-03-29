//
//  File.swift
//
//
//  Created by Spencer Curtis on 6/30/20.
//

import Vapor
import ORSSerial
import Dispatch

class SerialController: NSObject, RouteCollection {
    
    private var sleepTime: UInt32 = 100000
    private var isWriting = false
    private var portIsOpen = false
    private var hasLoadedZoneNames = false
    
    var currentSettings: PortSettings!
    var port: ORSSerialPort
    var portCloseTime = Date().timeIntervalSince1970
    
    var zones: [Zone] = [Zone(id: 11),
                         Zone(id: 12),
                         Zone(id: 13),
                         Zone(id: 14),
                         Zone(id: 15),
                         Zone(id: 16)]
    
    
    private var validBaudRates: [Int] = [9600, 19200,
                                         38400, 57600,
                                         115200, 230400]
    
    var closePortTimer: DispatchSourceTimer
    var closePortQueue = DispatchQueue(label: "com.SpencerCurtis.MPRAmpController.closePortQueue")
    
    var application: Application!
    
    // MARK: - Initialization
    
    init(app: Application) {
        self.application = app
        closePortTimer = DispatchSource.makeTimerSource(queue: closePortQueue)
        port = ORSSerialPortManager.shared().availablePorts.first(where: { $0.name.contains("usbserial") })!
        port.baudRate = 9600
    }
    
    // MARK: - Routing
    
    func boot(routes: RoutesBuilder) throws {
        if port.delegate == nil {
            port.delegate = self
            port.open()
        }
        routes.get("zones", use: getAllZones)
        routes.get("zones", ":zoneid", use: getSingleZone)
        
        routes.post("zones", ":zoneid", ":attribute", ":value", use: changeZoneAttributes)
        routes.post("settings", use: changeSettings)
        //        routes.post("reset", use: resetPort)
        routes.get("bedroom", use: bedroomOn)
        routes.get("bathroom", use: bathroomOn)
    }
    
    // MARK: - POST
    
    func bedroomOn(req: Request) throws -> String {
        let requestData = "<11pr01\r<12pr00\r".data(using: .ascii)!
        let regex = try NSRegularExpression(pattern: "<.{6}")
        let descriptor = ORSSerialPacketDescriptor(regularExpression: regex, maximumPacketLength: 8, userInfo: nil)
        let promise = req.eventLoop.makePromise(of: Zone.self)
        
        let userInfo: [String: Any] = ["requestType": SerialRequestType.attributeChange,
                                       "promise": promise]
        
        let request = ORSSerialRequest(dataToSend: requestData,
                                       userInfo: userInfo,
                                       timeoutInterval: 5,
                                       responseDescriptor: descriptor)
        
        port.send(request)
        
        return "OK"
    }
    
    func bathroomOn(req: Request) throws -> String {
        let requestData = "<11pr00\r<12pr01\r".data(using: .ascii)!
        let regex = try NSRegularExpression(pattern: "<.{6}")
        let descriptor = ORSSerialPacketDescriptor(regularExpression: regex, maximumPacketLength: 8, userInfo: nil)
        let promise = req.eventLoop.makePromise(of: Zone.self)
        
        let userInfo: [String: Any] = ["requestType": SerialRequestType.attributeChange,
                                       "promise": promise]
        
        let request = ORSSerialRequest(dataToSend: requestData,
                                       userInfo: userInfo,
                                       timeoutInterval: 5,
                                       responseDescriptor: descriptor)
        
        port.send(request)
        
        return "OK"
    }
    
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
                      validBaudRates.contains(value) else {
                    status = .badRequest
                    break
                }
            }
        }
        return status
    }
    
    func changeZoneAttributes(req: Request) throws -> EventLoopFuture<Zone> {
        
        guard let zoneID = req.parameters.get("zoneid"),
              let attributeString = req.parameters.get("attribute"),
              let value = req.parameters.get("value"),
              let attribute = ZoneAttributeIdentifier(rawValue: attributeString.lowercased()) else {
            isWriting = false
            throw Abort(.preconditionFailed)
        }
        
        
        if attribute == .name {
            return try setNameForZone(req, zoneID: zoneID, name: value).flatMap({ (success) in
                self.isWriting = false
                return try! self.getSingleZone(req: req)
            })
        }
        
        let requestData = "<\(zoneID)\(attributeString)\(value)\r".data(using: .ascii)!
        let regex = try NSRegularExpression(pattern: "<.{6}")
        let descriptor = ORSSerialPacketDescriptor(regularExpression: regex, maximumPacketLength: 8, userInfo: nil)
        let promise = req.eventLoop.makePromise(of: Zone.self)
        
        let userInfo: [String: Any] = ["requestType": SerialRequestType.attributeChange,
                                       "promise": promise]
        
        let request = ORSSerialRequest(dataToSend: requestData,
                                       userInfo: userInfo,
                                       timeoutInterval: 5,
                                       responseDescriptor: descriptor)
        
        port.send(request)
        
        return promise.futureResult
    }
    
    func responseForAttributeChange(_ data: Data, request: ORSSerialRequest) {
        guard let userInfo = request.userInfo as? [String: Any],
              let promise = userInfo["promise"] as? EventLoopPromise<Zone>,
              let dataAsString = String(data: data, encoding: .ascii) else {
            return
        }
        
        guard let attributeUpdate = parseAttributeStatus(dataAsString),
              let index = indexOfZone(for: attributeUpdate.zoneID) else {
            promise.fail(FailureError.noResults)
            return
        }
        
        var zone = zones[index]
        
        switch attributeUpdate.attribute {
        case .pa:
            zone.pa = attributeUpdate.value
        case .power:
            zone.power = attributeUpdate.zoneID
        case .mute:
            zone.mute = attributeUpdate.zoneID
        case .doNotDisturb:
            zone.doNotDisturb = attributeUpdate.zoneID
        case .volume:
            zone.volume = attributeUpdate.zoneID
        case .treble:
            zone.treble = attributeUpdate.zoneID
        case .bass:
            zone.bass = attributeUpdate.zoneID
        case .balance:
            zone.balance = attributeUpdate.zoneID
        case .source:
            zone.source = attributeUpdate.zoneID
        case .name:
            break
        }
        
        zones[index].updateWith(zone)
        
        promise.succeed(zone)
    }
    
    // MARK: - GET
    
    func getSingleZone(req: Request) throws -> EventLoopFuture<Zone> {
        guard let zoneIDString = req.parameters.get("zoneid"),
              let zoneID = Int(zoneIDString) else {
            isWriting = false
            throw Abort(.preconditionFailed)
        }
        
        let requestData = "?\(zoneID)\r".data(using: .ascii)!
        
        let descriptor = ORSSerialPacketDescriptor(prefixString: "#>",
                                                   suffixString: "\n",
                                                   maximumPacketLength: 30,
                                                   userInfo: nil)
        
        let promise = req.eventLoop.makePromise(of: Zone.self)
        
        let userInfo: [String: Any] = ["requestType": SerialRequestType.getSingleZone,
                                       "zoneID": zoneID,
                                       "promise": promise]
        
        let request = ORSSerialRequest(dataToSend: requestData,
                                       userInfo: userInfo,
                                       timeoutInterval: 5,
                                       responseDescriptor: descriptor)
        
        
        port.send(request)
        return promise.futureResult
    }
    
    func responseForGettingSingleZone(_ data: Data, request: ORSSerialRequest) {
        //        #>1100010000190707100200
        guard let userInfo = request.userInfo as? [String: Any],
              let promise = userInfo["promise"] as? EventLoopPromise<Zone>,
              let zoneID = userInfo["zoneID"] as? Int,
              let dataAsString = String(data: data, encoding: .ascii) else { return }
        
        NSLog("Response: \(dataAsString)")
        guard let cleanStatus = dataAsString.components(separatedBy: ">").last else {
            promise.fail(FailureError.noZone)
            return
        }
        let success = parseZoneStatus(from: cleanStatus, for: zoneID)
        
        guard let index = indexOfZone(for: zoneID),
              success == true else {
            promise.fail(FailureError.noZone)
            return
        }
        
        promise.succeed(zones[index])
    }
    
    enum FailureError: Error {
        case noZone
        case noResults
    }
    
    func getAllZones(_ req: Request) throws -> EventLoopFuture<[Zone]> {
        // TODO: Keep track of how many amps are connected.
        
        
        //         TODO: Change the 6 in this regex to work with multiple controllers (12 for three or 18 for three controllers)
        
        let regex = try NSRegularExpression(pattern: "(#>.+\r\r\n{0,}){6}#", options: .useUnixLineSeparators)
        
        
        let requestData = "?10\r".data(using: .ascii)!
        //        let descriptor = ORSSerialPacketDescriptor(prefixString: "?10", suffixString: "\\r\\r", maximumPacketLength: 200, userInfo: nil)
        
        let descriptor = ORSSerialPacketDescriptor(regularExpression: regex,
                                                   //                                                   matchingOptions: .anchored,
                                                   maximumPacketLength: 200,
                                                   userInfo: nil)
        
        let promise = req.eventLoop.makePromise(of: [Zone].self)
        
        let userInfo: [String: Any] = ["requestType": SerialRequestType.getAllZones,
                                       "promise": promise]
        
        let request = ORSSerialRequest(dataToSend: requestData,
                                       userInfo: userInfo,
                                       timeoutInterval: 5,
                                       responseDescriptor: descriptor)
        
        
        port.send(request)
        return promise.futureResult
    }
    
    func responseForGettingAllZones(_ data: Data, request: ORSSerialRequest) {
        guard let userInfo = request.userInfo as? [String: Any],
              let promise = userInfo["promise"] as? EventLoopPromise<[Zone]>,
              let dataAsString = String(data: data, encoding: .ascii) else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            NSLog("Finishing string: \(dataAsString)")
        }
        
        let zones = parseAllZoneStatus(from: dataAsString)
        
        promise.succeed(zones)
        
    }
    
    // MARK: - Private
    
    func indexOfZone(for id: Int) -> Int? {
        guard let zone = zones.filter({ $0.id == id }).first else { return nil }
        return zones.firstIndex(of: zone)
    }
    
    @discardableResult private func updatePort() -> Bool {
        closePort()
        //        let port = SerialPort(path: currentSettings.path)
        //        port.setSettings(receiveRate: currentSettings.receiveRate,
        //                         transmitRate: currentSettings.transmitRate,
        //                         minimumBytesToRead: currentSettings.minimumBytesToRead)
        //
        do {
            //            self.port = port
            try openPort()
            return true
        } catch {
            NSLog("Error updating port: \(error)")
            return false
        }
    }
    
    func checkToClosePort() {
        let now = Date().timeIntervalSince1970
        
        if now > portCloseTime {
            if portIsOpen {
                NSLog("Closing port after inactivity")
                closePort()
            }
        }
    }
    
    private func updatePortCloseTime() {
        portCloseTime = Date().timeIntervalSince1970 + 2
    }
    
    private func openPort() throws {
        if !portIsOpen {
            //            try port.openPort()
            usleep(100000)
            portIsOpen = true
        }
    }
    
    private func closePort() {
        //        guard port != nil else { return }
        //        port.closePort()
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
    
    private func setNameForZone(_ req: Request, zoneID: String, name: String) throws -> EventLoopFuture<Bool> {
        
        guard let zoneID = Int(zoneID) else {
            return req.eventLoop.makeSucceededFuture(false)
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
                        var success = false
                        if let index = self.indexOfZone(for: zoneNameToSave.zoneID) {
                            self.zones[index].name = name
                            success = true
                        }
                        return req.eventLoop.makeSucceededFuture(success)
                    })
            }
    }
    
    // MARK: - String Parsing From Serial Connection
    
    @discardableResult private func parseZoneStatus(from string: String, for zoneID: Int? = nil) -> Bool {
        var zoneString = string
        
        zoneString = zoneString
            .replacingOccurrences(of: "\r\r", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "#", with: "")
        
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
    
    private func parseAllZoneStatus(from string: String) -> [Zone] {
        
        var zoneStrings = string.components(separatedBy: "#>")
        zoneStrings.removeFirst()
        
        for zoneString in zoneStrings {
            parseZoneStatus(from: zoneString)
        }
        
        return zones
    }
    
    
    private func parseAttributeStatus(_ attributeString: String) -> ZoneAttributeUpdate? {
        let cleanString = attributeString.components(separatedBy: "<").last ?? ""
        
        guard cleanString.count >= 6 else { return nil }
        
        var zoneString = ""
        var attributeString = ""
        var valueString = ""
        
        for (index, character) in cleanString.enumerated() {
            switch index {
            case 0, 1:
                zoneString += "\(character)"
            case 2, 3:
                attributeString += "\(character)"
            case 4, 5:
                valueString += "\(character)"
            default:
                break
            }
        }
        
        guard let attribute = ZoneAttributeIdentifier(rawValue: attributeString),
              let zoneID = Int(zoneString),
              let value = Int(valueString) else {
            NSLog("Unable to parse attribute status")
            return nil
        }
        
        return ZoneAttributeUpdate(zoneID: zoneID, attribute: attribute, value: value)
    }
    
    var buffer = ""
}

extension SerialController: ORSSerialPortDelegate {
    
    func serialPortWasClosed(_ serialPort: ORSSerialPort) {
        NSLog("Port closed")
    }
    
    func serialPortWasOpened(_ serialPort: ORSSerialPort) {
        NSLog("Port opened")
    }
    
    func serialPortWasRemovedFromSystem(_ serialPort: ORSSerialPort) {
        NSLog("Removed from system")
    }
    
    func serialPort(_ serialPort: ORSSerialPort, didReceive data: Data) {
        let dataString = String(data: data, encoding: .ascii)!
        buffer += dataString
        NSLog("Data received: \(buffer)")
    }
    
    func serialPort(_ serialPort: ORSSerialPort, didEncounterError error: Error) {
        NSLog("Error with port: \(error)")
    }
    
    func serialPort(_ serialPort: ORSSerialPort, requestDidTimeout request: ORSSerialRequest) {
        NSLog("Timeout requested: \(request.timeoutInterval)")
    }
    
    func serialPort(_ serialPort: ORSSerialPort, didReceiveResponse responseData: Data, to request: ORSSerialRequest) {
        
        guard let userInfo = request.userInfo as? [String: Any],
              let requestType = userInfo["requestType"] as? SerialRequestType else { return }
        
        
        switch requestType {
        case .getSingleZone:
            responseForGettingSingleZone(responseData, request: request)
        case .getAllZones:
            responseForGettingAllZones(responseData, request: request)
        case .attributeChange:
            responseForAttributeChange(responseData, request: request)
        }
        buffer = ""
        
        //        let dataString = String(data: responseData, encoding: .utf8)!
        //
        //        NSLog("Response received: \(dataString)")
    }
    
    func serialPort(_ serialPort: ORSSerialPort, didReceivePacket packetData: Data, matching descriptor: ORSSerialPacketDescriptor) {
        let dataString = String(data: packetData, encoding: .ascii)!
        NSLog("Packet received: \(dataString)")
    }
}
