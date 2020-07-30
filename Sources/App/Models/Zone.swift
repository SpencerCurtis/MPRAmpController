//
//  File.swift
//  
//
//  Created by Spencer Curtis on 7/1/20.
//

import Foundation
import Vapor

enum ZoneAttributeIdentifier: String, CaseIterable {
    case pa
    case power = "pr"
    case mute = "mu"
    case doNotDisturb = "dt"
    case volume = "vo"
    case treble = "tr"
    case bass = "bs"
    case balance = "bl"
    case source = "ch"
    case name
//    case keypadStatus = "ls"
}

struct Zone: Equatable {
    
    var id: Int
    var pa: Int
    var power: Int
    var mute: Int
    var doNotDisturb: Int
    var volume: Int
    var treble: Int
    var bass: Int
    var balance: Int
    var source: Int
    //    var keypadStatus: ZoneAttribute
    var name: String
    
    init(id: Int = -1) {
        self.id = id
        pa = -1
        power = -1
        mute = -1
        doNotDisturb = -1
        volume = -1
        treble = -1
        bass = -1
        balance = -1
        source = -1
        name = id.description
    }
    
    mutating func updateWith(_ zone: Zone) {
        id = zone.id
        pa = zone.pa
        power = zone.power
        mute = zone.mute
        doNotDisturb = zone.doNotDisturb
        volume = zone.volume
        treble = zone.treble
        bass = zone.bass
        balance = zone.balance
        source = zone.source
    }
}


extension Zone: Content {
     enum CodingKeys: String, CodingKey {
        case id = "zone"
        case pa
        case power = "pr"
        case mute = "mu"
        case doNotDisturb = "dt"
        case volume = "vo"
        case treble = "tr"
        case bass = "bs"
        case balance = "bl"
        case source = "ch"
        case keypadStatus = "ls"
        case name
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.id = Int(try container.decode(String.self, forKey: .id)) ?? 0
        self.pa = Int(try container.decode(String.self, forKey: .pa)) ?? 0
        self.power = Int(try container.decode(String.self, forKey: .power)) ?? 0
        self.mute = Int(try container.decode(String.self, forKey: .mute)) ?? 0
        self.doNotDisturb = Int(try container.decode(String.self, forKey: .doNotDisturb)) ?? 0
        self.volume = Int(try container.decode(String.self, forKey: .volume)) ?? 0
        self.treble = Int(try container.decode(String.self, forKey: .treble)) ?? 0
        self.bass = Int(try container.decode(String.self, forKey: .bass)) ?? 0
        self.balance = Int(try container.decode(String.self, forKey: .balance)) ?? 0
        self.source = Int(try container.decode(String.self, forKey: .source)) ?? 0
        self.name = self.id.description
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(formattedString(for: id), forKey: .id)
        try container.encode(formattedString(for: pa), forKey: .pa)
        try container.encode(formattedString(for: power), forKey: .power)
        try container.encode(formattedString(for: mute), forKey: .mute)
        try container.encode(formattedString(for: doNotDisturb), forKey: .doNotDisturb)
        try container.encode(formattedString(for: volume), forKey: .volume)
        try container.encode(formattedString(for: treble), forKey: .treble)
        try container.encode(formattedString(for: bass), forKey: .bass)
        try container.encode(formattedString(for: balance), forKey: .balance)
        try container.encode(formattedString(for: source), forKey: .source)
        try container.encode(self.name, forKey: .name)
    }
    
    private func formattedString(for value: Int) -> String {
        return value < 10 ? "0\(value)" : value.description
    }
}
