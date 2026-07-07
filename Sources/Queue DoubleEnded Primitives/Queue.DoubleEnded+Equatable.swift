// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-primitives open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-primitives project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

public import Queue_DoubleEnded_Primitive

// MARK: - Equatable + Hashable (the S5 chain; see Queue+Equatable.swift)

extension __QueueDoubleEnded: Equatable where S: Equatable {
    /// Returns whether two deques hold equal elements in equal order.
    @inlinable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.store == rhs.store
    }
}

extension __QueueDoubleEnded: Hashable where S: Hashable {
    /// Hashes the essential components of this deque into the given hasher.
    @inlinable
    public func hash(into hasher: inout Hasher) {
        store.hash(into: &hasher)
    }
}
