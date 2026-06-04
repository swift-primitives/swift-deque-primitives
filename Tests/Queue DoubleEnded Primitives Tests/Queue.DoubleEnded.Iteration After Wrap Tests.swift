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

import Queue_DoubleEnded_Primitives_Test_Support
import Testing

@testable import Queue_DoubleEnded_Primitives

// Regression coverage for iterating a deque whose backing ring is in a head-offset
// or wrapped (`.two`) state. The thin 22-test baseline only iterated freshly built
// (head == 0) deques, so it never exercised the logical→physical mapping the
// scalar/iterable iterators perform once `pop(from: .front)` has advanced the ring
// head. A wrapped ring places front-segment physical slots in `[count, capacity)`;
// reading them through a count-bounded span trapped "Index out of bounds" /
// "Range requires lowerBound <= upperBound". These tests replay the broadcast
// trim/interleave op-patterns (push-back + pop-front churn while scanning with
// `first(where:)` / `contains`) that surfaced the defect in swift-async-primitives'
// BroadcastStressTests.
@Suite("Queue.DoubleEnded - Iteration after wrap")
struct QueueDoubleEndedIterationAfterWrapTests {

    private typealias Pos = Queue<Int>.DoubleEnded.Position

    /// Drive the ring into a wrapped (`.two`) state, then scan with `first(where:)`.
    @Test
    func `first(where:) over wrapped ring`() {
        var deque = Queue<Int>.DoubleEnded()
        deque.reserve(8)
        for i in 0..<8 { deque.push(i, to: Pos.back) }
        for _ in 0..<5 { _ = deque.pop(from: Pos.front) }   // head advances to 5
        for i in 100..<104 { deque.push(i, to: Pos.back) }  // wraps → .two

        #expect(deque.first(where: { $0 == 102 }) == 102)
        #expect(deque.first(where: { $0 == 7 }) == 7)        // last of pre-wrap segment
        #expect(deque.first(where: { $0 == 999 }) == nil)
    }

    /// Same wrapped state, scan with `contains`.
    @Test
    func `contains over wrapped ring`() {
        var deque = Queue<Int>.DoubleEnded()
        deque.reserve(8)
        for i in 0..<8 { deque.push(i, to: Pos.back) }
        for _ in 0..<5 { _ = deque.pop(from: Pos.front) }
        for i in 100..<104 { deque.push(i, to: Pos.back) }

        #expect(deque.contains(where: { $0 == 103 }))
        #expect(!deque.contains(where: { $0 == 0 }))         // popped
    }

    /// `.one` initialization but head > 0 (front segment starts mid-allocation).
    @Test
    func `first(where:) with head offset, no wrap`() {
        var deque = Queue<Int>.DoubleEnded()
        deque.reserve(8)
        for i in 0..<4 { deque.push(i, to: Pos.back) }
        for _ in 0..<2 { _ = deque.pop(from: Pos.front) }    // head=2, count=2, .one(2..<4)

        #expect(deque.first(where: { $0 == 3 }) == 3)
        #expect(deque.contains(where: { $0 == 2 }))
    }

    /// Iteration over a wrapped ring yields exact FIFO order (forEach is the
    /// borrowing terminal; the consuming-scalar agreement is locked in at the
    /// buffer-ring level).
    @Test
    func `iteration over wrapped ring is FIFO`() {
        var deque = Queue<Int>.DoubleEnded()
        deque.reserve(8)
        for i in 0..<8 { deque.push(i, to: Pos.back) }
        for _ in 0..<5 { _ = deque.pop(from: Pos.front) }    // remaining: 5,6,7
        for i in 100..<104 { deque.push(i, to: Pos.back) }   // append 100..103, wraps

        var collected: [Int] = []
        deque.forEach { collected.append($0) }
        #expect(collected == [5, 6, 7, 100, 101, 102, 103])
    }

    /// Broadcast "Buffer trimming with slow subscriber" op-pattern: push to back,
    /// trim from front below a lagging cursor, scan with `first(where:)`/`contains`.
    @Test
    func `broadcast trim op-pattern does not trap`() {
        var buffer = Queue<(index: UInt64, element: Int)>.DoubleEnded()
        let bufferLimit = 10
        let elementCount = 100
        var slowCursor: UInt64 = 0
        var nextIndex: UInt64 = 0
        typealias EPos = Queue<(index: UInt64, element: Int)>.DoubleEnded.Position

        for _ in 0..<elementCount {
            let index = nextIndex
            nextIndex += 1
            buffer.push((index: index, element: Int(index)), to: EPos.back)

            let minCursor = slowCursor
            while Int(bitPattern: buffer.count) > bufferLimit {
                if let front = buffer.peek(at: EPos.front, { $0.index }), front < minCursor {
                    _ = buffer.take(from: EPos.front)
                } else {
                    break
                }
            }
            if index % 3 == 0, buffer.first(where: { $0.index == slowCursor }) != nil {
                slowCursor += 1
            }
            _ = buffer.contains { $0.index >= slowCursor }
        }
        // Survival is the assertion (the pattern previously trapped).
        #expect(Int(bitPattern: buffer.count) >= 0)
    }

    /// Broadcast "Many subscribers with interleaved send and cancel" op-pattern:
    /// cursor-driven front-trim with no fixed limit, repeated `first(where:)` /
    /// `contains` scans over a ring whose head wraps as elements are pushed.
    @Test
    func `broadcast interleave op-pattern does not trap`() {
        var buffer = Queue<(index: UInt64, element: Int)>.DoubleEnded()
        let elementCount = 500
        var nextIndex: UInt64 = 0
        var minCursor: UInt64 = 0
        typealias EPos = Queue<(index: UInt64, element: Int)>.DoubleEnded.Position

        for i in 0..<elementCount {
            let index = nextIndex
            nextIndex += 1
            buffer.push((index: index, element: Int(index)), to: EPos.back)

            if i % 7 == 0 { minCursor += 3 }
            while let front = buffer.peek(at: EPos.front, { $0.index }), front < minCursor {
                _ = buffer.take(from: EPos.front)
            }
            for probe in [minCursor, minCursor + 1, minCursor + 10] {
                _ = buffer.first(where: { $0.index == probe })
            }
            _ = buffer.contains { $0.index >= minCursor }
        }
        #expect(Int(bitPattern: buffer.count) >= 0)
    }
}
