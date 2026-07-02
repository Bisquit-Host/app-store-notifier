// swift-tools-version:6.3.2
import PackageDescription

let package = Package(
    name: "AppStoreNotifier",
    platforms: [
       .macOS(.v13)
    ],
    dependencies: [
        // Web framework
        // https://github.com/vapor/vapor
        .package(url: "https://github.com/vapor/vapor.git", from: "4.122.0"),
        
        // https://github.com/apple/app-store-server-library-swift
        .package(url: "https://github.com/apple/app-store-server-library-swift.git", .upToNextMajor(from: "6.0.0")),
        
        // https://github.com/vapor/fluent
        .package(url: "https://github.com/vapor/fluent.git", from: "4.12.0"),
        
        // https://github.com/vapor/fluent-postgres-driver
        .package(url: "https://github.com/vapor/fluent-postgres-driver.git", from: "2.10.0"),
        
        // https://github.com/Mikroservices/Smtp
        .package(url: "https://github.com/Mikroservices/Smtp.git", from: "3.1.2"),
        
        // Networking
        // https://github.com/apple/swift-nio
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.101.0")
    ],
    targets: [
        .executableTarget(
            name: "AppStoreNotifier",
            dependencies: [
                .product(name: "AppStoreServerLibrary", package: "app-store-server-library-swift"),
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"),
                .product(name: "Smtp", package: "Smtp"),
                .product(name: "Vapor", package: "vapor"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio")
            ],
            resources: [
                .process("Resources")
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "AppStoreNotifierTests",
            dependencies: [
                .target(name: "AppStoreNotifier"),
                .product(name: "VaporTesting", package: "vapor")
            ],
            swiftSettings: swiftSettings
        )
    ]
)

var swiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("ExistentialAny")
]
