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
    public var pop: Pop {
        _read {
            yield Pop(deque: self)
        }
        _modify {
            // Force uniqueness only (no growth needed for removal)
            makeUnique()

            // Transfer ownership to proxy
            var proxy = Pop(deque: self)
            self = Deque()  // Clear self to release our reference
            defer { self = proxy.deque }
            yield &proxy
        }
    }
}

// MARK: - Pop Type

extension Deque where Element: Copyable {
    /// Namespace for pop operations.
    public struct Pop {
        @usableFromInline
        var deque: Deque<Element>

        @usableFromInline
        init(deque: Deque<Element>) {
            self.deque = deque
        }
    }
}

// MARK: - Pop Operations

extension Deque.Pop where Element: Copyable {
    /// Pops an element from the back of the deque.
    ///
    /// - Returns: The removed element.
    /// - Throws: `Deque.Error.empty` if the deque is empty.
    /// - Complexity: O(1).
    @inlinable
    public mutating func back() throws(__DequeError) -> Element {
        guard let element = deque.pop(from: .back) else {
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
    public mutating func front() throws(__DequeError) -> Element {
        guard let element = deque.pop(from: .front) else {
            throw .empty
        }
        return element
    }
}
