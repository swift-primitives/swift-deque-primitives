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

// MARK: - Take Accessor

extension Deque {
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
    /// - Note: `_modify` only - no `get` accessor to prevent silent discard of mutations.
    @inlinable
    public var take: Take {
        _read {
            yield Take(storage: storage)
        }
        _modify {
            // Force uniqueness only (no growth needed for removal)
            storage.ensureUnique()

            // Transfer storage ownership to proxy to maintain unique reference
            var proxy = Take(storage: storage)
            storage = Storage()  // Clear self.storage to release our reference
            defer { storage = proxy.storage }
            yield &proxy
        }
    }
}

// MARK: - Take Type

extension Deque {
    /// Namespace for optional removal operations.
    public struct Take {
        @usableFromInline
        var storage: Storage

        @usableFromInline
        init(storage: Storage) {
            self.storage = storage
        }
    }
}

// MARK: - Take Operations

extension Deque.Take {
    /// Removes and returns the back element, or `nil` if empty.
    ///
    /// - Returns: The removed element, or `nil` if the deque is empty.
    /// - Complexity: O(1).
    @inlinable
    public var back: Element? {
        mutating get {
            guard !storage.isEmpty else { return nil }
            return storage.removeLast()
        }
    }

    /// Removes and returns the front element, or `nil` if empty.
    ///
    /// - Returns: The removed element, or `nil` if the deque is empty.
    /// - Complexity: O(1).
    @inlinable
    public var front: Element? {
        mutating get {
            guard !storage.isEmpty else { return nil }
            return storage.removeFirst()
        }
    }
}
