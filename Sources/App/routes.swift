import Vapor

func routes(_ app: Application) throws {
    // Environment-based controller selection
    let useMockController = Environment.get("USE_MOCK_CONTROLLER") == "true"
    
    let controller: ZoneControllerProtocol = useMockController 
        ? MockZoneController(app: app) 
        : SerialController(app: app)
    
    NSLog("🎛️ Initialized \(useMockController ? "Mock" : "Serial") Zone Controller")
    
    try app.register(collection: controller)
    
    // Ultra-simple plain text test route (non-async)
    app.get("hello") { req -> String in
        return "Hello World! Server is working."
    }
    
    // Test route with simple data to isolate Leaf rendering (non-async)
    app.get("test") { req -> EventLoopFuture<View> in
        struct TestData: Encodable {
            let message: String
            let timestamp: String
            let items: [String]
        }
        
        let testData = TestData(
            message: "Hello from test route!",
            timestamp: "\(Date())",
            items: ["item1", "item2", "item3"]
        )
        return req.view.render("test", testData)
    }
    
    // Add root route to render zones.leaf (non-async)
    app.get { req -> EventLoopFuture<View> in
        let context = ZonesViewContext(zones: controller.zones)
        return req.view.render("zones", context)
    }
}
