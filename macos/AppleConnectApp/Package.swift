// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "AppleConnectApp",
    defaultLocalization: "en",
    platforms: [
        .macOS("26.0")
    ],
    products: [
        .executable(name: "AppleConnectApp", targets: ["AppleConnectApp"])
    ],
    targets: [
        .executableTarget(
            name: "AppleConnectApp",
            exclude: [
                "Resources/fact.icon"
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "AppleConnectAppTests",
            dependencies: ["AppleConnectApp"]
        )
    ]
)
