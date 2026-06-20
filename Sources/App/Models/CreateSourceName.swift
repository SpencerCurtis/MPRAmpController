//
//  CreateSourceName.swift
//
//

import Fluent

struct CreateSourceName: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(SourceName.schema)
            .id()
            .field("sourceID", .int, .required)
            .field("name", .string, .required)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(SourceName.schema).delete()
    }
}
