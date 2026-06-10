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

// The COLUMN-GENERIC deque surface: both-end pops and peeks ride the front-anchored
// seam (`move(at: .zero)` = front; `move(at: count − 1)` = back), the gate makes them
// CoW-correct on the `Shared` columns; pushes pin per column (`+Columns.swift`).
public import Queue_DoubleEnded_Primitive
public import Queue_Primitive
public import Buffer_Protocol_Primitives
public import Store_Protocol_Primitives
import Index_Primitives
import Ordinal_Primitives_Standard_Library_Integration
import Affine_Primitives_Standard_Library_Integration

// ============================================================================
// MARK: - Properties
// ============================================================================

extension Queue.DoubleEnded where S: ~Copyable {
    /// The number of elements in the deque.
    @inlinable
    public var count: Index.Count { store.count }

    /// Whether the deque is empty.
    @inlinable
    public var isEmpty: Bool { store.isEmpty }

    /// The current capacity of the deque.
    @inlinable
    public var capacity: Index.Count { store.capacity }

    /// The number of additional elements that can be pushed without growth (or, on
    /// the bounded columns, at all).
    @inlinable
    public var freeCapacity: Index.Count {
        store.capacity.subtract.saturating(store.count)
    }
}

// ============================================================================
// MARK: - Pops + peeks at both ends (generic: gate + the seam's boundary moves)
// ============================================================================

extension Queue.DoubleEnded where S: ~Copyable {
    /// Removes and returns the element at the given end, or nil if empty.
    ///
    /// - Complexity: O(1)
    @inlinable
    public mutating func pop(from position: Position) -> S.Element? {
        guard !isEmpty else { return nil }
        store.prepareForMutation()
        switch position {
        case .front:
            return store.move(at: .zero)
        case .back:
            let last: Index = store.count.subtract.saturating(.one).map(Ordinal.init)
            return store.move(at: last)
        }
    }

    /// Removes and returns the element at the given end, or nil if empty.
    /// (Alias of `pop(from:)` — the shipping surface's consuming spelling.)
    @inlinable
    public mutating func take(from position: Position) -> S.Element? {
        pop(from: position)
    }

    /// Peeks at the element at the given end without removing it.
    ///
    /// - Returns: The result of the closure, or `nil` if the deque is empty.
    /// - Complexity: O(1)
    @inlinable
    public func peek<R>(at position: Position, _ body: (borrowing S.Element) -> R) -> R? {
        guard !isEmpty else { return nil }
        switch position {
        case .front:
            return body(store[.zero])
        case .back:
            let last: Index = store.count.subtract.saturating(.one).map(Ordinal.init)
            return body(store[last])
        }
    }

    /// Consumes every element front-to-back, leaving the deque empty.
    @inlinable
    public mutating func drain(_ body: (consuming S.Element) -> Void) {
        store.prepareForMutation()
        while !isEmpty {
            body(store.move(at: .zero))
        }
    }

    /// Calls the given closure for each element, front to back.
    ///
    /// - Complexity: O(n)
    @inlinable
    public func forEach(_ body: (borrowing S.Element) -> Void) {
        var slot: Index = .zero
        let end = count.map(Ordinal.init)
        while slot < end {
            body(store[slot])
            slot = slot.successor.saturating()
        }
    }
}

extension Queue.DoubleEnded where S: ~Copyable, S.Element: Copyable {
    /// Returns the element at the given end by value, or nil if empty.
    @inlinable
    public func peek(at position: Position) -> S.Element? {
        peek(at: position) { copy $0 }
    }
}

// ============================================================================
// MARK: - Cloning (generic on the CoW columns)
// ============================================================================

extension Queue.DoubleEnded where S: Copyable {
    /// Returns an independent copy of this deque with its own storage (`Shared`
    /// columns: the mutation gate on the fresh copy ALWAYS installs a deep copy).
    ///
    /// - Complexity: O(`count`)
    @inlinable
    public borrowing func clone() -> Self {
        var result = copy self
        result.store.prepareForMutation()
        return result
    }
}
