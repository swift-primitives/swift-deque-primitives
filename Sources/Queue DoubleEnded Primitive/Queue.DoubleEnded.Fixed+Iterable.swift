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
public import Buffer_Ring_Primitives
public import Buffer_Ring_Bounded_Primitive
public import Buffer_Ring_Bounded_Primitives
public import Iterable
public import Iterator_Primitive
public import Iterator_Chunk_Primitives

// MARK: - Iterable (multipass, borrowing) — via materialising adapter
//
// `Queue.DoubleEnded.Fixed` is a bounded ring buffer: it has NO single contiguous element span
// (the ring wraps), so — unlike the contiguous containers which vend `Iterator.Chunk` over a
// `Memory.Contiguous.Protocol` span — it produces its bulk iterator by wrapping the backing bounded
// ring's hand-written scalar witness `Buffer.Ring.Bounded.Scalar` in
// `Iterator_Primitive.Iterator.Materializing`. The deque therefore does NOT conform
// `Memory.Contiguous.Protocol` (no element span).
//
// `@_implements` splits the unified `Iterator` associated type: `Iterable.Iterator` binds the
// materialising bulk iterator here; `Sequenceable.Iterator` binds the scalar
// (Queue.DoubleEnded.Fixed+Sequenceable.swift in the ops module).

extension Queue.DoubleEnded.Fixed: Iterable where Element: Copyable {
    @_implements(Iterable, Iterator)
    public typealias IterableIterator = Iterator_Primitive.Iterator.Materializing<Buffer<Storage<Element>.Heap>.Ring.Bounded.Scalar>

    /// Iterable's bulk span witness: wraps the bounded ring's scalar walk in the generator
    /// materialise adapter. Iterates a copy-on-write snapshot of the ring (multipass-safe).
    @inlinable
    @_lifetime(borrow self)
    @_implements(Iterable, makeIterator())
    public borrowing func iterableMakeIterator() -> Iterator_Primitive.Iterator.Materializing<Buffer<Storage<Element>.Heap>.Ring.Bounded.Scalar> {
        var snapshot = _buffer
        return Iterator_Primitive.Iterator.Materializing(snapshot.makeIterator())
    }
}
