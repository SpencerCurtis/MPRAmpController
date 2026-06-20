import Vapor

func routes(_ app: Application) throws {
    let transport = ORSSerialTransport(logger: app.logger)
    let controller = SerialController(transport: transport)
    try app.register(collection: controller)
}
