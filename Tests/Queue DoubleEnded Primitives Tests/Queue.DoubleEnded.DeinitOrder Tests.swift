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

/// Tests verifying deinit order (FIFO: front-to-back) for Queue.DoubleEnded variants.
@Suite("Queue.DoubleEnded - Deinit Order")
struct QueueDoubleEndedDeinitOrderTests {

    /// Thread-safe tracker for deinit order.
    final class Tracker: @unchecked Sendable {
        private var _storage: [Int] = []
        var deinitOrder: [Int] {
            _storage
        }
        func reset() { _storage = [] }
        func append(_ id: Int) { _storage.append(id) }
    }

    /// Copyable element that tracks its deinit via reference counting.
    /// Used for Queue.DoubleEnded.Static which only has Copyable API.
    final class TrackedBox {
        let id: Int
        let tracker: Tracker

        init(_ id: Int, tracker: Tracker) {
            self.id = id
            self.tracker = tracker
        }

        deinit {
            tracker.append(id)
        }
    }

    @Test
    func `Queue.DoubleEnded.Static deinit order`() throws {
        let tracker = Tracker()
        do {
            var deque = Queue<TrackedBox>.DoubleEnded.Static<4>()
            try deque.push(TrackedBox(1, tracker: tracker), to: .back)
            try deque.push(TrackedBox(2, tracker: tracker), to: .back)
            try deque.push(TrackedBox(3, tracker: tracker), to: .back)
        }
        let order = tracker.deinitOrder
        #expect(order == [1, 2, 3])
    }

    @Test
    func `Queue.DoubleEnded.Static deinit order (with wraparound)`() throws {
        let tracker = Tracker()
        do {
            var deque = Queue<TrackedBox>.DoubleEnded.Static<4>()
            try deque.push(TrackedBox(1, tracker: tracker), to: .back)
            try deque.push(TrackedBox(2, tracker: tracker), to: .back)
            _ = deque.pop(from: .front)  // Remove and deinit 1
            try deque.push(TrackedBox(3, tracker: tracker), to: .back)
            try deque.push(TrackedBox(4, tracker: tracker), to: .back)
        }
        let order = tracker.deinitOrder
        #expect(order == [1, 2, 3, 4])
    }

    @Test
    func `Empty deque deinit (no crash)`() {
        let tracker = Tracker()
        do {
            let _: Queue<TrackedBox>.DoubleEnded.Static<4> = Queue<TrackedBox>.DoubleEnded.Static<4>()
        }
        let order = tracker.deinitOrder
        #expect(order == [])
    }
}
