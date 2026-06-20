//
//  File.swift
//  
//
//  Created by Spencer Curtis on 7/1/20.
//

import Foundation

struct ZoneAttribute: Equatable {
    
    let zoneID: Int
    let identifier: ZoneAttributeIdentifier
    let name: String
    let minValue: Int
    let maxValue: Int
    var value: Int
}

extension ZoneAttributeIdentifier {
    /// Inclusive range of values the amplifier accepts, or `nil` for `name` (not a numeric attribute).
    var validRange: ClosedRange<Int>? {
        switch self {
        case .pa, .power, .mute, .doNotDisturb: return 0...1
        case .volume: return 0...38
        case .treble, .bass: return 0...14
        case .balance: return 0...20
        case .source: return 1...6
        case .name: return nil
        }
    }
}
