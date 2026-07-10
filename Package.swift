// swift-tools-version: 6.3.3

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
        .library(name: "Queue DoubleEnded Primitive", targets: ["Queue DoubleEnded Primitive"]),
        // MARK: - Ops module; `Queue DoubleEnded Primitives` doubles as the [MOD-005] umbrella
        .library(name: "Queue DoubleEnded Primitives", targets: ["Queue DoubleEnded Primitives"]),
        // Convenience alias product matching the package name (the top-level `Deque<S>` typealias).
        .library(name: "Deque Primitives", targets: ["Deque Primitives"]),

        // MARK: - Small variant ([DS-027].1: own product, NOT umbrella-re-exported)
        .library(name: "Queue DoubleEnded Small Primitive", targets: ["Queue DoubleEnded Small Primitive"]),

        // MARK: - Fixed variant: DELETED at the ADT-families reshape (ASK-E — the
        // fixed-capacity story lives in the COLUMN: Queue<Buffer<…>.Ring.Bounded>.DoubleEnded)
    ],
    dependencies: [
        .package(url: "https://github.com/swift-primitives/swift-queue-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-buffer-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-buffer-ring-primitives.git", branch: "main"),
        // swift-memory-small-primitives: for the `Queue DoubleEnded Small Primitive` variant
        // target ONLY ([DS-027].1) — `Queue<E>.DoubleEnded.Small<n>`'s Memory.Small<n> leaf.
        .package(url: "https://github.com/swift-primitives/swift-memory-small-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-storage-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-ownership-shared-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-memory-heap-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-memory-allocation-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-index-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-ordinal-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-affine-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-tagged-primitives.git", branch: "main"),
    ],
    targets: [

        // MARK: - Type module — Queue<S>.DoubleEnded (the deque over the ring columns)
        .target(
            name: "Queue DoubleEnded Primitive",
            dependencies: [
                .product(name: "Queue Primitive", package: "swift-queue-primitives"),
                .product(name: "Buffer Primitive", package: "swift-buffer-primitives"),
                .product(name: "Buffer Protocol Primitives", package: "swift-buffer-primitives"),
                .product(name: "Buffer Ring Primitive", package: "swift-buffer-ring-primitives"),
                .product(name: "Buffer Ring Bounded Primitive", package: "swift-buffer-ring-primitives"),
                .product(name: "Store Protocol Primitives", package: "swift-storage-primitives"),
                .product(name: "Ownership Shared Primitive", package: "swift-ownership-shared-primitives"),
                .product(name: "Storage Contiguous Primitives", package: "swift-storage-primitives"),
                .product(name: "Memory Heap Primitives", package: "swift-memory-heap-primitives"),
                .product(name: "Memory Allocator Primitive", package: "swift-memory-allocation-primitives"),
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                .product(name: "Ordinal Primitives Standard Library Integration", package: "swift-ordinal-primitives"),
                .product(name: "Affine Primitives Standard Library Integration", package: "swift-affine-primitives"),
            ]
        ),

        // MARK: - Ops module + umbrella ([MOD-005]: re-exports the in-package type module only)
        .target(
            name: "Queue DoubleEnded Primitives",
            dependencies: [
                "Queue DoubleEnded Primitive",
                .product(name: "Queue Primitive", package: "swift-queue-primitives"),
                .product(name: "Buffer Primitive", package: "swift-buffer-primitives"),
                .product(name: "Buffer Protocol Primitives", package: "swift-buffer-primitives"),
                .product(name: "Buffer Ring Primitive", package: "swift-buffer-ring-primitives"),
                .product(name: "Buffer Ring Bounded Primitive", package: "swift-buffer-ring-primitives"),
                .product(name: "Store Protocol Primitives", package: "swift-storage-primitives"),
                .product(name: "Ownership Shared Primitive", package: "swift-ownership-shared-primitives"),
                .product(name: "Storage Contiguous Primitives", package: "swift-storage-primitives"),
                .product(name: "Memory Heap Primitives", package: "swift-memory-heap-primitives"),
                .product(name: "Memory Allocator Primitive", package: "swift-memory-allocation-primitives"),
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                .product(name: "Ordinal Primitives Standard Library Integration", package: "swift-ordinal-primitives"),
                .product(name: "Affine Primitives Standard Library Integration", package: "swift-affine-primitives"),
            ]
        ),

        // MARK: - Small type ([DS-027].1: own product, NO umbrella re-export — keeps the
        //         heap-only consumers' closure lean; the Memory.Small<n> leaf dep lands on
        //         THIS target only. The door's ops flow from __QueueDoubleEnded's
        //         allocation-generic pins in `Queue DoubleEnded Primitives`.)
        .target(
            name: "Queue DoubleEnded Small Primitive",
            dependencies: [
                "Queue DoubleEnded Primitive",
                .product(name: "Buffer Primitive", package: "swift-buffer-primitives"),
                .product(name: "Buffer Ring Primitive", package: "swift-buffer-ring-primitives"),
                .product(name: "Store Protocol Primitives", package: "swift-storage-primitives"),
                .product(name: "Storage Contiguous Primitives", package: "swift-storage-primitives"),
                .product(name: "Memory Allocator Primitive", package: "swift-memory-allocation-primitives"),
                .product(name: "Memory Small Primitives", package: "swift-memory-small-primitives"),
            ]
        ),

        // MARK: - Deque umbrella — the top-level `Deque<S>` typealias + package-name-facing re-export
        .target(
            name: "Deque Primitives",
            dependencies: [
                "Queue DoubleEnded Primitives",
                .product(name: "Queue Primitive", package: "swift-queue-primitives"),
                .product(name: "Store Protocol Primitives", package: "swift-storage-primitives"),
                .product(name: "Buffer Protocol Primitives", package: "swift-buffer-primitives"),
            ]
        ),

        // MARK: - Tests
        .testTarget(
            name: "Queue DoubleEnded Primitives Tests",
            dependencies: [
                "Deque Primitives",
                "Queue DoubleEnded Small Primitive",
                .product(name: "Buffer Ring Primitives", package: "swift-buffer-ring-primitives"),
                .product(name: "Buffer Primitives Test Support", package: "swift-buffer-primitives"),
                .product(name: "Memory Small Primitives", package: "swift-memory-small-primitives"),
                .product(name: "Tagged Primitives Standard Library Integration", package: "swift-tagged-primitives"),
                .product(name: "Ordinal Primitives Standard Library Integration", package: "swift-ordinal-primitives"),
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
    ]

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem
}
