// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "deque-deinit-order",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../..")
    ],
    targets: [
        .executableTarget(
            name: "deque-deinit-order",
            dependencies: [
                .product(name: "Deque Primitives", package: "swift-deque-primitives")
            ]
        )
    ]
)
