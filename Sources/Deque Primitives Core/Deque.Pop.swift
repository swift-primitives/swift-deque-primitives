// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-standards open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-standards project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

// MARK: - Pop Tag

extension Deque where Element: Copyable {
    /// Phantom tag for pop operations.
    ///
    /// Used with ``Property`` to provide namespaced pop methods.
    public enum Pop {}
}

// MARK: - Pop Accessor (Copyable elements only)

extension Deque where Element: Copyable {
    /// Nested accessor for pop operations.
    ///
    /// ```swift
    /// var deque: Deque<Int> = [1, 2, 3]
    /// let back = try deque.pop.back()
    /// let front = try deque.pop.front()
    /// ```
    ///
    /// - Note: This accessor is only available for `Copyable` elements.
    ///   For `~Copyable` elements, use ``pop(from:)``.
    ///
    /// - Note: `_modify` only - no `get` accessor to prevent silent discard of mutations.
    @inlinable
    public var pop: Property<Pop> {
        _read {
            yield Property(self)
        }
        _modify {
            // Force uniqueness only (no growth needed for removal)
            makeUnique()

            // Transfer ownership to proxy
            var property: Property<Pop> = Property(self)
            self = Deque()  // Clear self to release our reference
            defer { self = property.base }
            yield &property
        }
    }
}

// MARK: - Pop Operations

extension Property_Primitives.Property {
    /// Pops an element from the back of the deque.
    ///
    /// - Returns: The removed element.
    /// - Throws: `Deque.Error.empty` if the deque is empty.
    /// - Complexity: O(1).
    @inlinable
    public mutating func back<E: Copyable>() throws(Deque<E>.Error) -> E
    where Tag == Deque<E>.Pop, Base == Deque<E> {
        guard let element = base.pop(from: .back) else {
            throw .empty
        }
        return element
    }

    /// Pops an element from the front of the deque.
    ///
    /// - Returns: The removed element.
    /// - Throws: `Deque.Error.empty` if the deque is empty.
    /// - Complexity: O(1).
    @inlinable
    public mutating func front<E: Copyable>() throws(Deque<E>.Error) -> E
    where Tag == Deque<E>.Pop, Base == Deque<E> {
        guard let element = base.pop(from: .front) else {
            throw .empty
        }
        return element
    }
}
