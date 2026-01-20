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
    public var peek: Peek {
        Peek(deque: self)
    }
}

// MARK: - Peek Type

extension Deque where Element: Copyable {
    /// Namespace for peek operations.
    public struct Peek {
        @usableFromInline
        let deque: Deque<Element>

        @usableFromInline
        init(deque: Deque<Element>) {
            self.deque = deque
        }
    }
}

// MARK: - Peek Operations

extension Deque.Peek where Element: Copyable {
    /// The element at the back of the deque, or `nil` if empty.
    ///
    /// - Complexity: O(1).
    @inlinable
    public var back: Element? {
        deque.peek(at: .back)
    }

    /// The element at the front of the deque, or `nil` if empty.
    ///
    /// - Complexity: O(1).
    @inlinable
    public var front: Element? {
        deque.peek(at: .front)
    }
}
