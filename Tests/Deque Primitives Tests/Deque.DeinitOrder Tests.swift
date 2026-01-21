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
import Synchronization
@testable import Deque_Primitives

/// Tests verifying deinit order (front-to-back) for all Deque variants.
/// Migrated from: Experiments/deque-deinit-order
@Suite("Deque - Deinit Order")
struct DequeDeinitOrderTests {

    /// Thread-safe tracker for deinit order
    final class Tracker: Sendable {
        private let _deinitOrder = Mutex<[Int]>([])
        var deinitOrder: [Int] { _deinitOrder.withLock { $0 } }
        func reset() { _deinitOrder.withLock { $0 = [] } }
        func append(_ id: Int) { _deinitOrder.withLock { $0.append(id) } }
    }

    /// Element that tracks its deinit
    struct TrackedElement: ~Copyable {
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

    @Test("Deque deinit order (simple)")
    func dequeDeinitSimple() {
        let tracker = Tracker()
        do {
            var deque = Deque<TrackedElement>()
            deque.push(TrackedElement(1, tracker: tracker), to: .back)
            deque.push(TrackedElement(2, tracker: tracker), to: .back)
            deque.push(TrackedElement(3, tracker: tracker), to: .back)
        }
        #expect(tracker.deinitOrder == [1, 2, 3])
    }

    @Test("Deque deinit order (with front pushes)")
    func dequeDeinitWithFrontPushes() {
        let tracker = Tracker()
        do {
            var deque = Deque<TrackedElement>()
            deque.push(TrackedElement(2, tracker: tracker), to: .back)
            deque.push(TrackedElement(1, tracker: tracker), to: .front)
            deque.push(TrackedElement(3, tracker: tracker), to: .back)
            // Logical order: [1, 2, 3]
        }
        #expect(tracker.deinitOrder == [1, 2, 3])
    }

    @Test("Deque deinit order (ring buffer wraparound)")
    func dequeDeinitWraparound() {
        let tracker = Tracker()
        do {
            var deque = Deque<TrackedElement>()
            // Fill and pop to create wraparound
            for i in 1...10 {
                deque.push(TrackedElement(i, tracker: tracker), to: .back)
            }
            // Pop some from front to shift head
            for _ in 1...5 {
                _ = deque.pop(from: .front)
            }
            // Now add more to wrap around
            for i in 11...15 {
                deque.push(TrackedElement(i, tracker: tracker), to: .back)
            }
            // Logical order should be: [6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
            tracker.reset()
        }
        #expect(tracker.deinitOrder == [6, 7, 8, 9, 10, 11, 12, 13, 14, 15])
    }

    @Test("Deque.Bounded deinit order")
    func boundedDeinitOrder() throws {
        let tracker = Tracker()
        do {
            var bounded = try Deque<TrackedElement>.Bounded(capacity: 5)
            try bounded.push(TrackedElement(1, tracker: tracker), to: .back)
            try bounded.push(TrackedElement(2, tracker: tracker), to: .back)
            try bounded.push(TrackedElement(0, tracker: tracker), to: .front)
            // Logical order: [0, 1, 2]
        }
        #expect(tracker.deinitOrder == [0, 1, 2])
    }

    @Test("Deque.Inline deinit order")
    func inlineDeinitOrder() throws {
        let tracker = Tracker()
        do {
            var inline = Deque<TrackedElement>.Inline<4>()
            try inline.push(TrackedElement(1, tracker: tracker), to: .back)
            try inline.push(TrackedElement(2, tracker: tracker), to: .back)
            try inline.push(TrackedElement(0, tracker: tracker), to: .front)
            // Logical order: [0, 1, 2]
        }
        #expect(tracker.deinitOrder == [0, 1, 2])
    }

    @Test("Deque.Small deinit order (inline path)")
    func smallInlineDeinitOrder() {
        let tracker = Tracker()
        do {
            var small = Deque<TrackedElement>.Small<4>()
            small.push(TrackedElement(1, tracker: tracker), to: .back)
            small.push(TrackedElement(2, tracker: tracker), to: .back)
        }
        #expect(tracker.deinitOrder == [1, 2])
    }

    @Test("Deque.Small deinit order (spilled path)")
    func smallSpilledDeinitOrder() {
        let tracker = Tracker()
        do {
            var small = Deque<TrackedElement>.Small<2>()
            small.push(TrackedElement(1, tracker: tracker), to: .back)
            small.push(TrackedElement(2, tracker: tracker), to: .back)
            small.push(TrackedElement(3, tracker: tracker), to: .back)  // Triggers spill
        }
        #expect(tracker.deinitOrder == [1, 2, 3])
    }

    @Test("Empty deque deinit (no crash)")
    func emptyDeinitNoCrash() throws {
        let tracker = Tracker()
        do {
            let _: Deque<TrackedElement> = Deque()
            let _: Deque<TrackedElement>.Bounded = try Deque<TrackedElement>.Bounded(capacity: 5)
            let _: Deque<TrackedElement>.Inline<4> = Deque<TrackedElement>.Inline<4>()
            let _: Deque<TrackedElement>.Small<4> = Deque<TrackedElement>.Small<4>()
        }
        #expect(tracker.deinitOrder == [])
    }
}
