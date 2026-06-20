import Vapor

func routes(_ app: Application) throws {
    // USE_MOCK_CONTROLLER=true runs the whole server with no amplifier attached.
    let useMock = Environment.get("USE_MOCK_CONTROLLER") == "true"
    let transport: SerialTransport = useMock ? MockSerialTransport() : ORSSerialTransport(logger: app.logger)
    app.logger.info("Using \(useMock ? "mock" : "serial") transport")

    let controller = SerialController(transport: transport)
    try app.register(collection: controller)
}
