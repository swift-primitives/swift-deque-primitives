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

public import Buffer_Primitive
public import Buffer_Ring_Primitive
public import Buffer_Ring_Bounded_Primitive
public import Store_Protocol_Primitives
public import Storage_Contiguous_Primitives
public import Memory_Heap_Primitives
public import Memory_Allocator_Primitive
public import Shared_Primitive
public import Index_Primitives

// MARK: - __QueueDoubleEnded (the deque carrier — generic over the ring COLUMN)

/// A double-ended queue — the semantic ADT over the SAME ring storage COLUMN as
/// `__Queue`.
///
/// The ratified two-column design (ADT-families tranche, 2026-06-10): the carrier is
/// generic over `S`, and **copyability flows from the column** (S5):
///
/// ```swift
/// __QueueDoubleEnded<            Buffer<…>.Ring        >   // zero-cost MOVE-ONLY (default)
/// __QueueDoubleEnded<Shared<Int, Buffer<…>.Ring>       >   // explicit CoW value semantics
/// __QueueDoubleEnded<            Buffer<…>.Ring.Bounded>   // fixed-capacity (the former .Fixed)
/// __QueueDoubleEnded<Shared<Int, Buffer<…>.Ring.Bounded>>  // fixed-capacity CoW
/// ```
///
/// Pops and peeks at BOTH ends ride the front-anchored seam generically
/// (`move(at: .zero)` / `move(at: count − 1)`); pushes pin per column (back-push
/// grows or rejects; front-push is a column op crossing the `Shared` box via
/// `withUnique`). The former nested `.Fixed` is dissolved into the bounded column
/// (ASK-E).
///
/// ## Carrier (hoisted per [API-IMPL-009]/[PKG-NAME-006])
///
/// `__QueueDoubleEnded` is the bound-free carrier ([DS-025]): its column parameter
/// `S` is bound `~Copyable` **only**; every capability (observability, the both-end
/// pops/peeks, construction/growth) attaches by conditional `@inlinable` extension
/// keyed on the seams the column conforms. The PUBLIC spelling of the family is the
/// front-door NEST alias `Queue<E>.DoubleEnded` (D4.1 sense (b), [DS-028]), declared
/// in `Queue.DoubleEnded.FrontDoor.swift`; the top-level `Deque<S>` alias
/// (`Deque Primitives`) names the carrier directly. The hoisted name never appears in
/// consumer signatures.
@_documentation(visibility: public)
@frozen
public struct __QueueDoubleEnded<S: ~Copyable>: ~Copyable {

    /// The ring storage column.
    @usableFromInline
    package var store: S

    /// Which end of the deque to operate on.
    public enum Position: Sendable, Equatable {
        case front
        case back
    }

    /// Wraps an existing column.
    @inlinable
    public init(store: consuming S) {
        self.store = store
    }

    /// Consumes the deque, yielding its storage column.
    @inlinable
    public consuming func take() -> S {
        store
    }
}

// MARK: - Conditional Conformances (co-located per [COPY-FIX-004])

/// The S5 chain: copyability flows from the column.
extension __QueueDoubleEnded: Copyable where S: Copyable {}

extension __QueueDoubleEnded: Sendable where S: Sendable & ~Copyable {}

// MARK: - Typed index (re-anchoring front-relative positions, like the queue's)

extension __QueueDoubleEnded where S: Store.`Protocol` & ~Copyable {
    public typealias Index = Index_Primitives.Index<S.Element>
}

// MARK: - Column-pinned construction

extension __QueueDoubleEnded where S: ~Copyable {
    /// Creates an empty MOVE-ONLY growable deque (the default ownership column).
    @inlinable
    public init<E: ~Copyable>(minimumCapacity: Index_Primitives.Index<E>.Count = .zero)
    where S == Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Ring {
        self.init(store: S(minimumCapacity: minimumCapacity))
    }

    /// Creates an empty MOVE-ONLY fixed-capacity deque (the former `.Fixed`).
    @inlinable
    public init<E: ~Copyable>(capacity: Index_Primitives.Index<E>.Count)
    where S == Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Ring.Bounded {
        self.init(store: S(minimumCapacity: capacity))
    }

    /// Creates an empty CoW (value-semantic) growable deque on the `Shared` column.
    @inlinable
    public init<E>(minimumCapacity: Index_Primitives.Index<E>.Count = .zero)
    where S == Shared<E, Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Ring> {
        self.init(store: Shared(
            Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Ring(minimumCapacity: minimumCapacity)
        ))
    }

    /// Creates an empty statically-unique deque of move-only elements on the `Shared` column.
    @inlinable
    public init<E: ~Copyable>(minimumCapacity: Index_Primitives.Index<E>.Count = .zero)
    where S == Shared<E, Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Ring> {
        self.init(store: Shared(
            Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Ring(minimumCapacity: minimumCapacity)
        ))
    }

    /// Creates an empty CoW fixed-capacity deque on the `Shared` bounded column.
    @inlinable
    public init<E>(capacity: Index_Primitives.Index<E>.Count)
    where S == Shared<E, Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Ring.Bounded> {
        self.init(store: Shared(
            Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Ring.Bounded(minimumCapacity: capacity)
        ))
    }

    /// Creates an empty statically-unique fixed-capacity deque of move-only elements
    /// on the `Shared` bounded column.
    @inlinable
    public init<E: ~Copyable>(capacity: Index_Primitives.Index<E>.Count)
    where S == Shared<E, Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Ring.Bounded> {
        self.init(store: Shared(
            Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Ring.Bounded(minimumCapacity: capacity)
        ))
    }
}
