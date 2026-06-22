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

public import Queue_Primitive
public import Store_Protocol_Primitives
public import Buffer_Protocol_Primitives
public import Index_Primitives

/// Standard double-ended queue (deque) vocabulary.
///
/// `Deque<S>` is the top-level spelling of the nested `Queue<S>.DoubleEnded` — the
/// same column vocabulary as `Queue<S>` (growable/bounded ring, direct/`Shared`),
/// exposed as a first-class abstract data type.
///
/// ```swift
/// var deque = Deque<Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>>.Ring>(minimumCapacity: 4)
/// deque.push(1, to: .back)
/// deque.push(2, to: .front)
/// deque.pop(from: .front)   // Optional(2)
/// ```
public typealias Deque<S: Store.`Protocol` & Buffer.`Protocol` & ~Copyable> = Queue<S>.DoubleEnded
    where S.Count == Index_Primitives.Index<S.Element>.Count
