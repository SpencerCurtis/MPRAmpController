//
//  File.swift
//  
//
//  Created by Spencer Curtis on 7/28/20.
//

import Fluent

struct CreateZone: Migration {
    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(ZoneName.schema)
                .delete()
    }
    
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(ZoneName.schema)
            .id()
            .field("zoneID", .int, .required)
            .field("name", .string, .required)
            .create()
    }
}
