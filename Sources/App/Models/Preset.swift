//
//  Preset.swift
//
//
//  A saved snapshot of zone settings that can be recalled as a "scene".
//

import Foundation
import Fluent
import Vapor

final class Preset: Model {
    static let schema = "presets"

    @ID var id: UUID?
    @Field(key: "name") var name: String
    @Field(key: "zones") var zonesData: String

    init() {}

    init(id: UUID? = nil, name: String, zones: [PresetZone]) {
        self.id = id
        self.name = name
        self.zones = zones
    }

    /// Per-zone settings, stored as JSON in the `zones` column.
    var zones: [PresetZone] {
        get { (try? JSONDecoder().decode([PresetZone].self, from: Data(zonesData.utf8))) ?? [] }
        set { zonesData = (try? String(decoding: JSONEncoder().encode(newValue), as: UTF8.self)) ?? "[]" }
    }
}

/// The recallable settings for one zone within a preset.
struct PresetZone: Content {
    let zone: Int
    let power: Int
    let source: Int
    let volume: Int
}

/// API representation of a `Preset` that exposes `zones` as structured JSON
/// rather than the stored string column.
struct PresetDTO: Content {
    let id: UUID?
    let name: String
    let zones: [PresetZone]

    init(_ preset: Preset) {
        id = preset.id
        name = preset.name
        zones = preset.zones
    }
}
