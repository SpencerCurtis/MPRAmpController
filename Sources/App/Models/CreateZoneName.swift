import Fluent

/// Migration to create the zoneNames table for storing custom zone names
struct CreateZoneName: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("zoneNames")
            .id()
            .field("name", .string, .required)
            .field("zoneID", .int, .required)
            .unique(on: "zoneID") // Ensure each zone can only have one custom name
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("zoneNames").delete()
    }
} 