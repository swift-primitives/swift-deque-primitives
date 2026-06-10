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

// The COLUMN-PINNED deque surface: pushes (growth / front-insert / reject-on-full),
// clear, and capacity ops per ratified column. `Shared` forms cross the box via the
// gate-first scoped accessors ([MEM-OWN-017]: enqueued elements thread as consuming
// closure PARAMETERS).
public import Queue_DoubleEnded_Primitive
public import Queue_Primitive
public import Buffer_Primitive
public import Buffer_Ring_Primitive
public import Buffer_Ring_Bounded_Primitive
public import Storage_Contiguous_Primitives
public import Memory_Heap_Primitives
public import Memory_Allocator_Primitive
public import Shared_Primitive
public import Index_Primitives

// ============================================================================
// MARK: - Push (growable columns: grows; bounded columns: typed-throws on full)
// ============================================================================

extension Queue.DoubleEnded where S: ~Copyable {
    /// Pushes an element at the given end (direct growable column; grows as needed).
    ///
    /// - Complexity: O(1) amortized
    @inlinable
    public mutating func push<E: ~Copyable>(_ element: consuming E, to position: Position)
    where S == Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Ring {
        switch position {
        case .front:
            store.pushFront(element)
        case .back:
            store.pushBack(element)
        }
    }

    /// Pushes an element at the given end (`Shared` growable column; uniqueness
    /// restored first).
    ///
    /// - Complexity: O(1) amortized (O(n) when a copy must be made first)
    @inlinable
    public mutating func push<E: ~Copyable>(_ element: consuming E, to position: Position)
    where S == Shared<E, Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Ring> {
        store.withUnique(consuming: element) { ring, element in
            switch position {
            case .front:
                ring.pushFront(element)
            case .back:
                ring.pushBack(element)
            }
        }
    }

    /// Pushes an element at the given end (direct bounded column).
    ///
    /// - Throws: `Queue<S>.Error.full` when the fixed capacity is exhausted.
    /// - Complexity: O(1)
    @inlinable
    public mutating func push<E: ~Copyable>(_ element: consuming E, to position: Position) throws(Queue<S>.Error)
    where S == Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Ring.Bounded {
        let rejected: E?
        switch position {
        case .front:
            rejected = store.push.front(element)
        case .back:
            rejected = store.push.back(element)
        }
        guard rejected == nil else {
            throw .full
        }
    }

    /// Pushes an element at the given end (`Shared` bounded column; uniqueness
    /// restored first).
    ///
    /// - Throws: `Queue<S>.Error.full` when the fixed capacity is exhausted.
    /// - Complexity: O(1)
    @inlinable
    public mutating func push<E: ~Copyable>(_ element: consuming E, to position: Position) throws(Queue<S>.Error)
    where S == Shared<E, Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Ring.Bounded> {
        let rejected = store.withUnique(consuming: element) { ring, element -> E? in
            switch position {
            case .front:
                return ring.push.front(element)
            case .back:
                return ring.push.back(element)
            }
        }
        guard rejected == nil else {
            throw .full
        }
    }
}

// ============================================================================
// MARK: - Clear (the Shared forms DETACH, preserving siblings)
// ============================================================================

extension Queue.DoubleEnded where S: ~Copyable {
    /// Removes all elements (direct growable column).
    @inlinable
    public mutating func clear<E: ~Copyable>(keepingCapacity: Bool = true)
    where S == Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Ring {
        store.removeAll()
        if !keepingCapacity {
            store = S(minimumCapacity: .zero)
        }
    }

    /// Removes all elements (direct bounded column; the fixed capacity remains).
    @inlinable
    public mutating func clear<E: ~Copyable>()
    where S == Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Ring.Bounded {
        store.remove.all()
    }

    /// Removes all elements (`Shared` growable column; detaches to a fresh box).
    @inlinable
    public mutating func clear<E>(keepingCapacity: Bool = true)
    where S == Shared<E, Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Ring> {
        let capacity: Index_Primitives.Index<E>.Count = keepingCapacity ? store.capacity : .zero
        self.store = Shared(
            Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Ring(minimumCapacity: capacity)
        )
    }

    /// Removes all elements (`Shared` bounded column; detaches to a fresh box of the
    /// same fixed capacity).
    @inlinable
    public mutating func clear<E>()
    where S == Shared<E, Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Ring.Bounded> {
        self.store = Shared(
            Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Ring.Bounded(minimumCapacity: store.capacity)
        )
    }
}

// ============================================================================
// MARK: - Capacity (growable columns)
// ============================================================================

extension Queue.DoubleEnded where S: ~Copyable {
    /// Reserves capacity for at least the given number of elements (direct column).
    @inlinable
    public mutating func reserve<E: ~Copyable>(_ minimumCapacity: Index_Primitives.Index<E>.Count)
    where S == Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Ring {
        store.reserveCapacity(minimumCapacity)
    }

    /// Reserves capacity (`Shared` column; uniquely, behind the gate).
    @inlinable
    public mutating func reserve<E: ~Copyable>(_ minimumCapacity: Index_Primitives.Index<E>.Count)
    where S == Shared<E, Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Ring> {
        store.withUnique { ring in
            ring.reserveCapacity(minimumCapacity)
        }
    }
}

// ============================================================================
// MARK: - Cloning (direct columns; the generic `clone()` covers the CoW columns)
// ============================================================================

extension Queue.DoubleEnded where S: ~Copyable {
    /// Returns an independent copy of this deque (direct growable column).
    @inlinable
    public func clone<E>() -> Self
    where S == Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Ring {
        Self(store: store.clone())
    }

    /// Returns an independent copy of this deque (direct bounded column).
    @inlinable
    public func clone<E>() -> Self
    where S == Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Ring.Bounded {
        Self(store: store.clone())
    }
}
