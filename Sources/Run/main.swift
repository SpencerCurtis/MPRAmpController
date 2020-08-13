import App
import Vapor

var env = try Environment.detect()
try LoggingSystem.bootstrap(from: &env)
let app = Application(env)
try configure(app)
let queue = DispatchQueue(label: "com.SpencerCurtis.runQueue")
let queue2 = DispatchQueue(label: "com.SpencerCurtis.runQueue2")
queue2.async {
//    defer { app.shutdown() }

    do {
        try app.run()
    } catch {
        NSLog("Error running app: \(error)")
    }
}

RunLoop.main.run()
