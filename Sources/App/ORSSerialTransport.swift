//
//  ORSSerialTransport.swift
//
//
//  Production SerialTransport backed by ORSSerialPort. All of the
//  delegate-callback-to-async bridging lives here, keeping SerialController free
//  of any hardware dependency.
//

import Foundation
import Logging
import ORSSerial

final class ORSSerialTransport: NSObject, SerialTransport {

    enum TransportError: Error {
        case noDevice
        case timeout
    }

    private var port: ORSSerialPort?
    private let logger: Logger

    init(logger: Logger) {
        self.port = ORSSerialPortManager.shared().availablePorts
            .first(where: { $0.name.contains("usbserial") })
        self.logger = logger
        super.init()
        port?.baudRate = 9600
        port?.delegate = self
        port?.open()
    }

    func send(_ command: Data, matching matcher: SerialResponseMatcher) async throws -> Data {
        guard let port = port else { throw TransportError.noDevice }
        let descriptor = try descriptor(for: matcher)

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
            let request = ORSSerialRequest(
                dataToSend: command,
                userInfo: ContinuationBox(continuation),
                timeoutInterval: 5,
                responseDescriptor: descriptor
            )
            port.send(request)
        }
    }

    private func descriptor(for matcher: SerialResponseMatcher) throws -> ORSSerialPacketDescriptor {
        switch matcher {
        case let .regex(pattern, maxLength):
            let regex = try NSRegularExpression(pattern: pattern, options: .useUnixLineSeparators)
            return ORSSerialPacketDescriptor(regularExpression: regex, maximumPacketLength: UInt(maxLength), userInfo: nil)
        case let .prefixSuffix(prefix, suffix, maxLength):
            return ORSSerialPacketDescriptor(prefixString: prefix, suffixString: suffix, maximumPacketLength: UInt(maxLength), userInfo: nil)
        }
    }
}

// MARK: - ORSSerialPortDelegate

extension ORSSerialTransport: ORSSerialPortDelegate {

    func serialPortWasOpened(_ serialPort: ORSSerialPort) {
        logger.info("Serial port opened")
    }

    func serialPortWasClosed(_ serialPort: ORSSerialPort) {
        logger.info("Serial port closed")
    }

    func serialPortWasRemovedFromSystem(_ serialPort: ORSSerialPort) {
        logger.warning("Serial port removed from system")
        if port === serialPort { port = nil }
    }

    func serialPort(_ serialPort: ORSSerialPort, didEncounterError error: Error) {
        logger.error("Serial port error: \(error)")
    }

    func serialPort(_ serialPort: ORSSerialPort, requestDidTimeout request: ORSSerialRequest) {
        (request.userInfo as? ContinuationBox)?.resume(throwing: TransportError.timeout)
    }

    func serialPort(_ serialPort: ORSSerialPort, didReceiveResponse responseData: Data, to request: ORSSerialRequest) {
        (request.userInfo as? ContinuationBox)?.resume(returning: responseData)
    }
}

/// One-shot wrapper around a continuation; guards against double-resume if a
/// reply and a timeout race for the same request.
final class ContinuationBox {
    private var continuation: CheckedContinuation<Data, Error>?

    init(_ continuation: CheckedContinuation<Data, Error>) {
        self.continuation = continuation
    }

    func resume(returning data: Data) {
        continuation?.resume(returning: data)
        continuation = nil
    }

    func resume(throwing error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}
