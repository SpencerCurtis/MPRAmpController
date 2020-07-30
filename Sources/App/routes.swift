import Vapor

func routes(_ app: Application) throws {
    let serialController = SerialController(app: app)
    try app.register(collection: serialController)

}
