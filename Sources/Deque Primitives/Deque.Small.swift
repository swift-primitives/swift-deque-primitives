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

// Note: Deque.Small is declared INSIDE the Deque struct body (in Deque.swift)
// due to a Swift compiler bug where nested types with value generic parameters
// declared in extensions do not properly inherit ~Copyable constraints from
// the outer type. This file contains only extensions to Deque.Small.

// Note: Deque.Small is UNCONDITIONALLY ~Copyable due to the deinit requirement
// for inline storage cleanup. No CoW extensions are needed.

// MARK: - Properties

extension Deque.Small where Element: ~Copyable {
    /// The current number of elements in the deque.
    @inlinable
    public var count: Int { _count }

    /// Whether the deque is empty.
    @inlinable
    public var isEmpty: Bool { _count == 0 }

    /// The current capacity (inline or heap).
    @inlinable
    public var capacity: Int {
        if let heap = _heap {
            return heap.capacity
        }
        return inlineCapacity
    }
}

// MARK: - Core Operations

extension Deque.Small where Element: ~Copyable {
    /// Pushes an element to the specified end of the deque.
    ///
    /// If the deque exceeds inline capacity, elements are moved to heap storage.
    ///
    /// - Parameters:
    ///   - element: The element to push.
    ///   - position: Which end to push to (.front or .back).
    /// - Complexity: O(1) amortized, O(n) when spilling to heap.
    @inlinable
    public mutating func push(_ element: consuming Element, to position: Deque<Element>.Position) {
        if _heap != nil {
            // Already spilled - push to heap
            _pushToHeap(element, to: position)
        } else if _count < inlineCapacity {
            // Still inline and have space
            switch position {
            case .front:
                _head = (_head - 1 + inlineCapacity) % inlineCapacity
                unsafe _inlinePointerToElement(at: _head).initialize(to: element)
            case .back:
                let tail = (_head + _count) % inlineCapacity
                unsafe _inlinePointerToElement(at: tail).initialize(to: element)
            }
            _count += 1
        } else {
            // Need to spill
            _spillToHeap(minimumCapacity: _count + 1)
            _pushToHeap(element, to: position)
        }
    }

    /// Internal: push element to heap storage.
    @usableFromInline
    mutating func _pushToHeap(_ element: consuming Element, to position: Deque<Element>.Position) {
        guard let heap = _heap else {
            preconditionFailure("_pushToHeap called without heap storage")
        }

        // Check if we need to grow
        if _count >= heap.capacity {
            _growHeap(minimumCapacity: _count + 1)
        }

        switch position {
        case .front:
            _heap!.prepend(element)
        case .back:
            _heap!.append(element)
        }
        _count += 1
    }

    /// Internal: grow heap storage.
    @usableFromInline
    mutating func _growHeap(minimumCapacity: Int) {
        guard let oldStorage = _heap else {
            preconditionFailure("_growHeap called without heap storage")
        }

        let newCapacity = Swift.max(minimumCapacity, oldStorage.capacity * 2)
        let newStorage = Deque<Element>.Storage.create(minimumCapacity: newCapacity)

        // Copy elements in logical order (linearizing)
        let count = _count
        let cap = unsafe oldStorage.header.bufferCapacity
        let head = unsafe oldStorage.header.head

        _ = unsafe oldStorage.withUnsafeMutablePointerToElements { src in
            unsafe newStorage.withUnsafeMutablePointerToElements { dst in
                for i in 0..<count {
                    let srcIndex = (head + i) % cap
                    unsafe (dst + i).initialize(to: (src + srcIndex).move())
                }
            }
        }

        unsafe (newStorage.header.count = count)
        unsafe (newStorage.header.head = 0)
        unsafe (oldStorage.header.count = 0)  // Prevent double-free

        _heap = newStorage
        unsafe (_heapPtr = newStorage._elementsPointer)
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

        if _heap != nil {
            _count -= 1
            switch position {
            case .front:
                return _heap!.removeFirst()
            case .back:
                return _heap!.removeLast()
            }
        } else {
            switch position {
            case .front:
                let oldHead = _head
                _head = (_head + 1) % inlineCapacity
                _count -= 1
                return unsafe _inlinePointerToElement(at: oldHead).move()
            case .back:
                _count -= 1
                let tail = (_head + _count) % inlineCapacity
                return unsafe _inlinePointerToElement(at: tail).move()
            }
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
    /// Does not shrink back to inline storage if spilled.
    ///
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public mutating func clear() {
        guard _count > 0 else { return }

        if let heap = _heap {
            heap.deinitializeAll()
        } else {
            for i in 0..<_count {
                let physicalIndex = (_head + i) % inlineCapacity
                unsafe _inlinePointerToElement(at: physicalIndex).deinitialize(count: 1)
            }
        }
        _head = 0
        _count = 0
    }
}

// MARK: - Peek

extension Deque.Small where Element: ~Copyable {
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

        if let heap = _heap, let heapPtr = _heapPtr {
            let physicalIndex: Int
            switch position {
            case .front:
                physicalIndex = unsafe heap.header.head
            case .back:
                let cap = unsafe heap.header.bufferCapacity
                let head = unsafe heap.header.head
                physicalIndex = (head + _count - 1) % cap
            }
            return try unsafe body((heapPtr + physicalIndex).pointee)
        } else {
            let physicalIndex: Int
            switch position {
            case .front:
                physicalIndex = _head
            case .back:
                physicalIndex = (_head + _count - 1) % inlineCapacity
            }
            return try unsafe body(_inlineReadPointerToElement(at: physicalIndex).pointee)
        }
    }
}

extension Deque.Small where Element: Copyable {
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

        if let heap = _heap, let heapPtr = _heapPtr {
            let physicalIndex: Int
            switch position {
            case .front:
                physicalIndex = unsafe heap.header.head
            case .back:
                let cap = unsafe heap.header.bufferCapacity
                let head = unsafe heap.header.head
                physicalIndex = (head + _count - 1) % cap
            }
            return unsafe (heapPtr + physicalIndex).pointee
        } else {
            let physicalIndex: Int
            switch position {
            case .front:
                physicalIndex = _head
            case .back:
                physicalIndex = (_head + _count - 1) % inlineCapacity
            }
            return unsafe _inlineReadPointerToElement(at: physicalIndex).pointee
        }
    }
}

// MARK: - Iteration

extension Deque.Small where Element: ~Copyable {
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
        if let heap = _heap, let heapPtr = _heapPtr {
            let cap = unsafe heap.header.bufferCapacity
            let head = unsafe heap.header.head
            for i in 0..<_count {
                let physicalIndex = (head + i) % cap
                try unsafe body((heapPtr + physicalIndex).pointee)
            }
        } else {
            for i in 0..<_count {
                let physicalIndex = (_head + i) % inlineCapacity
                try unsafe body(_inlineReadPointerToElement(at: physicalIndex).pointee)
            }
        }
    }
}

// MARK: - Truncate

extension Deque.Small where Element: ~Copyable {
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

        if let heap = _heap {
            let cap = unsafe heap.header.bufferCapacity
            let head = unsafe heap.header.head
            _ = unsafe heap.withUnsafeMutablePointerToElements { elements in
                for i in targetCount..<_count {
                    let physicalIndex = (head + i) % cap
                    unsafe (elements + physicalIndex).deinitialize(count: 1)
                }
            }
            unsafe (heap.header.count = targetCount)
        } else {
            for i in targetCount..<_count {
                let physicalIndex = (_head + i) % inlineCapacity
                unsafe _inlinePointerToElement(at: physicalIndex).deinitialize(count: 1)
            }
        }
        _count = targetCount
    }
}
