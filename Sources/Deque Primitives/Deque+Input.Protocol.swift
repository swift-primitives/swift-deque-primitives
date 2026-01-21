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

public import Input_Primitives

// MARK: - Input.Streaming Conformance

extension Deque: Input.Streaming where Element: Copyable {
    /// Whether the deque has no elements remaining.
    @inlinable
    public var isEmpty: Bool { count == 0 }

    /// The front element, if any.
    @inlinable
    public var first: Element? {
        peek(at: .front)
    }

    /// Advances the cursor, returning the consumed element.
    ///
    /// - Precondition: The deque must not be empty.
    @inlinable
    @discardableResult
    public mutating func advance() -> Element {
        guard let element = pop(from: .front) else {
            preconditionFailure("Cannot advance from empty deque")
        }
        return element
    }
}

// MARK: - Input.Protocol Conformance

extension Deque: Input.`Protocol` where Element: Copyable {
    /// Checkpoint for backtracking: stores the logical position from the original front.
    ///
    /// When elements are consumed, we track how many have been consumed. Restoring
    /// to a checkpoint "unconsumes" elements by adjusting the ring buffer head.
    public struct Checkpoint: Sendable, Comparable {
        /// The logical head position at checkpoint time.
        @usableFromInline
        let head: Int

        /// The count at checkpoint time.
        @usableFromInline
        let count: Int

        @usableFromInline
        init(head: Int, count: Int) {
            self.head = head
            self.count = count
        }

        @inlinable
        public static func < (lhs: Checkpoint, rhs: Checkpoint) -> Bool {
            // Earlier checkpoints have higher counts (less consumed)
            lhs.count > rhs.count
        }
    }

    /// Creates a checkpoint at the current position.
    @inlinable
    public var checkpoint: Checkpoint {
        Checkpoint(head: _storage.header.head, count: _storage.header.count)
    }

    /// The range of valid checkpoint positions.
    @inlinable
    public var checkpointRange: ClosedRange<Checkpoint> {
        // Valid range is from current position to current position
        // (Deque doesn't support restoring to earlier positions after consumption)
        checkpoint...checkpoint
    }

    /// Sets position to a checkpoint.
    ///
    /// - Parameter checkpoint: A checkpoint obtained from ``checkpoint``.
    /// - Precondition: The checkpoint was created from this deque instance and
    ///   no elements have been added since the checkpoint was taken.
    @inlinable
    public mutating func setPosition(to checkpoint: Checkpoint) {
        makeUnique()
        _storage.header.head = checkpoint.head
        _storage.header.count = checkpoint.count
    }

    /// Advances cursor by `n` elements.
    ///
    /// - Parameter n: The number of elements to skip.
    /// - Precondition: `n >= 0` and `n <= count`.
    @inlinable
    public mutating func advance(by n: Int) {
        precondition(n >= 0 && n <= count, "Cannot advance by more elements than available")
        makeUnique()
        for _ in 0..<n {
            _ = _storage.removeFirst()
        }
    }

    /// The remaining input (returns self for deque).
    @inlinable
    public var remaining: Self {
        self
    }
}

// MARK: - Input.Access.Random Conformance

extension Deque: Input.Access.Random where Element: Copyable {
    /// Accesses the element at the given offset from the current position.
    ///
    /// - Parameter offset: Offset from current front (0-indexed).
    /// - Precondition: `offset >= 0` and `offset < count`.
    @inlinable
    public subscript(offset offset: Int) -> Element {
        precondition(offset >= 0 && offset < count, "Offset out of bounds")
        return _readElement(at: offset)
    }
}

// MARK: - Bounded Deque Input Conformance
// NOTE: Per [MEM-COPY-006], Deque.Bounded protocol conformances are in Deque.swift
// to avoid breaking ~Copyable propagation.
