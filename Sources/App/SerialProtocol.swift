//
//  SerialProtocol.swift
//
//
//  Hardware-independent parsing and command building for the Monoprice
//  multizone amplifier's RS-232 protocol. Kept free of any ORSSerialPort
//  dependency so the wire format can be unit tested without a serial port.
//

import Foundation

enum SerialProtocol {

    // MARK: - Command Building

    /// `?10\r` — request the status of all six zones on amp unit 1.
    static func queryAllZonesCommand() -> Data {
        Data("?10\r".utf8)
    }

    /// `?<zoneID>\r` — request the status of a single zone.
    static func querySingleZoneCommand(zoneID: Int) -> Data {
        Data("?\(zoneID)\r".utf8)
    }

    /// `<<zone><attr><value>\r` — set one attribute on one zone, e.g. `<11vo15`.
    static func attributeCommand(zoneID: String, attribute: String, value: String) -> Data {
        Data("<\(zoneID)\(attribute)\(value)\r".utf8)
    }

    // MARK: - Response Parsing

    /// Parses a single zone status reply such as `#>1100010000190707100200`.
    ///
    /// Digits are read in fixed two-character fields, positionally mapped to
    /// id, pa, power, mute, doNotDisturb, volume, treble, bass, balance, source.
    /// Returns `nil` if a complete field is non-numeric, surfacing a bad reply
    /// instead of silently decoding it as zeros.
    static func parseZoneStatus(from string: String) -> Zone? {
        let cleaned = string
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: ">", with: "")

        var values: [Int] = []
        var pair = ""
        for character in cleaned {
            pair.append(character)
            if pair.count == 2 {
                guard let value = Int(pair) else { return nil }
                values.append(value)
                pair = ""
            }
        }

        guard let id = values.first else { return nil }

        var zone = Zone(id: id)
        let fields: [WritableKeyPath<Zone, Int>] = [
            \.id, \.pa, \.power, \.mute, \.doNotDisturb,
            \.volume, \.treble, \.bass, \.balance, \.source
        ]
        for (index, keyPath) in fields.enumerated() where index < values.count {
            zone[keyPath: keyPath] = values[index]
        }
        return zone
    }

    /// Parses a combined reply containing several `#>...` zone records.
    static func parseAllZoneStatus(from string: String) -> [Zone] {
        var records = string.components(separatedBy: "#>")
        if !records.isEmpty { records.removeFirst() }
        return records.compactMap { parseZoneStatus(from: $0) }
    }

    /// Parses an attribute-change echo such as `<11vo15`.
    static func parseAttributeStatus(_ attributeString: String) -> ZoneAttributeUpdate? {
        let cleanString = attributeString.components(separatedBy: "<").last ?? ""
        guard cleanString.count >= 6 else { return nil }

        var zoneString = ""
        var attributeCode = ""
        var valueString = ""

        for (index, character) in cleanString.enumerated() {
            switch index {
            case 0, 1: zoneString.append(character)
            case 2, 3: attributeCode.append(character)
            case 4, 5: valueString.append(character)
            default: break
            }
        }

        guard let attribute = ZoneAttributeIdentifier(rawValue: attributeCode),
            let zoneID = Int(zoneString),
            let value = Int(valueString) else {
                return nil
        }

        return ZoneAttributeUpdate(zoneID: zoneID, attribute: attribute, value: value)
    }
}
