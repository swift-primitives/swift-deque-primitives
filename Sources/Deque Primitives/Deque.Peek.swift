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

// MARK: - Peek Tag

extension Deque where Element: Copyable {
    /// Phantom tag for peek operations.
    ///
    /// Used with ``Property`` to provide namespaced peek properties.
    public enum Peek {}
}

// MARK: - Typealias

extension Deque where Element: Copyable {
    /// Shorthand for `Property_Primitives.Property<Tag, Deque<Element>>.Typed<Element>`.
    ///
    /// Used for property-based accessors where Element must be in extension scope.
    public typealias PropertyTyped<Tag> = Property_Primitives.Property<Tag, Deque<Element>>.Typed<Element>
}

// MARK: - Peek Accessor (Copyable elements only)

extension Deque where Element: Copyable {
    /// Nested accessor for peek operations.
    ///
    /// ```swift
    /// let deque: Deque<Int> = [1, 2, 3]
    /// if let back = deque.peek.back { ... }
    /// if let front = deque.peek.front { ... }
    /// ```
    ///
    /// - Note: This accessor is only available for `Copyable` elements.
    ///   For `~Copyable` elements, use ``peek(at:_:)`` with a closure.
    @inlinable
    public var peek: PropertyTyped<Peek> {
        Property_Primitives.Property.Typed(self)
    }
}

// MARK: - Peek Operations

extension Property_Primitives.Property.Typed where Tag == Deque<Element>.Peek, Base == Deque<Element>, Element: Copyable {
    /// The element at the back of the deque, or `nil` if empty.
    ///
    /// - Returns: The back element, or `nil` if the deque is empty.
    /// - Complexity: O(1).
    @inlinable
    public var back: Element? {
        base.peek(at: .back)
    }

    /// The element at the front of the deque, or `nil` if empty.
    ///
    /// - Returns: The front element, or `nil` if the deque is empty.
    /// - Complexity: O(1).
    @inlinable
    public var front: Element? {
        base.peek(at: .front)
    }
}
