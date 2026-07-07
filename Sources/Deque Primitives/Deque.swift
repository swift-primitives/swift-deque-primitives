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

public import Buffer_Protocol_Primitives
public import Queue_DoubleEnded_Primitives
public import Store_Protocol_Primitives

/// Standard double-ended queue (deque) vocabulary.
///
/// `Deque<S>` is the top-level, column-generic spelling of the `__QueueDoubleEnded`
/// carrier — the same column vocabulary as the queue family (growable/bounded ring,
/// direct/`Shared`), exposed as a first-class abstract data type. The element-generic
/// front door is the sibling nest alias `Queue<Element>.DoubleEnded` ([DS-028]); this
/// alias preserves the pre-hoist column-generic surface and now names the hoisted
/// carrier directly.
///
/// ```swift
/// var deque = Deque<Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>>.Ring>(minimumCapacity: 4)
/// deque.push(1, to: .back)
/// deque.push(2, to: .front)
/// deque.pop(from: .front)   // Optional(2)
/// ```
public typealias Deque<S: Store.`Protocol` & Buffer.`Protocol` & ~Copyable> = __QueueDoubleEnded<S>
