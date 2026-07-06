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
public import Buffer_Primitive
public import Buffer_Ring_Primitive
public import Storage_Contiguous_Primitives
public import Memory_Allocator_Primitive
public import Memory_Small_Primitives
public import Store_Protocol_Primitives

// The `Buffer.Ring: Column.Direct` fence conformance is checked at the CONSUMER's
// instantiation of `Queue<E>.DoubleEnded.Small<n>`, not here — this alias is generic over
// `S: __ColumnDirect`, so it names no bounded symbol. Per [DS-027].1 leanness the Small
// target does NOT re-export that module. The growable ring's ops are allocation-generic
// ([DS-029] form 2, W3.1), so the Small column is fully usable through the deque surface
// (construct / push-both-ends / clear / reserve / clone), spilling inline→heap on growth.

// MARK: - Queue<E>.DoubleEnded.Small<n> — the inline-budget allocation variant ([DS-028] law 1)

extension __QueueDoubleEnded where S: ~Copyable, S: Store.Direct {
    /// `Queue<E>.DoubleEnded.Small<n>` — the small (inline⊕heap) allocation front door.
    ///
    /// An axis-CHANGING front-door alias ([DS-028] law 1): it re-points the allocation axis
    /// from the direct ring column's leaf to the `Memory.Small<n>` spill-buffer leaf,
    /// preserving the element (`S.Element`) and the ring (double-ended) discipline. The
    /// fence is `where S: `__ColumnDirect`` (spelled `Column.Direct` in the column
    /// vocabulary): the alias applies only at a DIRECT column, so a mis-ordered chain over
    /// `Shared`/bounded — which would silently reset an already-set axis — fails to compile
    /// instead. The carrier's suppression is restated (`where S: ~Copyable`, M1) so the door
    /// is reachable from the move-only canonical column.
    ///
    /// **Units**: `Small<n>` is a **BYTE** budget (`Memory.Small`'s `n`), not an element
    /// count ([DS-028]). `Queue<Int>.DoubleEnded.Small<64>` gives a 64-byte inline budget
    /// (≈ 8 `Int`s) that spills to a heap region on growth past it (never a trap —
    /// `Memory.Small: Memory.Growable`).
    ///
    /// Elements live inline until the budget is exceeded; the allocation-generic op pins on
    /// `__QueueDoubleEnded` ([DS-029] form 2, `Resource: Memory.Growable`) serve this column
    /// with no per-leaf duplication.
    public typealias Small<let n: Int> =
        __QueueDoubleEnded<Buffer<Storage<Memory.Allocator<Memory.Small<n>>>.Contiguous<S.Element>>.Ring>
}
