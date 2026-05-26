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

@Suite("Queue.DoubleEnded - drain(while:_:)")
struct QueueDoubleEndedDrainWhileTests {

    @Test
    func `DoubleEnded drains some elements front-to-back`() {
        var q = Queue<Int>.DoubleEnded()
        for e in [1, 2, 3, 4, 5] { q.push(e, to: .back) }
        var drained: [Int] = []
        q.drain(while: { $0 < 4 }) { drained.append($0) }
        #expect(drained == [1, 2, 3])
        #expect(Int(bitPattern: q.count) == 2)
    }

    @Test
    func `DoubleEnded.Fixed drains some elements`() throws {
        var q = Queue<Int>.DoubleEnded.Fixed(capacity: 10)
        for e in [1, 2, 3, 4, 5] { try q.push(e, to: .back) }
        var drained: [Int] = []
        q.drain(while: { $0 < 4 }) { drained.append($0) }
        #expect(drained == [1, 2, 3])
        #expect(Int(bitPattern: q.count) == 2)
    }
}
