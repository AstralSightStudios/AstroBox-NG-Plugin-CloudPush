// swift-tools-version:6.1.0

import PackageDescription

let package = Package(
    name: "cloud-push",
    platforms: [
        .iOS(.v15),
    ],
    products: [
        .library(
            name: "cloud-push",
            type: .static,
            targets: ["cloud-push"]),
    ],
    dependencies: [
        .package(name: "Tauri", path: "../.tauri/tauri-api")
    ],
    targets: [
        .target(
            name: "cloud-push",
            dependencies: [
                .byName(name: "Tauri")
            ],
            path: "Sources",
            linkerSettings: [
                .linkedFramework("Foundation"),
                .linkedFramework("UIKit"),
                .linkedFramework("UserNotifications")
            ]
        )
    ]
)
