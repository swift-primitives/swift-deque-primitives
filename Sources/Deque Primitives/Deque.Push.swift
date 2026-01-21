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

// MARK: - Push Tag

extension Deque where Element: Copyable {
    /// Phantom tag for push operations.
    ///
    /// Used with ``Property`` to provide namespaced push methods.
    public enum Push {}
}

// MARK: - Push Accessor (Copyable elements only)

extension Deque where Element: Copyable {
    /// Nested accessor for push operations.
    ///
    /// ```swift
    /// var deque = Deque<Int>()
    /// deque.push.back(1)
    /// deque.push.front(0)
    /// ```
    ///
    /// - Note: This accessor is only available for `Copyable` elements.
    ///   For `~Copyable` elements, use ``push(_:to:)``.
    ///
    /// - Note: `_modify` only - no `get` accessor to prevent silent discard of mutations.
    @inlinable
    public var push: Property<Push, Deque<Element>> {
        // _read provides a snapshot for read-only access (rarely used)
        _read {
            yield Property(self)
        }
        _modify {
            // CRITICAL: Force uniqueness + growth BEFORE transferring storage
            makeUnique()
            reserve(count + 1)

            // Transfer ownership to proxy
            var property: Property<Push, Deque<Element>> = Property(self)
            self = Deque()  // Clear self to release our reference
            defer { self = property.base }
            yield &property
        }
    }
}

// MARK: - Push Operations

extension Property {
    /// Pushes an element to the back of the deque.
    ///
    /// - Parameter element: The element to push.
    /// - Complexity: O(1) amortized.
    @inlinable
    public mutating func back<E: Copyable>(_ element: E)
    where Tag == Deque<E>.Push, Base == Deque<E> {
        base.push(element, to: .back)
    }

    /// Pushes an element to the front of the deque.
    ///
    /// - Parameter element: The element to push.
    /// - Complexity: O(1) amortized.
    @inlinable
    public mutating func front<E: Copyable>(_ element: E)
    where Tag == Deque<E>.Push, Base == Deque<E> {
        base.push(element, to: .front)
    }
}
