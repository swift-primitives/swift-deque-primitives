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

import Deque_Primitives
import Queue_Primitive
import Buffer_Primitive
import Buffer_Ring_Primitive
import Buffer_Ring_Bounded_Primitive
import Storage_Contiguous_Primitives
import Memory_Heap_Primitives
import Memory_Allocator_Primitive
import Ownership_Shared_Primitive
import Index_Primitives
import Tagged_Primitives_Standard_Library_Integration
import Ordinal_Primitives
import Ordinal_Primitives_Standard_Library_Integration
import Cardinal_Primitives

// The ratified ring columns, spelled as the package's own test suite spells them.

typealias HeapStorage<E: ~Copyable> =
    Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>

typealias GrowableRing<E: ~Copyable> = Buffer<HeapStorage<E>>.Ring

typealias MoveDeque<E: ~Copyable> = Deque<GrowableRing<E>>

typealias CoWDeque<E: ~Copyable> = Deque<Ownership.Shared<E, GrowableRing<E>>>

extension Bench {
    /// Typed count from a runtime size via the non-throwing `UInt` lane.
    static func count<E>(_ n: Int) -> Index_Primitives.Index<E>.Count {
        Index_Primitives.Index<E>.Count(Cardinal(UInt(n)))
    }

    /// Three steady-state pair shapes at occupancy n (per-op = one ring op):
    /// `backBack.steady` push(.back)+pop(.back) — both ends O(1) on every
    /// subject (stdlib: append/removeLast — the fair fight); `frontFront.steady`
    /// push(.front)+pop(.front) — ring O(1) vs stdlib insert(at:0)/removeFirst
    /// both O(n) (copy-class target); `rotate.steady` push(.back)+pop(.front) —
    /// the queue-through-deque wrap path vs stdlib append/removeFirst
    /// (removeFirst O(n), copy-class target).
    static func dequeCases() -> [Result] {
        var results: [Result] = []

        for n in sizes {
            let pairs = Swift.max(1, (elementOpsTarget / 2) / n) * n
            let ops = pairs * 2
            let shiftPairs = Swift.max(16, (copiedSlotsTarget / 2) / n)
            let shiftOps = shiftPairs * 2
            let seed = opaque(1)

            var d = MoveDeque<Int>(minimumCapacity: count(n))
            for i in 0..<n { d.push(i, to: .back) }
            var c = CoWDeque<Int>(minimumCapacity: count(n))
            for i in 0..<n { c.push(i, to: .back) }
            var sa: [Int] = []
            sa.reserveCapacity(n)
            for i in 0..<n { sa.append(i) }

            results.append(Result(
                name: "backBack.steady", subject: "tower.direct", n: n, opsPerBatch: ops,
                perOpNs: sample(opsPerBatch: ops) {
                    var sum = 0
                    for i in 0..<pairs {
                        d.push(i &+ seed, to: .back)
                        sum &+= d.pop(from: .back) ?? 0
                    }
                    sink(sum)
                }
            ))

            results.append(Result(
                name: "backBack.steady", subject: "tower.cow", n: n, opsPerBatch: ops,
                perOpNs: sample(opsPerBatch: ops) {
                    var sum = 0
                    for i in 0..<pairs {
                        c.push(i &+ seed, to: .back)
                        sum &+= c.pop(from: .back) ?? 0
                    }
                    sink(sum)
                }
            ))

            results.append(Result(
                name: "backBack.steady", subject: "stdlib", n: n, opsPerBatch: ops,
                perOpNs: sample(opsPerBatch: ops) {
                    var sum = 0
                    for i in 0..<pairs {
                        sa.append(i &+ seed)
                        sum &+= sa.removeLast()
                    }
                    sink(sum)
                }
            ))

            results.append(Result(
                name: "frontFront.steady", subject: "tower.direct", n: n, opsPerBatch: ops,
                perOpNs: sample(opsPerBatch: ops) {
                    var sum = 0
                    for i in 0..<pairs {
                        d.push(i &+ seed, to: .front)
                        sum &+= d.pop(from: .front) ?? 0
                    }
                    sink(sum)
                }
            ))

            results.append(Result(
                name: "frontFront.steady", subject: "tower.cow", n: n, opsPerBatch: ops,
                perOpNs: sample(opsPerBatch: ops) {
                    var sum = 0
                    for i in 0..<pairs {
                        c.push(i &+ seed, to: .front)
                        sum &+= c.pop(from: .front) ?? 0
                    }
                    sink(sum)
                }
            ))

            results.append(Result(
                name: "frontFront.steady", subject: "stdlib", n: n, opsPerBatch: shiftOps,
                perOpNs: sample(opsPerBatch: shiftOps) {
                    var sum = 0
                    for i in 0..<shiftPairs {
                        sa.insert(i &+ seed, at: 0)
                        sum &+= sa.removeFirst()
                    }
                    sink(sum)
                }
            ))

            results.append(Result(
                name: "rotate.steady", subject: "tower.direct", n: n, opsPerBatch: ops,
                perOpNs: sample(opsPerBatch: ops) {
                    var sum = 0
                    for i in 0..<pairs {
                        d.push(i &+ seed, to: .back)
                        sum &+= d.pop(from: .front) ?? 0
                    }
                    sink(sum)
                }
            ))

            results.append(Result(
                name: "rotate.steady", subject: "tower.cow", n: n, opsPerBatch: ops,
                perOpNs: sample(opsPerBatch: ops) {
                    var sum = 0
                    for i in 0..<pairs {
                        c.push(i &+ seed, to: .back)
                        sum &+= c.pop(from: .front) ?? 0
                    }
                    sink(sum)
                }
            ))

            results.append(Result(
                name: "rotate.steady", subject: "stdlib", n: n, opsPerBatch: shiftOps,
                perOpNs: sample(opsPerBatch: shiftOps) {
                    var sum = 0
                    for i in 0..<shiftPairs {
                        sa.append(i &+ seed)
                        sum &+= sa.removeFirst()
                    }
                    sink(sum)
                }
            ))
        }

        return results
    }
}
