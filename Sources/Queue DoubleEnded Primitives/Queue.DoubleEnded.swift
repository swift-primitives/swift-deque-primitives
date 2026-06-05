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

public import Buffer_Ring_Primitive
public import Buffer_Ring_Primitives
public import Memory_Small_Primitives
public import Storage_Primitive
public import Queue_DoubleEnded_Primitive
public import Queue_Primitives

// Note: Queue.DoubleEnded struct declaration is in Queue.swift
// (must be same file due to Swift compiler bug [MEM-COPY-006])
// This file contains extensions with operations and conformances.

// Note: the top-level `Deque` typealias is declared in the `Queue DoubleEnded Primitive`
// type module (Deque.swift) and re-exported here via exports.swift.

// MARK: - DoubleEnded Properties (~Copyable)

extension Queue.DoubleEnded where Element: ~Copyable {
    /// The current number of elements in the deque.
    @inlinable
    public var count: Index_Primitives.Index<Element>.Count { _buffer.count }

    /// Whether the deque is empty.
    @inlinable
    public var isEmpty: Bool { _buffer.isEmpty }

    /// The current capacity of the deque.
    @inlinable
    public var capacity: Index_Primitives.Index<Element>.Count { _buffer.capacity }
}

// MARK: - DoubleEnded Capacity Management (~Copyable)

extension Queue.DoubleEnded where Element: ~Copyable {
    /// Reserves enough space to store the specified number of elements.
    @inlinable
    public mutating func reserve(_ minimumCapacity: Index_Primitives.Index<Element>.Count) {
        _buffer.reserveCapacity(minimumCapacity)
    }
}

// MARK: - DoubleEnded Core Operations (~Copyable)

extension Queue.DoubleEnded where Element: ~Copyable {
    /// Pushes an element to the specified end of the deque.
    ///
    /// - Complexity: O(1) amortized
    @inlinable
    public mutating func push(_ element: consuming Element, to position: Position) {
        switch position {
        case .front:
            _buffer.push.front(consume element)
        case .back:
            _buffer.push.back(consume element)
        }
    }

    /// Pops and returns an element from the specified end, or nil if empty.
    ///
    /// - Complexity: O(1)
    @inlinable
    public mutating func pop(from position: Position) -> Element? {
        guard !isEmpty else { return nil }
        switch position {
        case .front:
            return _buffer.pop.front()
        case .back:
            return _buffer.pop.back()
        }
    }

    /// Takes and returns an element from the specified end, or nil if empty.
    ///
    /// - Complexity: O(1)
    @inlinable
    public mutating func take(from position: Position) -> Element? {
        pop(from: position)
    }

    /// Removes all elements from the deque.
    ///
    /// - Complexity: O(n)
    // on remove.all() + conditional buffer reassignment in deep @inlinable chain.
    @inlinable
    public mutating func clear(keepingCapacity: Bool = true) {
        _buffer.remove.all()
        if !keepingCapacity {
            _buffer = Buffer<Storage<Element>.Contiguous<Memory.Heap<Element>>>.Ring(minimumCapacity: .zero)
        }
    }
}

// MARK: - DoubleEnded Peek (~Copyable)

extension Queue.DoubleEnded where Element: ~Copyable {
    /// Peeks at the element at the specified end without removing it.
    ///
    /// - Complexity: O(1)
    @inlinable
    public func peek<R>(at position: Position, _ body: (borrowing Element) -> R) -> R? {
        guard !_buffer.isEmpty else { return nil }
        switch position {
        case .front:
            return _buffer.withFront(body)
        case .back:
            return _buffer.withBack(body)
        }
    }
}

// MARK: - DoubleEnded forEach (~Copyable)

extension Queue.DoubleEnded where Element: ~Copyable {
    /// Calls the given closure for each element in the deque.
    ///
    /// - Complexity: O(n)
    @inlinable
    public func forEach(_ body: (borrowing Element) -> Void) {
        _buffer.forEach(body)
    }
}

// MARK: - DoubleEnded Copy-on-Write (Copyable)

extension Queue.DoubleEnded where Element: Copyable {
    /// Ensures the storage is uniquely referenced before mutation.
    @usableFromInline
    package mutating func makeUnique() {
        _buffer.ensureUnique()
    }

    /// Pushes an element (CoW-aware).
    @inlinable
    public mutating func push(_ element: Element, to position: Position) {
        switch position {
        case .front:
            _buffer.push.front(element)
        case .back:
            _buffer.push.back(element)
        }
    }

