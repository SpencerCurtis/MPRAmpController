// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "MPRAmpController",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .executable(name: "Run", targets: ["Run"]),
        .library(name: "App", targets: ["App"]),
    ],
    dependencies: [
        // 💧 A server-side Swift web framework.
        .package(url: "https://github.com/vapor/vapor.git", .exact("4.77.1")),
        .package(url: "https://github.com/armadsen/ORSSerialPort.git", .exact("2.1.0")),
        .package(url: "https://github.com/vapor/fluent.git", .exact("4.8.0")),
        .package(url: "https://github.com/vapor/fluent-sqlite-driver.git", .exact("4.5.0"))
    ],
    targets: [
        .target(
            name: "App",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "ORSSerial", package: "ORSSerialPort"),
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentSQLiteDriver", package: "fluent-sqlite-driver")
            ]
        ),
        .target(name: "Run", dependencies: [.target(name: "App")]),
        .testTarget(name: "AppTests", dependencies: [
            .target(name: "App"),
            .product(name: "XCTVapor", package: "vapor"),
        ])
    ]
)
