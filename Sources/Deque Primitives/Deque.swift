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

public import Queue_DoubleEnded_Primitives

/// A double-ended queue: a first-class alias for ``Queue/DoubleEnded``.
///
/// `Deque` is the top-level spelling of the nested `Queue<Element>.DoubleEnded`
/// type. The deque is ring-backed (it shares `Buffer<Storage<Element>.Contiguous<Memory.Heap<Element>>>.Ring` with the base
/// `Queue`) yet is exposed as a first-class abstract data type.
///
/// ```swift
/// var deque = Deque<Int>()
/// deque.push(1, to: .back)
/// deque.push(2, to: .front)
/// deque.pop(from: .front)   // Optional(2)
/// ```
public typealias Deque<Element: ~Copyable> = Queue<Element>.DoubleEnded
