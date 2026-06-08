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

public import Buffer_Ring_Primitives
public import Buffer_Ring_Bounded_Primitive
public import Buffer_Linear_Primitive
public import Buffer_Linear_Primitives
public import Queue_DoubleEnded_Primitive
public import Queue_Primitives

// ============================================================================
// MARK: - Queue.DoubleEnded (Dynamic)
// ============================================================================

// MARK: Subscript

extension Queue.DoubleEnded where Element: Copyable {
    /// Accesses the element at the given index.
    ///
    /// - Parameter index: The index of the element to access (0 = front).
    /// - Precondition: `index` must be in bounds.
    @inlinable
    public subscript(index: Queue.Index) -> Element {
        _read {
            yield _buffer[index]
        }
        _modify {
            yield &_buffer[index]
        }
    }
}

// MARK: removeAll()

extension Queue.DoubleEnded where Element: Copyable {
    /// Removes all elements from the deque.
    @inlinable
    public mutating func removeAll() {
        clear(keepingCapacity: false)
    }
}

// MARK: Sequence.Drain.Protocol

extension Queue.DoubleEnded: Sequence.Drain.`Protocol` where Element: Copyable {
    /// Drains all elements in front-to-back order, passing each to the closure with ownership.
    ///
    /// After this method returns, the deque is empty but still usable.
    ///
    /// - Parameter body: A closure that receives each drained element with ownership.
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public mutating func drain(_ body: (consuming Element) -> Void) {
        makeUnique()
        while let element = pop(from: .front) {
            body(element)
        }
    }
}

// MARK: Conditional Drain

extension Queue.DoubleEnded where Element: Copyable {
    /// Drains elements front-to-back while the predicate returns true.
    @inlinable
    public mutating func drain(
        while predicate: (borrowing Element) -> Bool,
        _ body: (consuming Element) -> Void
    ) {
        makeUnique()
        while let element = peek(at: .front), predicate(element) {
            body(pop(from: .front)!)
        }
    }
}

// MARK: Drain Property Accessor

extension Queue.DoubleEnded where Element: Copyable {
    /// Accessor for drain operations.
    public var drain: Property<Sequence.Drain, Self>.Inout {
        mutating _read {
            yield Property<Sequence.Drain, Self>.Inout(&self)
        }
        mutating _modify {
            var accessor = Property<Sequence.Drain, Self>.Inout(&self)
            yield &accessor
        }
    }
}

// MARK: Index navigation

extension Queue.DoubleEnded where Element: Copyable {
    @inlinable
    public var startIndex: Queue.Index { .zero }

    @inlinable
    public var endIndex: Queue.Index { count.map(Ordinal.init) }

    @inlinable
    public func index(after i: Queue.Index) -> Queue.Index { i.successor.saturating() }
}

// MARK: Collection.Bidirectional

extension Queue.DoubleEnded: Collection.Bidirectional where Element: Copyable {
    @inlinable
    public func index(before i: Queue.Index) -> Queue.Index { try! i.predecessor.exact() }
}

// MARK: Collection.Protocol

extension Queue.DoubleEnded: Collection.`Protocol` where Element: Copyable {}

// MARK: Collection.Access.Random

extension Queue.DoubleEnded: Collection.Access.Random where Element: Copyable {}

// ============================================================================
// MARK: - Queue.DoubleEnded.Fixed
// ============================================================================

// MARK: removeAll()

extension Queue.DoubleEnded.Fixed where Element: Copyable {
    /// Removes all elements from the deque.
    ///
    /// The capacity remains unchanged.
    @inlinable
    public mutating func removeAll() {
        clear()
    }
}

// MARK: Sequence.Drain.Protocol

extension Queue.DoubleEnded.Fixed where Element: Copyable {
    /// Drains all elements in front-to-back order (CoW-aware).
    ///
    /// Ensures unique storage before draining. Overrides the base (~Copyable)
    /// drain with copy-on-write preparation per [IMPL-025].
    ///
    /// - Parameter body: A closure that receives each drained element with ownership.
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public mutating func drain(_ body: (consuming Element) -> Void) {
        makeUnique()
        while let element = pop(from: .front) {
            body(element)
        }
    }
}

// MARK: Fixed Conditional Drain (Copyable)

extension Queue.DoubleEnded.Fixed where Element: Copyable {
    /// Drains elements front-to-back while the predicate returns true (CoW-aware).
    @inlinable
    public mutating func drain(
        while predicate: (borrowing Element) -> Bool,
        _ body: (consuming Element) -> Void
    ) {
        makeUnique()
        while let element = peek(at: .front), predicate(element) {
            body(pop(from: .front)!)
        }
    }
}

// MARK: Subscript

extension Queue.DoubleEnded.Fixed where Element: Copyable {
    /// Accesses the element at the given index.
    ///
    /// - Parameter index: The index of the element to access (0 = front).
    /// - Precondition: `index` must be in bounds.
    @inlinable
    public subscript(index: Queue.Index) -> Element {
        _read {
            yield _buffer[index]
        }
        _modify {
            yield &_buffer[index]
        }
    }
}

// MARK: Drain Property Accessor

extension Queue.DoubleEnded.Fixed where Element: Copyable {
    /// Accessor for drain operations.
    public var drain: Property<Sequence.Drain, Self>.Inout {
        mutating _read {
            yield Property<Sequence.Drain, Self>.Inout(&self)
        }
        mutating _modify {
            var accessor = Property<Sequence.Drain, Self>.Inout(&self)
            yield &accessor
        }
    }
}

// MARK: Index navigation

extension Queue.DoubleEnded.Fixed where Element: Copyable {
    @inlinable
    public var startIndex: Queue.Index { .zero }

    @inlinable
    public var endIndex: Queue.Index { count.map(Ordinal.init) }

    @inlinable
    public func index(after i: Queue.Index) -> Queue.Index { i.successor.saturating() }
}

// MARK: Collection.Bidirectional

extension Queue.DoubleEnded.Fixed: Collection.Bidirectional where Element: Copyable {
    @inlinable
    public func index(before i: Queue.Index) -> Queue.Index { try! i.predecessor.exact() }
}

// MARK: Collection.Protocol

extension Queue.DoubleEnded.Fixed: Collection.`Protocol` where Element: Copyable {}

// MARK: Collection.Access.Random

extension Queue.DoubleEnded.Fixed: Collection.Access.Random where Element: Copyable {}

