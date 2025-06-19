import Vapor
import Fluent
import FluentSQLiteDriver
import Leaf

// Called before your application initializes.
public func configure(_ app: Application) throws {
    // Configure Leaf
    app.views.use(.leaf)
    
    // Set custom path for Resources directory
    let workingDirectory = DirectoryConfiguration.detect().workingDirectory
    
    // Check if we're running from development or binary deployment
    let developmentViewsPath = workingDirectory + "Sources/App/Resources/Views"
    let binaryViewsPath = workingDirectory + "Resources/Views"
    
    if FileManager.default.fileExists(atPath: developmentViewsPath) {
        app.directory.viewsDirectory = developmentViewsPath
        print("📁 Using development views path: \(developmentViewsPath)")
    } else if FileManager.default.fileExists(atPath: binaryViewsPath) {
        app.directory.viewsDirectory = binaryViewsPath
        print("📁 Using binary deployment views path: \(binaryViewsPath)")
    } else {
        // Use embedded templates - create them in a temporary directory
        do {
            let embeddedViewsPath = try EmbeddedTemplates.createTempViewsDirectory()
            app.directory.viewsDirectory = embeddedViewsPath
            print("📁 Using embedded templates in: \(embeddedViewsPath)")
        } catch {
            print("❌ Failed to create embedded templates: \(error)")
            // Fallback to default path
        }
    }
    
    // Debug logging
    print("Working Directory: \(workingDirectory)")
    print("Views Directory: \(app.directory.viewsDirectory)")
    
    // Serves files from `Public/` directory
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    
    // Configure CORS
    let corsConfiguration = CORSMiddleware.Configuration(
        allowedOrigin: .all,
        allowedMethods: [.GET, .POST, .PUT, .OPTIONS, .DELETE, .PATCH],
        allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith, .userAgent, .accessControlAllowOrigin]
    )
    let cors = CORSMiddleware(configuration: corsConfiguration)
    app.middleware.use(cors)

    // Configure SQLite database
    app.databases.use(.sqlite(.file("zones.sqlite")), as: .sqlite)
    
    // Configure migrations
    app.http.server.configuration.hostname = "0.0.0.0"
    app.http.server.configuration.port = 8001
    
    app.migrations.add(CreateZone())
    app.migrations.add(CreateZoneName())
    try app.autoMigrate().wait()
    try routes(app)
}
