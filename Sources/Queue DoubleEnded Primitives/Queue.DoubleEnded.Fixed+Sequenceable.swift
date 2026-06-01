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

public import Queue_DoubleEnded_Primitive
public import Buffer_Ring_Primitives
public import Buffer_Ring_Bounded_Primitive
public import Buffer_Ring_Bounded_Primitives
public import Sequence_Primitives

// MARK: - Sequenceable (single-pass, consuming)
//
// Re-uses the backing bounded ring's hand-written scalar witness `Buffer.Ring.Bounded.Scalar`.
// The consuming `makeIterator()` witness is a public member in the type module
// (Queue.DoubleEnded.Fixed+Sequenceable.swift) per [MOD-036] refined-C; this conformance is thin
// and splits the `Iterator` associated-type binding from `Iterable`'s via `@_implements`. The
// prior per-type `Swift.Sequence` conformance + `struct Iterator` are dropped to match the
// exemplar.

extension Queue.DoubleEnded.Fixed: Sequenceable where Element: Copyable {
    @_implements(Sequenceable, Iterator)
    public typealias SequenceableIterator = Buffer<Element>.Ring.Bounded.Scalar

    /// Returns the count as the underestimated count since we know the exact size.
    @inlinable
    public var underestimatedCount: Int { Int(bitPattern: count) }
}
