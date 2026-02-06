// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-standards open source project
//
// Copyright (c) 2024-2025 Coen ten Thije Boonkkamp and the swift-standards project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

import Testing
@testable import Queue_Primitives

/// Tests verifying Deque.Small inline-to-heap spill behavior.
/// Migrated from: Experiments/deque-small-spill
@Suite("Deque.Small - Spill Behavior")
struct DequeSmallSpillTests {

    /// ~Copyable element for testing spill with move-only types
    struct TrackedValue: ~Copyable {
        let id: Int
    }

    @Test("Small stays inline under capacity")
    func staysInlineUnderCapacity() {
        var small = Deque<Int>.Small<4>()
        small.push(1, to: .back)
        small.push(2, to: .back)
        small.push(3, to: .back)

        let count = small.count
        let isSpilled = small.isSpilled
        #expect(count == 3)
        #expect(!isSpilled)
    }

    @Test("Small spills when exceeding capacity")
    func spillsWhenExceedingCapacity() {
        var small = Deque<Int>.Small<4>()
        for i in 1...4 {
            small.push(i, to: .back)
        }
        let beforeSpill = small.isSpilled
        #expect(!beforeSpill)

        small.push(5, to: .back)  // Triggers spill
        let afterSpill = small.isSpilled
        let count = small.count
        #expect(afterSpill)
        #expect(count == 5)

        var elements: [Int] = []
        small.forEach { elements.append($0) }
        #expect(elements == [1, 2, 3, 4, 5])
    }

    @Test("Small spill preserves ring buffer order")
    func spillPreservesRingBufferOrder() {
        var small = Deque<Int>.Small<4>()

        // Create ring buffer wraparound scenario
        small.push(1, to: .back)
        small.push(2, to: .back)
        small.push(0, to: .front)  // Now [0, 1, 2] with head shifted

        _ = small.pop(from: .front)  // Remove 0, now [1, 2]
        small.push(3, to: .back)  // [1, 2, 3]
        small.push(4, to: .back)  // [1, 2, 3, 4] - at capacity

        let beforeSpill = small.isSpilled
        #expect(!beforeSpill)

        small.push(5, to: .back)  // Triggers spill

        let afterSpill = small.isSpilled
        #expect(afterSpill)

        var elements: [Int] = []
        small.forEach { elements.append($0) }
        #expect(elements == [1, 2, 3, 4, 5])
    }

    @Test("Small with ~Copyable elements spills correctly")
    func spillWithNonCopyableElements() {
        var small = Deque<TrackedValue>.Small<2>()
        small.push(TrackedValue(id: 1), to: .back)
        small.push(TrackedValue(id: 2), to: .back)

        let beforeSpill = small.isSpilled
        #expect(!beforeSpill)

        small.push(TrackedValue(id: 3), to: .back)  // Triggers spill

        let afterSpill = small.isSpilled
        let count = small.count
        #expect(afterSpill)
        #expect(count == 3)

        var ids: [Int] = []
        small.forEach { ids.append($0.id) }
        #expect(ids == [1, 2, 3])
    }

    @Test("Small operations work after spill")
    func operationsWorkAfterSpill() {
        var small = Deque<Int>.Small<2>()
        small.push(1, to: .back)
        small.push(2, to: .back)
        small.push(3, to: .back)  // Spills

        // Push to front after spill
        small.push(0, to: .front)

        // Pop from back after spill
        let back = small.pop(from: .back)

        // Peek after spill
        let front = small.peek(at: .front)

        var elements: [Int] = []
        small.forEach { elements.append($0) }

        #expect(back == 3)
        #expect(front == 0)
        #expect(elements == [0, 1, 2])
    }

    @Test("Small clear does not shrink back to inline")
    func clearDoesNotShrinkToInline() {
        var small = Deque<Int>.Small<2>()
        small.push(1, to: .back)
        small.push(2, to: .back)
        small.push(3, to: .back)  // Spills

        let spilledBefore = small.isSpilled
        #expect(spilledBefore)

        small.clear()

        let spilledAfter = small.isSpilled  // Still on heap (documented behavior)
        let isEmpty = small.isEmpty
        #expect(spilledAfter)
        #expect(isEmpty)

        // Can still push after clear
        small.push(10, to: .back)
        let count = small.count
        #expect(count == 1)
    }

    @Test("Small capacity reflects current storage")
    func capacityReflectsStorage() {
        var small = Deque<Int>.Small<4>()
        let inlineCapacity = small.capacity
        #expect(inlineCapacity == 4)

        for i in 1...5 {
            small.push(i, to: .back)
        }

        let heapCapacity = small.capacity
        #expect(heapCapacity >= 5)
    }
}