    /// Pops an element (CoW-aware).
    @inlinable
    public mutating func pop(from position: Position) -> Element? {
        guard !isEmpty else { return nil }
        switch position {
        case .front:
            return _buffer.pop.front()
        case .back:
            return _buffer.pop.back()
        }
    }

    /// Takes an element (CoW-aware).
    @inlinable
    public mutating func take(from position: Position) -> Element? {
        pop(from: position)
    }

    /// Removes all elements (CoW-aware).
    // on remove.all() + conditional buffer reassignment in deep @inlinable chain.
    @inlinable
    public mutating func clear(keepingCapacity: Bool = true) {
        _buffer.remove.all()
        if !keepingCapacity {
            _buffer = Buffer<Storage<Element>.Contiguous<Memory.Heap<Element>>>.Ring(minimumCapacity: .zero)
        }
    }

    /// Returns the element at the specified end without removing it.
    @inlinable
    public func peek(at position: Position) -> Element? {
        guard !isEmpty else { return nil }
        switch position {
        case .front:
            return _buffer.peek.front
        case .back:
            return _buffer.peek.back
        }
    }

    /// Reads the element at the given logical index.
    @usableFromInline
    package func _readElement(at logicalIndex: Index_Primitives.Index<Element>.Count) -> Element {
        return _buffer[logicalIndex.map(Ordinal.init)]
    }
}

// MARK: - Fixed Properties (~Copyable)

extension Queue.DoubleEnded.Fixed where Element: ~Copyable {
    /// The current number of elements in the deque.
    @inlinable
    public var count: Index_Primitives.Index<Element>.Count { _buffer.count }

    /// Whether the deque is empty.
    @inlinable
    public var isEmpty: Bool { _buffer.isEmpty }

    /// Whether the deque is full.
    @inlinable
    public var isFull: Bool { count >= capacity }
}

// MARK: - Fixed Core Operations (~Copyable)

extension Queue.DoubleEnded.Fixed where Element: ~Copyable {
    /// Pushes an element to the specified end.
    ///
    /// - Throws: ``Queue/DoubleEnded/Fixed/Error/overflow`` if the deque is full.
    @inlinable
    public mutating func push(
        _ element: consuming Element,
        to position: Queue<Element>.DoubleEnded.Position
    ) throws(Queue<Element>.DoubleEnded.Fixed.Error) {
        guard !isFull else { throw .overflow }
        switch position {
        case .front:
            _buffer.push.front(consume element)
        case .back:
            _buffer.push.back(consume element)
        }
    }

    /// Pops an element from the specified end, or nil if empty.
    @inlinable
    public mutating func pop(from position: Queue<Element>.DoubleEnded.Position) -> Element? {
        guard !isEmpty else { return nil }
        switch position {
        case .front:
            return _buffer.pop.front()
        case .back:
            return _buffer.pop.back()
        }
    }

    /// Takes an element from the specified end, or nil if empty.
    @inlinable
    public mutating func take(from position: Queue<Element>.DoubleEnded.Position) -> Element? {
        pop(from: position)
    }

    /// Peeks at the element at the specified end.
    @inlinable
    public func peek<R>(
        at position: Queue<Element>.DoubleEnded.Position,
        _ body: (borrowing Element) -> R
    ) -> R? {
        guard !isEmpty else { return nil }
        switch position {
        case .front:
            return _buffer.withFront(body)
        case .back:
            return _buffer.withBack(body)
        }
    }

    /// Removes all elements from the deque.
    @inlinable
    public mutating func clear() {
        _buffer.remove.all()
    }

    /// Calls the given closure for each element.
    @inlinable
    public func forEach(_ body: (borrowing Element) -> Void) {
        _buffer.forEach(body)
    }
}

// MARK: - Sequence.Drain.Protocol (~Copyable)

extension Queue.DoubleEnded.Fixed: Sequence.Drain.`Protocol` where Element: ~Copyable {
    /// Drains all elements in front-to-back order, passing each to the closure with ownership.
    ///
    /// After this method returns, the deque is empty but still usable.
    /// The capacity remains unchanged.
    ///
    /// - Parameter body: A closure that receives each drained element with ownership.
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public mutating func drain(_ body: (consuming Element) -> Void) {
        while let element = pop(from: .front) {
            body(element)
        }
    }
}

// MARK: - Fixed Conditional Drain (~Copyable)

