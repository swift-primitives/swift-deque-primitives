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

// MARK: - Take Accessor (Copyable elements only)

extension Deque where Element: Copyable {
    /// Nested accessor for optional removal operations.
    ///
    /// Use `take` when empty is a normal state (queue/stack semantics):
    /// ```swift
    /// var queue: Deque<Int> = [1, 2, 3]
    /// while let element = queue.take.front {
    ///     process(element)
    /// }
    /// ```
    ///
    /// Use `pop` when empty is exceptional and should throw.
    ///
    /// - Note: This accessor is only available for `Copyable` elements.
    ///   For `~Copyable` elements, use ``take(from:)``.
    ///
    /// - Note: `_modify` only - no `get` accessor to prevent silent discard of mutations.
    @inlinable
    public var take: Take {
        _read {
            yield Take(deque: self)
        }
        _modify {
            // Force uniqueness only (no growth needed for removal)
            makeUnique()

            // Transfer ownership to proxy
            var proxy = Take(deque: self)
            self = Deque()  // Clear self to release our reference
            defer { self = proxy.deque }
            yield &proxy
        }
    }
}

// MARK: - Take Type

extension Deque where Element: Copyable {
    /// Namespace for optional removal operations.
    public struct Take {
        @usableFromInline
        var deque: Deque<Element>

        @usableFromInline
        init(deque: Deque<Element>) {
            self.deque = deque
        }
    }
}

// MARK: - Take Operations

extension Deque.Take where Element: Copyable {
    /// Removes and returns the back element, or `nil` if empty.
    ///
    /// - Returns: The removed element, or `nil` if the deque is empty.
    /// - Complexity: O(1).
    @inlinable
    public var back: Element? {
        mutating get {
            deque.pop(from: .back)
        }
    }

    /// Removes and returns the front element, or `nil` if empty.
    ///
    /// - Returns: The removed element, or `nil` if the deque is empty.
    /// - Complexity: O(1).
    @inlinable
    public var front: Element? {
        mutating get {
            deque.pop(from: .front)
        }
    }
}
