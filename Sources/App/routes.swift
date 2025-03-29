import Vapor

func routes(_ app: Application) throws {
    let serialController = SerialController(app: app)
//    let serialController = MockSerialController(app: app)
    try app.register(collection: serialController)

}
