//
//  CreatePreset.swift
//
//

import Fluent

struct CreatePreset: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(Preset.schema)
            .id()
            .field("name", .string, .required)
            .field("zones", .string, .required)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(Preset.schema).delete()
    }
}
