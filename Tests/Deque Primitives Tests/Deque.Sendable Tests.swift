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

/// Tests verifying Sendable conformance when Element: Sendable.
/// Migrated from: Experiments/deque-sendable-conformance
@Suite("Deque - Sendable Conformance")
struct DequeSendableTests {

    /// Compile-time check: value conforms to Sendable
    func requireSendable<T: Sendable>(_ value: T) {
        // Compile-time verification only
    }

    /// Compile-time check: ~Copyable value conforms to Sendable
    func requireSendableNC<T: Sendable & ~Copyable>(_ value: borrowing T) {
        // Compile-time verification only
    }

    @Test("Deque<Int> is Sendable")
    func dequeIntIsSendable() {
        let deque: Deque<Int> = [1, 2, 3]
        requireSendable(deque)
    }

    @Test("Deque<String> is Sendable")
    func dequeStringIsSendable() {
        let deque: Deque<String> = ["a", "b", "c"]
        requireSendable(deque)
    }

    @Test("Deque.Bounded<Int> is Sendable")
    func boundedIntIsSendable() throws {
        var bounded = try Deque<Int>.Bounded(capacity: 10)
        try bounded.push(1, to: .back)
        requireSendable(bounded)
    }

    @Test("Deque.Inline<Int> is Sendable")
    func inlineIntIsSendable() throws {
        var inline = Deque<Int>.Inline<4>()
        try inline.push(1, to: .back)
        requireSendableNC(inline)
    }

    @Test("Deque.Small<Int> is Sendable")
    func smallIntIsSendable() {
        var small = Deque<Int>.Small<4>()
        small.push(1, to: .back)
        requireSendableNC(small)
    }

    @Test("Deque.Iterator is Sendable")
    func iteratorIsSendable() {
        let deque: Deque<Int> = [1, 2, 3]
        var iterator = deque.makeIterator()
        requireSendable(iterator)
        _ = iterator.next()
    }

    @Test("Async task transfer")
    func asyncTaskTransfer() async {
        @Sendable
        func processInBackground(_ deque: Deque<Int>) async -> Int {
            var sum = 0
            for element in deque {
                sum += element
            }
            return sum
        }

        let deque: Deque<Int> = [1, 2, 3, 4, 5]

        let task = Task {
            await processInBackground(deque)
        }

        let result = await task.value
        #expect(result == 15)
    }
}
