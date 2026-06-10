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
public import Queue_Primitive

// MARK: - Equatable + Hashable (the S5 chain; see Queue+Equatable.swift)

extension Queue.DoubleEnded: Equatable where S: Equatable {
    @inlinable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.store == rhs.store
    }
}

extension Queue.DoubleEnded: Hashable where S: Hashable {
    @inlinable
    public func hash(into hasher: inout Hasher) {
        store.hash(into: &hasher)
    }
}