extension Queue.DoubleEnded.Fixed where Element: ~Copyable {
    /// Drains elements front-to-back while the predicate returns true.
    @inlinable
    public mutating func drain(
        while predicate: (borrowing Element) -> Bool,
        _ body: (consuming Element) -> Void
    ) {
        while peek(at: .front, predicate) ?? false {
            body(pop(from: .front)!)
        }
    }
}

// MARK: - Fixed Copy-on-Write (Copyable)

extension Queue.DoubleEnded.Fixed where Element: Copyable {
    /// Ensures the storage is uniquely referenced before mutation.
    @usableFromInline
    package mutating func makeUnique() {
        _buffer.ensureUnique()
    }

    /// Pushes an element (CoW-aware).
    @inlinable
    public mutating func push(
        _ element: Element,
        to position: Queue<Element>.DoubleEnded.Position
    ) throws(Queue<Element>.DoubleEnded.Fixed.Error) {
        guard !isFull else { throw .overflow }
        switch position {
        case .front:
            _buffer.push.front(element)
        case .back:
            _buffer.push.back(element)
        }
    }

    /// Pops an element (CoW-aware).
    @inlinable
    public mutating func pop(from position: Queue<Element>.DoubleEnded.Position) -> Element? {
        guard !isEmpty else { return nil }
        switch position {
        case .front:
            return _buffer.pop.front()
        case .back:
            return _buffer.pop.back()
        }
    }

    /// Takes an element (CoW-aware).
    @inlinable
    public mutating func take(from position: Queue<Element>.DoubleEnded.Position) -> Element? {
        pop(from: position)
    }

    /// Clears all elements (CoW-aware).
    @inlinable
    public mutating func clear() {
        _buffer.remove.all()
    }

    /// Returns the element at the specified end without removing it.
    @inlinable
    public func peek(at position: Queue<Element>.DoubleEnded.Position) -> Element? {
        guard !isEmpty else { return nil }
        switch position {
        case .front:
            return _buffer.peek.front
        case .back:
            return _buffer.peek.back
        }
    }
}

// MARK: - Static Properties and Operations


// MARK: - Small Properties and Operations


// Note: the base `Swift.Sequence` conformance + nested `struct Iterator` are dropped per the
// recipe-2 migration (the deferred stdlib-interop axis). Element iteration is via the institute
// `Iterable` + `Sequenceable` attachables in the type module
// (Queue.DoubleEnded+Iterable.swift / Queue.DoubleEnded+Sequenceable.swift).

// MARK: - Equatable (Copyable)

extension Queue.DoubleEnded: Equatable where Element: Equatable & Copyable {
    @inlinable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        guard lhs.count == rhs.count else { return false }
        var i: Index_Primitives.Index<Element>.Count = .zero
        while i < lhs.count {
            if lhs._readElement(at: i) != rhs._readElement(at: i) {
                return false
            }
            i += .one
        }
        return true
    }
}

// MARK: - Hashable (Copyable)

extension Queue.DoubleEnded: Hashable where Element: Hashable & Copyable {
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(count)
        var i: Index_Primitives.Index<Element>.Count = .zero
        while i < count {
            hasher.combine(_readElement(at: i))
            i += .one
        }
    }
}

// MARK: - ExpressibleByArrayLiteral (Copyable)

extension Queue.DoubleEnded: ExpressibleByArrayLiteral where Element: Copyable {
    @inlinable
    public init(arrayLiteral elements: Element...) {
        self.init()
        for element in elements {
            push(element, to: .back)
        }
    }
}

// MARK: - Sequence Initializer (Copyable)

extension Queue.DoubleEnded where Element: Copyable {
    /// Creates a deque containing the elements of a sequence.
    @inlinable
    public init<S: Swift.Sequence>(_ elements: S) where S.Element == Element {
        self.init()
        for element in elements {
            push(element, to: .back)
        }
    }
}

// MARK: - CustomStringConvertible

#if !hasFeature(Embedded)
    extension Queue.DoubleEnded: CustomStringConvertible where Element: Copyable {
        public var description: String {
            var result = "Queue.DoubleEnded(["
            var i: Index_Primitives.Index<Element>.Count = .zero
            while i < count {
                if i > .zero { result += ", " }
                result += String(describing: _readElement(at: i))
                i += .one
            }
            result += "])"
            return result
        }
    }
#endif

// (Removed: the obsolete `_identity` CoW-test probe forwarded to
// `Buffer.Ring.bufferIdentity` (ObjectIdentifier), which was deleted in the
// value-type Storage.Contiguous<Memory.Heap> migration — it was dead (zero call sites) and
// meaningless on value-type storage; CoW is now a storage-layer guarantee.)
