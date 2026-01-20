// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "deque-sendable-conformance",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../..")
    ],
    targets: [
        .executableTarget(
            name: "deque-sendable-conformance",
            dependencies: [
                .product(name: "Deque Primitives", package: "swift-deque-primitives")
            ]
        )
    ]
)
