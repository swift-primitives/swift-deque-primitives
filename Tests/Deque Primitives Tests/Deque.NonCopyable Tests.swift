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

/// Tests verifying ~Copyable element support across all Deque variants.
/// Migrated from: Experiments/deque-noncopyable-elements
@Suite("Deque - NonCopyable Elements")
struct DequeNonCopyableTests {

    /// A ~Copyable test type with observable deinit
    struct Token: ~Copyable {
        let id: Int
        let onDeinit: @Sendable (Int) -> Void

        init(_ id: Int, onDeinit: @escaping @Sendable (Int) -> Void = { _ in }) {
            self.id = id
            self.onDeinit = onDeinit
        }

        deinit {
            onDeinit(id)
        }
    }

    @Test("Deque with ~Copyable elements: push/pop/peek")
    func dequeWithNonCopyable() {
        var deque = Deque<Token>()
        deque.push(Token(1), to: .back)
        deque.push(Token(2), to: .back)
        deque.push(Token(0), to: .front)

        let count = deque.count
        #expect(count == 3)

        // Peek via closure (borrowing)
        var peekedId: Int?
        deque.peek(at: .front) { token in
            peekedId = token.id
        }
        #expect(peekedId == 0)

        // Pop
        if let token = deque.pop(from: .front) {
            #expect(token.id == 0)
        } else {
            Issue.record("Expected to pop token")
        }

        let countAfter = deque.count
        #expect(countAfter == 2)
    }

    @Test("Deque with ~Copyable elements: forEach iteration")
    func dequeForEach() {
        var deque = Deque<Token>()
        deque.push(Token(1), to: .back)
        deque.push(Token(2), to: .back)
        deque.push(Token(3), to: .back)

        var ids: [Int] = []
        deque.forEach { token in
            ids.append(token.id)
        }

        #expect(ids == [1, 2, 3])
    }

    @Test("Deque.Bounded with ~Copyable elements")
    func boundedWithNonCopyable() throws {
        var bounded = try Deque<Token>.Bounded(capacity: 5)
        try bounded.push(Token(10), to: .back)
        try bounded.push(Token(20), to: .back)

        let count = bounded.count
        let capacity = bounded.capacity
        #expect(count == 2)
        #expect(capacity == 5)

        if let token = bounded.pop(from: .back) {
            #expect(token.id == 20)
        } else {
            Issue.record("Expected to pop token")
        }
    }

    @Test("Deque.Inline with ~Copyable elements")
    func inlineWithNonCopyable() throws {
        var inline = Deque<Token>.Inline<4>()
        try inline.push(Token(100), to: .back)
        try inline.push(Token(200), to: .front)

        let count = inline.count
        let isFull = inline.isFull
        #expect(count == 2)
        #expect(!isFull)

        if let token = inline.pop(from: .front) {
            #expect(token.id == 200)
        } else {
            Issue.record("Expected to pop token")
        }
    }

    @Test("Deque.Small with ~Copyable elements (inline path)")
    func smallInlineWithNonCopyable() {
        var small = Deque<Token>.Small<4>()
        small.push(Token(1), to: .back)
        small.push(Token(2), to: .back)

        let count = small.count
        let isSpilled = small.isSpilled
        #expect(count == 2)
        #expect(!isSpilled)
    }

    @Test("Deque.Small with ~Copyable elements (spill path)")
    func smallSpillWithNonCopyable() {
        var small = Deque<Token>.Small<2>()
        small.push(Token(1000), to: .back)
        small.push(Token(2000), to: .back)
        let notSpilled = !small.isSpilled
        #expect(notSpilled)

        small.push(Token(3000), to: .back)
        let isSpilled = small.isSpilled
        let count = small.count
        #expect(isSpilled)
        #expect(count == 3)

        if let token = small.pop(from: .front) {
            #expect(token.id == 1000)
        } else {
            Issue.record("Expected to pop token")
        }
    }
}
