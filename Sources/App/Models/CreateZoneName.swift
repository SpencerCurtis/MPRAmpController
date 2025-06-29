import Fluent
import SQLKit
import FluentSQLiteDriver

/// Migration to create the zoneNames table for storing custom zone names
struct CreateZoneName: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        // Check if we can cast to SQLDatabase for raw SQL capability
        guard let sqlDatabase = database as? SQLDatabase else {
            // Fallback to original schema-based approach if raw SQL isn't available
            return database.schema("zoneNames")
                .id()
                .field("name", .string, .required)
                .field("zoneID", .int, .required)
                .unique(on: "zoneID")
                .create()
        }
        
        // Use raw SQL with IF NOT EXISTS to handle existing tables gracefully
        return sqlDatabase.raw("""
            CREATE TABLE IF NOT EXISTS "zoneNames" (
                "id" UUID PRIMARY KEY DEFAULT (lower(hex(randomblob(4))) || '-' || lower(hex(randomblob(2))) || '-4' || substr(lower(hex(randomblob(2))),2) || '-' || substr('89ab',abs(random()) % 4 + 1, 1) || substr(lower(hex(randomblob(2))),2) || '-' || lower(hex(randomblob(6)))),
                "name" TEXT NOT NULL,
                "zoneID" INTEGER NOT NULL UNIQUE
            );
        """).run()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("zoneNames").delete()
    }
} 