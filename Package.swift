// swift-tools-version: 6.3.1

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
        // MARK: - Type module (lean ~Copyable types; Copyable-requiring conformances live in the ops module per [MOD-004])
        // Module names follow the NESTED namespace `Queue.DoubleEnded`; the top-level `Deque` typealias lives here.
        .library(name: "Queue DoubleEnded Primitive", targets: ["Queue DoubleEnded Primitive"]),
        // MARK: - Ops module; `Queue DoubleEnded Primitives` doubles as the [MOD-005] umbrella
        .library(name: "Queue DoubleEnded Primitives", targets: ["Queue DoubleEnded Primitives"]),
        // Convenience alias product matching the package name.
        .library(name: "Deque Primitives", targets: ["Deque Primitives"]),
        .library(name: "Queue DoubleEnded Primitives Test Support", targets: ["Queue DoubleEnded Primitives Test Support"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-primitives/swift-queue-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-buffer-ring-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-buffer-linear-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-property-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-index-primitives.git", branch: "main"),
    ],
    targets: [

        // MARK: - Type module — lean ~Copyable Queue.DoubleEnded + nested variants/errors + `Deque` typealias ([MOD-036])
        //         Ring-backed (shares Buffer<Element>.Ring with the base Queue).
        .target(
            name: "Queue DoubleEnded Primitive",
            dependencies: [
                .product(name: "Queue Primitives Core", package: "swift-queue-primitives"),
                .product(name: "Buffer Ring Primitive", package: "swift-buffer-ring-primitives"),
                .product(name: "Buffer Ring Primitives", package: "swift-buffer-ring-primitives"),
                .product(name: "Buffer Ring Bounded Primitive", package: "swift-buffer-ring-primitives"),
                .product(name: "Buffer Ring Inline Primitives", package: "swift-buffer-ring-primitives"),
                .product(name: "Buffer Ring Small Primitive", package: "swift-buffer-ring-primitives"),
            ]
        ),

        // MARK: - Ops module + umbrella — Copyable conformances + ops, re-exports the type module
        .target(
            name: "Queue DoubleEnded Primitives",
            dependencies: [
                "Queue DoubleEnded Primitive",
                .product(name: "Queue Primitives Core", package: "swift-queue-primitives"),
                .product(name: "Buffer Ring Primitive", package: "swift-buffer-ring-primitives"),
                .product(name: "Buffer Ring Primitives", package: "swift-buffer-ring-primitives"),
                .product(name: "Buffer Ring Bounded Primitive", package: "swift-buffer-ring-primitives"),
                .product(name: "Buffer Ring Inline Primitives", package: "swift-buffer-ring-primitives"),
                .product(name: "Buffer Linear Primitive", package: "swift-buffer-linear-primitives"),
                .product(name: "Buffer Linear Primitives", package: "swift-buffer-linear-primitives"),
                .product(name: "Property Primitives", package: "swift-property-primitives"),
            ]
        ),

        // MARK: - Deque umbrella — package-name-facing re-export so consumers `import Deque_Primitives`
        .target(
            name: "Deque Primitives",
            dependencies: ["Queue DoubleEnded Primitives"]
        ),

        // MARK: - Test Support
        .target(
            name: "Queue DoubleEnded Primitives Test Support",
            dependencies: [
                "Queue DoubleEnded Primitives",
                .product(name: "Index Primitives Test Support", package: "swift-index-primitives"),
            ],
            path: "Tests/Support"
        ),

        // MARK: - Tests
        .testTarget(
            name: "Queue DoubleEnded Primitives Tests",
            dependencies: [
                "Queue DoubleEnded Primitives",
                "Queue DoubleEnded Primitives Test Support",
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let ecosystem: [SwiftSetting] = [
        .strictMemorySafety(),
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableExperimentalFeature("LifetimeDependence"),
        .enableExperimentalFeature("Lifetimes"),
        .enableExperimentalFeature("SuppressedAssociatedTypes"),
        .enableUpcomingFeature("InferIsolatedConformances"),
        .enableUpcomingFeature("LifetimeDependence"),
    ]

    let package: [SwiftSetting] = []

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package
}
