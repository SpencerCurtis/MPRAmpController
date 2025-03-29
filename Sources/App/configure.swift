import Vapor
import Fluent
import FluentSQLiteDriver
import Leaf

// Called before your application initializes.
public func configure(_ app: Application) throws {
    // Configure Leaf
    app.views.use(.leaf)
    
    // Serves files from `Public/` directory
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    // Configure SQLite database
//    app.databases.use(.sqlite(.file("db.sqlite")), as: .sqlite)

    // Configure migrations
   app.http.server.configuration.hostname = "0.0.0.0"
   app.http.server.configuration.port = 8001
    
    app.databases.use(.sqlite(.file("zones.sqlite")), as: .sqlite)
    app.migrations.add(CreateZone())
    try app.autoMigrate().wait()
    try routes(app)
}
