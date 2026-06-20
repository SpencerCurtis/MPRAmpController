//
//  SerialController.swift
//
//
//  Created by Spencer Curtis on 6/30/20.
//

import Foundation
import Vapor
import Fluent
import ORSSerial

final class SerialController: NSObject, RouteCollection {

    var port: ORSSerialPort?
    var currentSettings: PortSettings

    var zones: [Zone] = [Zone(id: 11),
                         Zone(id: 12),
                         Zone(id: 13),
                         Zone(id: 14),
                         Zone(id: 15),
                         Zone(id: 16)]

    private let validBaudRates: [Int] = [9600, 19200, 38400, 57600, 115200, 230400]

    let application: Application

    enum FailureError: Error {
        case noDevice
        case noZone
        case noResults
        case timeout
    }

    // MARK: - Initialization

    init(app: Application) {
        self.application = app
        let availablePort = ORSSerialPortManager.shared().availablePorts
            .first(where: { $0.name.contains("usbserial") })
        availablePort?.baudRate = 9600
        self.port = availablePort
        self.currentSettings = PortSettings(path: availablePort?.path ?? "", minimumBytesToRead: 0)
        super.init()
    }

    // MARK: - Routing

    func boot(routes: RoutesBuilder) throws {
        if let port = port, port.delegate == nil {
            port.delegate = self
            port.open()
        }
        routes.get("zones", use: getAllZones)
        routes.get("zones", ":zoneid", use: getSingleZone)
        routes.post("zones", ":zoneid", ":attribute", ":value", use: changeZoneAttributes)
        routes.post("settings", use: changeSettings)
    }

    // MARK: - GET

    func getAllZones(_ req: Request) async throws -> [Zone] {
        // TODO: Support multiple chained amps (the descriptor is hardcoded to 6 zones / 1 amp).
        let regex = try NSRegularExpression(pattern: "(#>.+\r\r\n{0,}){6}#", options: .useUnixLineSeparators)
        let descriptor = ORSSerialPacketDescriptor(regularExpression: regex, maximumPacketLength: 200, userInfo: nil)

        let _: [Zone] = try await send(
            SerialProtocol.queryAllZonesCommand(),
            requestType: .getAllZones,
            descriptor: descriptor
        )
        await loadZoneNames(on: req.db)
        return zones
    }

    func getSingleZone(req: Request) async throws -> Zone {
        guard let zoneIDString = req.parameters.get("zoneid"),
            let zoneID = Int(zoneIDString) else {
                throw Abort(.preconditionFailed)
        }

        let descriptor = ORSSerialPacketDescriptor(
            prefixString: "#>",
            suffixString: "\n",
            maximumPacketLength: 30,
            userInfo: nil
        )

        let _: Zone = try await send(
            SerialProtocol.querySingleZoneCommand(zoneID: zoneID),
            requestType: .getSingleZone,
            descriptor: descriptor
        )
        await loadZoneNames(on: req.db)

        guard let index = indexOfZone(for: zoneID) else { throw Abort(.notFound) }
        return zones[index]
    }

    // MARK: - POST

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

        let regex = try NSRegularExpression(pattern: "<.{6}")
        let descriptor = ORSSerialPacketDescriptor(regularExpression: regex, maximumPacketLength: 8, userInfo: nil)

