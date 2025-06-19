//
//  File.swift
//  
//
//  Created by Spencer Curtis on 7/28/20.
//

import Fluent

struct CreateZone: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("zones")
            .field("id", .int, .identifier(auto: false))
            .field("pa", .int, .required)
            .field("power", .int, .required)
            .field("mute", .int, .required)
            .field("doNotDisturb", .int, .required)
            .field("volume", .int, .required)
            .field("treble", .int, .required)
            .field("bass", .int, .required)
            .field("balance", .int, .required)
            .field("source", .int, .required)
            .field("name", .string, .required)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("zones").delete()
    }
}
