// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "deque-noncopyable-elements",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../..")
    ],
    targets: [
        .executableTarget(
            name: "deque-noncopyable-elements",
            dependencies: [
                .product(name: "Deque Primitives", package: "swift-deque-primitives")
            ]
        )
    ]
)