        return try await send(
            SerialProtocol.attributeCommand(zoneID: zoneID, attribute: attributeString, value: value),
            requestType: .attributeChange,
            descriptor: descriptor
        )
    }

    func changeSettings(req: Request) throws -> HTTPResponseStatus {
        guard let settingsDictionary = try? req.content.decode([String: String].self) else {
            return .badRequest
        }

        for (key, value) in settingsDictionary {
            guard let identifier = SettingIdentifier(rawValue: key) else { continue }

            switch identifier {
            case .path:
                currentSettings.path = value
            case .receiveRate, .transmitRate:
                guard let rate = Int(value), validBaudRates.contains(rate) else {
                    return .badRequest
                }
            }
        }
        return .ok
    }

    // MARK: - Serial Bridge

    /// Sends a serial request and suspends until the matching response (or a timeout)
    /// arrives, bridging ORSSerialPort's delegate callbacks into async/await.
    private func send<T>(
        _ data: Data,
        requestType: SerialRequestType,
        descriptor: ORSSerialPacketDescriptor
    ) async throws -> T {
        guard let port = port else { throw FailureError.noDevice }

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<T, Error>) in
            let userInfo: [String: Any] = [
                "requestType": requestType,
                "resumer": Resumer(continuation)
            ]
            let request = ORSSerialRequest(
                dataToSend: data,
                userInfo: userInfo,
                timeoutInterval: 5,
                responseDescriptor: descriptor
            )
            port.send(request)
        }
    }

    private func responseForGettingSingleZone(_ data: Data, request: ORSSerialRequest) {
        guard let resumer = request.resumer,
            let dataAsString = String(data: data, encoding: .ascii) else { return }

        guard let cleanStatus = dataAsString.components(separatedBy: ">").last,
            let parsed = SerialProtocol.parseZoneStatus(from: cleanStatus),
            let index = indexOfZone(for: parsed.id) else {
                resumer.fail(FailureError.noZone)
                return
        }

        zones[index].updateWith(parsed)
        resumer.succeed(zones[index])
    }

    private func responseForGettingAllZones(_ data: Data, request: ORSSerialRequest) {
        guard let resumer = request.resumer,
            let dataAsString = String(data: data, encoding: .ascii) else { return }

        for parsed in SerialProtocol.parseAllZoneStatus(from: dataAsString) {
            guard let index = indexOfZone(for: parsed.id) else { continue }
            zones[index].updateWith(parsed)
        }
        resumer.succeed(zones)
    }

    private func responseForAttributeChange(_ data: Data, request: ORSSerialRequest) {
        guard let resumer = request.resumer,
            let dataAsString = String(data: data, encoding: .ascii) else { return }

        guard let update = SerialProtocol.parseAttributeStatus(dataAsString),
            let index = indexOfZone(for: update.zoneID) else {
                resumer.fail(FailureError.noResults)
                return
        }

        zones[index].apply(update)
        resumer.succeed(zones[index])
    }

    // MARK: - Zone Names

    private func loadZoneNames(on database: Database) async {
        do {
            let fetched = try await ZoneName.query(on: database).all()
            for zoneName in fetched {
                guard let index = indexOfZone(for: zoneName.zoneID) else { continue }
                zones[index].name = zoneName.name
            }
        } catch {
            application.logger.error("Zone names could not be fetched: \(error)")
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

        if let index = indexOfZone(for: zoneID) {
            zones[index].name = name
        }
    }

    // MARK: - Helpers

    func indexOfZone(for id: Int) -> Int? {
        zones.firstIndex(where: { $0.id == id })
    }
}

// MARK: - ORSSerialPortDelegate

extension SerialController: ORSSerialPortDelegate {

    func serialPortWasClosed(_ serialPort: ORSSerialPort) {
        application.logger.info("Serial port closed")
    }

    func serialPortWasOpened(_ serialPort: ORSSerialPort) {
        application.logger.info("Serial port opened")
    }

    func serialPortWasRemovedFromSystem(_ serialPort: ORSSerialPort) {
        application.logger.warning("Serial port removed from system")
        if port === serialPort { port = nil }
    }

    func serialPort(_ serialPort: ORSSerialPort, didEncounterError error: Error) {
        application.logger.error("Serial port error: \(error)")
    }

    func serialPort(_ serialPort: ORSSerialPort, requestDidTimeout request: ORSSerialRequest) {
        request.resumer?.fail(FailureError.timeout)
    }

    func serialPort(_ serialPort: ORSSerialPort, didReceiveResponse responseData: Data, to request: ORSSerialRequest) {
        guard let requestType = request.requestType else { return }
        switch requestType {
        case .getSingleZone:
            responseForGettingSingleZone(responseData, request: request)
        case .getAllZones:
            responseForGettingAllZones(responseData, request: request)
        case .attributeChange:
            responseForAttributeChange(responseData, request: request)
        }
    }
}

// MARK: - ORSSerialRequest userInfo accessors

private extension ORSSerialRequest {
    var userInfoDictionary: [String: Any]? { userInfo as? [String: Any] }
    var resumer: Resumer? { userInfoDictionary?["resumer"] as? Resumer }
    var requestType: SerialRequestType? { userInfoDictionary?["requestType"] as? SerialRequestType }
}

/// Type-erased, one-shot bridge from a serial delegate callback back to an awaiting
/// continuation. Guards against double-resume if a response and a timeout race.
final class Resumer {
    private var resume: ((Result<Any, Error>) -> Void)?

    init<T>(_ continuation: CheckedContinuation<T, Error>) {
        resume = { result in
            switch result {
            case .success(let value): continuation.resume(returning: value as! T)
            case .failure(let error): continuation.resume(throwing: error)
            }
        }
    }

    func succeed(_ value: Any) {
        resume?(.success(value))
        resume = nil
    }

    func fail(_ error: Error) {
        resume?(.failure(error))
        resume = nil
    }
}
