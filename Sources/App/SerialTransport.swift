//
//  SerialTransport.swift
//
//
//  Abstracts the serial link so SerialController can be exercised without real
//  hardware. ORSSerialTransport is the production implementation; tests inject a
//  fake that returns canned replies.
//

import Foundation

/// How ORSSerialPort should recognize the end of a reply to a command.
enum SerialResponseMatcher {
    case regex(pattern: String, maxLength: Int)
    case prefixSuffix(prefix: String, suffix: String, maxLength: Int)
}

protocol SerialTransport: AnyObject {
    /// Sends a command and returns the bytes of the matching reply,
    /// or throws on timeout / no connected device.
    func send(_ command: Data, matching matcher: SerialResponseMatcher) async throws -> Data
}
