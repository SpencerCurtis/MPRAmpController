//
//  File.swift
//  
//
//  Created by Spencer Curtis on 7/1/20.
//

import Foundation
import Vapor
import Fluent

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

final class Zone: Model, Equatable {
    static func == (lhs: Zone, rhs: Zone) -> Bool {
        return lhs.id == rhs.id
    }
    
    static let schema = "zones"
    
    @ID(custom: "id")
    var id: Int?
    
    @Field(key: "pa")
    var pa: Int
    
    @Field(key: "power")
    var power: Int
    
    @Field(key: "mute")
    var mute: Int
    
    @Field(key: "doNotDisturb")
    var doNotDisturb: Int
    
    @Field(key: "volume")
    var volume: Int
    
    @Field(key: "treble")
    var treble: Int
    
    @Field(key: "bass")
    var bass: Int
    
    @Field(key: "balance")
    var balance: Int
    
    @Field(key: "source")
    var source: Int
    
    @Field(key: "name")
    var name: String
    
    init() {
        self.pa = -1
        self.power = -1
        self.mute = -1
        self.doNotDisturb = -1
        self.volume = -1
        self.treble = -1
        self.bass = -1
        self.balance = -1
        self.source = -1
        self.name = "Unknown"
    }
    
    init(id: Int = -1) {
        self.id = id
        self.pa = -1
        self.power = -1
        self.mute = -1
        self.doNotDisturb = -1
        self.volume = -1
        self.treble = -1
        self.bass = -1
        self.balance = -1
        self.source = -1
        self.name = id.description
    }
    
    func updateWith(_ zone: Zone) {
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
    
    convenience init(from decoder: Decoder) throws {
        self.init()
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
        self.name = self.id?.description ?? "Unknown"
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(formattedString(for: id ?? 0), forKey: .id)
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
        // Handle uninitialized values (default to "00" for off state)
        if value < 0 {
            return "00"
        }
        return value < 10 ? "0\(value)" : value.description
    }
}
