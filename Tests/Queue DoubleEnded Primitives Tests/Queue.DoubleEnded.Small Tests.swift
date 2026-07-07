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
import Index_Primitives
import Memory_Small_Primitives
import Queue_DoubleEnded_Small_Primitive
import Queue_Primitive
import Testing

// MARK: - W3.2 `Queue<E>.DoubleEnded.Small<n>` door coverage
//
// The double-ended analogue of the ring's W3.1 `.Small` probe, exercised THROUGH the
// family front door `Queue<Int>.DoubleEnded.Small<64>` ([DS-028] law 1): a constrained
// axis-changing alias re-pointing the ring column's leaf to `Memory.Small<n>`. Proves
// (a) the door RESOLVES from the nest alias, (b) push-both-ends past the inline budget
// spills inline→heap and stays FIFO, and (c) the door is reachable from a MOVE-ONLY
// element (the M1 `~Copyable` restatement on the door extension).

@Suite("Queue<E>.DoubleEnded.Small<n> door")
struct DequeSmallDoorTests {

    @Test
    func `the door resolves and is FIFO across the inline→heap spill (byte budget)`() {
        // `Memory.Small`'s n is a BYTE budget: 64 bytes ≈ 8 `Int`s inline before spilling.
        var d = Queue<Int>.DoubleEnded.Small<64>(minimumCapacity: 4)
        let empty = d.isEmpty
        #expect(empty)

        // Push 16 `Int`s (128 bytes) to the back, past the 64-byte inline budget, forcing
        // at least one inline→heap spill during growth (the ring's form-2 grow path).
        for value in 1...16 {
            d.push(value, to: .back)
        }
        #expect(d.count == Index<Int>.Count(16))

        // Pop from the front — FIFO order preserved across the spill boundary.
        var seen: [Int] = []
        while let x = d.pop(from: .front) { seen.append(x) }
        #expect(seen == Array(1...16))
    }

    @Test
    func `the door supports both ends + the growable family surface (push / pop / reserve / clear / clone)`() {
        var d = Queue<Int>.DoubleEnded.Small<64>()
        d.push(1, to: .back)  // [1]
        d.push(2, to: .back)  // [1, 2]
        d.push(0, to: .front)  // [0, 1, 2]

        #expect(d.pop(from: .front) == 0)
        #expect(d.pop(from: .back) == 2)
        #expect(d.count == Index<Int>.Count(1))

        // reserve is allocation-generic (form 2) on the Small leaf.
        d.reserve(Index<Int>.Count(32))
        #expect(d.capacity >= Index<Int>.Count(32))

        // clone (form 2) detaches; a push on the copy leaves the original intact.
        var copy = d.clone()
        copy.push(9, to: .back)
        #expect(d.count == Index<Int>.Count(1))
        #expect(copy.count == Index<Int>.Count(2))

        // clear (form 2) empties.
        d.clear()
        let cleared = d.isEmpty
        #expect(cleared)
    }

    @Test
    func `the door is reachable from a MOVE-ONLY element and tears down exactly once (M1 restatement)`() {
        // Compile-probe: `Queue<DequeSmallItem>.DoubleEnded.Small<64>` typechecks ONLY if
        // the door extension restates `where S: ~Copyable` (M1) — the canonical column is
        // move-only, so a bare `where S: Store.Direct` would re-impose Copyable and make
        // `.Small` unreachable here.
        DequeSmallProbe.reset()
        do {
            var d = Queue<DequeSmallItem>.DoubleEnded.Small<64>(minimumCapacity: 2)
            d.push(DequeSmallItem(1), to: .back)
            d.push(DequeSmallItem(2), to: .back)
            d.push(DequeSmallItem(0), to: .front)  // 3×8 < 64: still inline
            #expect(d.count == Index<DequeSmallItem>.Count(3))

            if let front = d.pop(from: .front) {
                #expect(front.id == 0)  // front-pushed; destroyed at scope end
            } else {
                Issue.record("expected the front element")
            }
        }
        // Every constructed element torn down exactly once (the popped one + the two
        // drained at teardown).
        #expect(DequeSmallProbe.destroyedSorted == [0, 1, 2])
    }
}

private struct DequeSmallItem: ~Copyable {
    let id: Int
    init(_ id: Int) { self.id = id }
    deinit { DequeSmallProbe.recordDestroy(id) }
}

private enum DequeSmallProbe {
    nonisolated(unsafe) static var _destroyed: [Int] = []
    static func reset() { unsafe _destroyed = [] }
    static func recordDestroy(_ id: Int) { unsafe _destroyed.append(id) }
    static var destroyedSorted: [Int] { unsafe _destroyed.sorted() }
}
