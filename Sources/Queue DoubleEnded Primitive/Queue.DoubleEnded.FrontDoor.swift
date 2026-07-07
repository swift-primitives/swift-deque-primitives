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
public import Memory_Allocator_Primitive
public import Memory_Heap_Primitives
public import Queue_Primitive
public import Storage_Contiguous_Primitives
public import Store_Protocol_Primitives

// MARK: - Queue<E>.DoubleEnded — the sibling NEST alias ([DS-028], D4.1 sense (b))

extension __Queue where S: Store.`Protocol` & ~Copyable {

    /// A double-ended queue over the family's default (growable move-only ring) column.
    ///
    /// This is a **nest alias** (D4.1 sense (b), [DS-028]): it merely NAMES the
    /// `__QueueDoubleEnded` sibling carrier's canonical front door under the `Queue`
    /// family namespace, so consumers spell `Queue<Element>.DoubleEnded`. The deque is
    /// a distinct end-surface sibling ([DS-027].2, its own package/carrier), not a
    /// variant of `__Queue`; only its nest alias lives here. The bounded / `Shared`
    /// column points are reached through the top-level `Deque<S>` alias
    /// (`Deque Primitives`) or the carrier's pinned constructors; their own front-door
    /// aliases are consumer-pulled and land as they gain live consumers.
    public typealias DoubleEnded =
        __QueueDoubleEnded<Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<S.Element>>.Ring>
}
