// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-standards open source project
//
// Copyright (c) 2024-2025 Coen ten Thije Boonkkamp and the swift-standards project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

extension Deque {
    /// Typed error for Deque operations.
    ///
    /// Uses typed throws (`throws(Deque.Error)`) for compile-time exhaustiveness.
    ///
    /// ## Example
    ///
    /// ```swift
    /// do {
    ///     let element = try deque.pop()
    /// } catch .empty {
    ///     print("Deque was empty")
    /// } catch .bounds(let info) {
    ///     print("Index \(info.index) out of bounds")
    /// }
    /// ```
    public enum Error: Swift.Error, Sendable, Equatable {
        /// An operation was attempted on an empty deque.
        case empty(Empty)

        /// An index was out of bounds.
        case bounds(Bounds)

        /// A capacity request could not be satisfied.
        case capacity(Capacity)
    }
}

// MARK: - Error Payloads

extension Deque.Error {
    /// Empty collection payload.
    public struct Empty: Sendable, Equatable {
        @inlinable
        public init() {}
    }

    /// Bounds violation payload.
    public struct Bounds: Sendable, Equatable {
        public let index: Int
        public let count: Int

        @inlinable
        public init(index: Int, count: Int) {
            self.index = index
            self.count = count
        }
    }

    /// Capacity violation payload.
    public struct Capacity: Sendable, Equatable {
        public let requested: Int
        public let maximum: Int

        @inlinable
        public init(requested: Int, maximum: Int) {
            self.requested = requested
            self.maximum = maximum
        }
    }
}

// MARK: - CustomStringConvertible

extension Deque.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .empty: return "operation attempted on empty deque"
        case .bounds(let e): return "index \(e.index) out of bounds for count \(e.count)"
        case .capacity(let e): return "requested capacity \(e.requested) exceeds maximum \(e.maximum)"
        }
    }
}
