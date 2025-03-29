import Vapor
import Fluent
import FluentSQLiteDriver
import Leaf

// Called before your application initializes.
public func configure(_ app: Application) throws {
    // Serves files from `Public/` directory
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    
    // Configure views using Leaf
    app.views.use(.leaf)
    
    // Configure server
    app.http.server.configuration.hostname = "0.0.0.0"
    app.http.server.configuration.port = 8001
    
    // Configure database
    app.databases.use(.sqlite(.file("zones.sqlite")), as: .sqlite)
    app.migrations.add(CreateZone())
    try app.autoMigrate().wait()
    try routes(app)
}
