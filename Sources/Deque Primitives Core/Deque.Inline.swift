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

// Note: Deque.Inline is declared INSIDE the Deque struct body (in Deque.swift)
// due to a Swift compiler bug where nested types with value generic parameters
// declared in extensions do not properly inherit ~Copyable constraints from
// the outer type. This file contains only extensions to Deque.Inline.

// MARK: - Properties

extension Deque.Inline where Element: ~Copyable {
    /// The current number of elements in the deque.
    @inlinable
    public var count: Int { _count }

    /// Whether the deque is empty.
    @inlinable
    public var isEmpty: Bool { _count == 0 }

    /// Whether the deque is full.
    @inlinable
    public var isFull: Bool { _count == Self.capacity }
}

// MARK: - Core Operations

extension Deque.Inline where Element: ~Copyable {
    /// Pushes an element to the specified end of the deque.
    ///
    /// - Parameters:
    ///   - element: The element to push.
    ///   - position: Which end to push to (.front or .back).
    /// - Throws: ``Deque/Inline/Error/overflow`` if the deque is full.
    /// - Complexity: O(1)
    @inlinable
    public mutating func push(_ element: consuming Element, to position: Deque<Element>.Position) throws(__Deque.Inline.Error) {
        guard _count < Self.capacity else {
            throw .overflow
        }

        switch position {
        case .front:
            // Prepend: move head backward
            _head = (_head - 1 + Self.capacity) % Self.capacity
            unsafe _pointerToElement(at: _head).initialize(to: element)
        case .back:
            // Append: add at tail
            let tail = (_head + _count) % Self.capacity
            unsafe _pointerToElement(at: tail).initialize(to: element)
        }
        _count += 1
    }

    /// Pops and returns an element from the specified end, or nil if empty.
    ///
    /// - Parameter position: Which end to pop from (.front or .back).
    /// - Returns: The removed element, or `nil` if the deque is empty.
    /// - Complexity: O(1)
    @inlinable
    public mutating func pop(from position: Deque<Element>.Position) -> Element? {
        guard _count > 0 else {
            return nil
        }

        switch position {
        case .front:
            let oldHead = _head
            _head = (_head + 1) % Self.capacity
            _count -= 1
            return unsafe _pointerToElement(at: oldHead).move()
        case .back:
            _count -= 1
            let tail = (_head + _count) % Self.capacity
            return unsafe _pointerToElement(at: tail).move()
        }
    }

    /// Takes and returns an element from the specified end, or nil if empty.
    ///
    /// - Parameter position: Which end to take from (.front or .back).
    /// - Returns: The removed element, or `nil` if the deque is empty.
    /// - Complexity: O(1)
    @inlinable
    public mutating func take(from position: Deque<Element>.Position) -> Element? {
        pop(from: position)
    }

    /// Removes all elements from the deque.
    ///
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public mutating func clear() {
        for i in 0..<_count {
            let physicalIndex = (_head + i) % Self.capacity
            unsafe _pointerToElement(at: physicalIndex).deinitialize(count: 1)
        }
        _head = 0
        _count = 0
    }
}

// MARK: - Peek

extension Deque.Inline where Element: ~Copyable {
    /// Peeks at the element at the specified end without removing it.
    ///
    /// Uses a closure to support `~Copyable` elements via borrowing.
    ///
    /// - Parameters:
    ///   - position: Which end to peek at (.front or .back).
    ///   - body: A closure that receives a borrowed reference to the element.
    /// - Returns: The result of the closure, or `nil` if the deque is empty.
    /// - Complexity: O(1)
    @inlinable
    public func peek<R, E: Swift.Error>(at position: Deque<Element>.Position, _ body: (borrowing Element) throws(E) -> R) throws(E) -> R? {
        guard _count > 0 else {
            return nil
        }

        let physicalIndex: Int
        switch position {
        case .front:
            physicalIndex = _head
        case .back:
            physicalIndex = (_head + _count - 1) % Self.capacity
        }

        return try unsafe body(_readPointerToElement(at: physicalIndex).pointee)
    }
}

extension Deque.Inline where Element: Copyable {
    /// Returns the element at the specified end without removing it, or nil if empty.
    ///
    /// - Parameter position: Which end to peek at (.front or .back).
    /// - Returns: A copy of the element, or `nil` if the deque is empty.
    /// - Complexity: O(1)
    @inlinable
    public func peek(at position: Deque<Element>.Position) -> Element? {
        guard _count > 0 else {
            return nil
        }

        let physicalIndex: Int
        switch position {
        case .front:
            physicalIndex = _head
        case .back:
            physicalIndex = (_head + _count - 1) % Self.capacity
        }

        return unsafe _readPointerToElement(at: physicalIndex).pointee
    }
}

// MARK: - Iteration

extension Deque.Inline where Element: ~Copyable {
    /// Calls the given closure for each element in the deque.
    ///
    /// Elements are visited from front to back.
    ///
    /// - Parameter body: A closure that receives each element.
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public func forEach<E: Swift.Error>(
        _ body: (borrowing Element) throws(E) -> Void
    ) throws(E) {
        for i in 0..<_count {
            let physicalIndex = (_head + i) % Self.capacity
            try unsafe body(_readPointerToElement(at: physicalIndex).pointee)
        }
    }
}

// MARK: - Truncate

extension Deque.Inline where Element: ~Copyable {
    /// Removes elements beyond the specified count.
    ///
    /// If `newCount >= count`, this method has no effect.
    /// Elements are removed from the back of the deque.
    ///
    /// - Parameter newCount: The maximum number of elements to retain.
    /// - Complexity: O(k) where k is the number of removed elements.
    @inlinable
    public mutating func truncate(to newCount: Int) {
        guard newCount < _count else { return }
        let targetCount = Swift.max(0, newCount)

        for i in targetCount..<_count {
            let physicalIndex = (_head + i) % Self.capacity
            unsafe _pointerToElement(at: physicalIndex).deinitialize(count: 1)
        }
        _count = targetCount
    }
}
