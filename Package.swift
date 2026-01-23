// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "swift-deque-primitives",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .tvOS(.v26),
        .watchOS(.v26),
        .visionOS(.v26)
    ],
    products: [
        .library(
            name: "Deque Primitives",
            targets: ["Deque Primitives"]
        )
    ],
    dependencies: [
        .package(path: "../swift-property-primitives"),
        .package(path: "../swift-index-primitives"),
        .package(path: "../swift-input-primitives"),
        .package(path: "../swift-collection-primitives"),
    ],
    targets: [
        // Internal: Core types with ~Copyable support (no Sequence/Collection.Protocol conformances)
        .target(
            name: "Deque Primitives Core",
            dependencies: [
                .product(name: "Property Primitives", package: "swift-property-primitives"),
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                .product(name: "Input Primitives", package: "swift-input-primitives"),
                .product(name: "Collection Primitives", package: "swift-collection-primitives"),
            ]
        ),
        // Internal: Sequence/Collection.Protocol conformances (Element: Copyable)
        // Separate module to avoid constraint poisoning on Core types
        .target(
            name: "Deque Primitives Sequence",
            dependencies: [
                "Deque Primitives Core",
                .product(name: "Collection Primitives", package: "swift-collection-primitives"),
            ]
        ),
        // Public: Re-exports Core and Sequence for users
        .target(
            name: "Deque Primitives",
            dependencies: [
                "Deque Primitives Core",
                "Deque Primitives Sequence",
            ]
        ),
        .testTarget(
            name: "Deque Primitives Tests",
            dependencies: ["Deque Primitives"]
        )
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let settings: [SwiftSetting] = [
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableExperimentalFeature("Lifetimes"),
        .strictMemorySafety()
    ]
    target.swiftSettings = (target.swiftSettings ?? []) + settings
}
