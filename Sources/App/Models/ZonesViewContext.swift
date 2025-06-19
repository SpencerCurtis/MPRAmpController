import Vapor

// Simple Zone struct for view rendering (not a Fluent model)
struct SimpleZone: Codable {
    let id: Int
    let pa: Int
    let power: Int
    let mute: Int
    let doNotDisturb: Int
    let volume: Int
    let treble: Int
    let bass: Int
    let balance: Int
    let source: Int
    let name: String
    
    init(from zone: Zone) {
        self.id = zone.id ?? -1
        self.pa = zone.pa
        self.power = zone.power
        self.mute = zone.mute
        self.doNotDisturb = zone.doNotDisturb
        self.volume = zone.volume
        self.treble = zone.treble
        self.bass = zone.bass
        self.balance = zone.balance
        self.source = zone.source
        self.name = zone.name
    }
}

struct ZonesViewContext: Encodable {
    let ampControllerUrl: String
    let hasError: Bool
    let zones: [SimpleZone]
    
    init(ampControllerUrl: String = "http://localhost:8001", hasError: Bool = false, zones: [Zone] = []) {
        self.ampControllerUrl = ampControllerUrl
        self.hasError = hasError
        self.zones = zones.map { SimpleZone(from: $0) }
    }
} 