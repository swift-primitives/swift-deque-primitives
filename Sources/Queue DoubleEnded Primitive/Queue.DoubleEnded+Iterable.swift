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

public import Queue_Primitives
public import Memory_Heap_Primitives
public import Storage_Contiguous_Primitives
public import Buffer_Ring_Primitive
public import Buffer_Ring_Primitives
public import Iterable
public import Iterator_Primitive
public import Iterator_Chunk_Primitives

// MARK: - Iterable (multipass, borrowing) — via materialising adapter
//
// `Queue.DoubleEnded` is a ring-buffer deque: it has NO single contiguous element span (the ring
// wraps), so — unlike the contiguous containers which vend `Iterator.Chunk` over a
// `Memory.Contiguous.Protocol` span — it produces its bulk iterator by wrapping the backing ring's
// hand-written scalar witness `Buffer.Ring.Scalar` in `Iterator_Primitive.Iterator.Materializing`,
// the span-primitive adapter for generator-style sequences. The deque therefore does NOT conform
// `Memory.Contiguous.Protocol` (no element span).
//
// `Buffer.Ring.Scalar` is itself the `~Copyable` hand-written GR3 scalar witness (demangle-safe,
// per Buffer.Ring+Sequence.Protocol), so `Queue.DoubleEnded` binds its iterators DIRECTLY to it.
//
// Both `Iterable` and `Sequenceable` declare `associatedtype Iterator`, which Swift unifies; the
// dual conformer splits the two bindings with `@_implements`. `Iterable.Iterator` binds to the
// materialising bulk iterator here; `Sequenceable.Iterator` binds to the scalar
// (Queue.DoubleEnded+Sequenceable.swift in the ops module).

extension Queue.DoubleEnded: Iterable where Element: Copyable {
    @_implements(Iterable, Iterator)
    public typealias IterableIterator = Iterator_Primitive.Iterator.Materializing<Buffer<Storage<Element>.Contiguous<Memory.Heap<Element>>>.Ring.Scalar>

    /// Iterable's bulk span witness: wraps the ring's scalar walk in the generator materialise
    /// adapter. Iterates a copy-on-write snapshot of the ring (multipass-safe).
    @inlinable
    @_lifetime(borrow self)
    @_implements(Iterable, makeIterator())
    public borrowing func iterableMakeIterator() -> Iterator_Primitive.Iterator.Materializing<Buffer<Storage<Element>.Contiguous<Memory.Heap<Element>>>.Ring.Scalar> {
        var snapshot = _buffer
        return Iterator_Primitive.Iterator.Materializing(snapshot.makeIterator())
    }
}
