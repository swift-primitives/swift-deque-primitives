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
@testable import Deque_Primitives

/// Tests verifying conditional Copyable conformance.
/// - Deque<Copyable> is Copyable
/// - Deque<~Copyable> is ~Copyable
/// - Deque.Inline and Deque.Small are unconditionally ~Copyable
/// Migrated from: Experiments/deque-conditional-copyable
@Suite("Deque - Conditional Copyable")
struct DequeConditionalCopyableTests {

    struct MoveOnly: ~Copyable {
        let id: Int
    }

    @Test("Deque<Int> is Copyable")
    func dequeIntIsCopyable() {
        let original: Deque<Int> = [1, 2, 3]
        let copy = original  // Copy, not move

        let origCount = original.count
        let copyCount = copy.count
        #expect(origCount == 3)
        #expect(copyCount == 3)
        #expect(Swift.Array(original) == Swift.Array(copy))
    }

    @Test("Deque.Bounded<Int> is Copyable")
    func boundedIntIsCopyable() throws {
        var original = try Deque<Int>.Bounded(capacity: 10)
        try original.push(1, to: .back)
        try original.push(2, to: .back)

        let copy = original  // Copy, not move

        let origCount = original.count
        let copyCount = copy.count
        let origCap = original.capacity
        let copyCap = copy.capacity
        #expect(origCount == 2)
        #expect(copyCount == 2)
        #expect(origCap == copyCap)
    }

    @Test("Deque<MoveOnly> is ~Copyable")
    func dequeMoveOnlyIsNotCopyable() {
        var deque = Deque<MoveOnly>()
        deque.push(MoveOnly(id: 1), to: .back)

        // Can only move, not copy
        let moved = consume deque
        let count = moved.count
        #expect(count == 1)
    }

    @Test("Deque.Inline<Int> is unconditionally ~Copyable")
    func inlineIsUnconditionallyNonCopyable() throws {
        var inline = Deque<Int>.Inline<4>()
        try inline.push(1, to: .back)
        try inline.push(2, to: .back)

        // Even with Copyable Int, Inline requires consume
        let moved = consume inline
        let count = moved.count
        #expect(count == 2)
    }

    @Test("Deque.Small<Int> is unconditionally ~Copyable")
    func smallIsUnconditionallyNonCopyable() {
        var small = Deque<Int>.Small<4>()
        small.push(1, to: .back)
        small.push(2, to: .back)

        // Even with Copyable Int, Small requires consume
        let moved = consume small
        let count = moved.count
        #expect(count == 2)
    }
}
