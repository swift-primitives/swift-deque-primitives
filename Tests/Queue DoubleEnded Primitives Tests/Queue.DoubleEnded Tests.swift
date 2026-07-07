import Buffer_Primitive
import Buffer_Primitives_Test_Support
import Buffer_Ring_Bounded_Primitive
import Buffer_Ring_Primitive
import Buffer_Ring_Primitives
import Deque_Primitives
import Index_Primitives
import Memory_Allocator_Primitive
import Memory_Heap_Primitives
import Ordinal_Primitives_Standard_Library_Integration
import Ownership_Shared_Primitive
import Queue_Primitive
import Storage_Contiguous_Primitives
import Tagged_Primitives_Standard_Library_Integration
import Testing

// The column-keyed deque suite over the same four ring columns as the queue.

private typealias HeapStorage<E: ~Copyable> =
    Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>

private typealias GrowableRing<E: ~Copyable> = Buffer<HeapStorage<E>>.Ring
private typealias BoundedRing<E: ~Copyable> = Buffer<HeapStorage<E>>.Ring.Bounded

private typealias MoveDeque<E: ~Copyable> = Deque<GrowableRing<E>>
private typealias CoWDeque<E: ~Copyable> = Deque<Ownership.Shared<E, GrowableRing<E>>>
private typealias FixedDeque<E: ~Copyable> = Deque<BoundedRing<E>>

// MARK: - [DS-024]: the columns are lawful from the deque family's own suite

@Suite
struct DequeColumnLawTests {

    @Test
    func `the direct growable-ring column obeys the seam ledger laws`() {
        let violations = Seam.Ledger.violations(
            makeEmpty: { GrowableRing<Int>(minimumCapacity: Index<Int>.Count(4)) },
            element: { $0 }
        )
        #expect(violations.isEmpty, "\(violations)")
    }

    @Test
    func `the direct bounded-ring column obeys the seam ledger laws`() {
        let violations = Seam.Ledger.violations(
            makeEmpty: { BoundedRing<Int>(minimumCapacity: Index<Int>.Count(4)) },
            element: { $0 }
        )
        #expect(violations.isEmpty, "\(violations)")
    }

    @Test
    func `the shared growable-ring column obeys the seam ledger laws`() {
        let violations = Seam.Ledger.violations(
            makeEmpty: { Ownership.Shared(GrowableRing<Int>(minimumCapacity: Index<Int>.Count(4))) },
            element: { $0 }
        )
        #expect(violations.isEmpty, "\(violations)")
    }

    @Test
    func `the shared bounded-ring column obeys the seam ledger laws`() {
        let violations = Seam.Ledger.violations(
            makeEmpty: { Ownership.Shared(BoundedRing<Int>(minimumCapacity: Index<Int>.Count(4))) },
            element: { $0 }
        )
        #expect(violations.isEmpty, "\(violations)")
    }
}

@Suite(.serialized)
struct DequeCoreTests {

    @Test
    func `pushes and pops at both ends; wrap-safe order`() {
        var d = MoveDeque<Int>(minimumCapacity: 4)
        d.push(2, to: .back)
        d.push(1, to: .front)  // head retreats (wraps physically)
        d.push(3, to: .back)
        let n = d.count
        #expect(n == Index<Int>.Count(3))
        let front = d.pop(from: .front)
        #expect(front == 1)
        let back = d.pop(from: .back)
        #expect(back == 3)
        let mid = d.pop(from: .front)
        #expect(mid == 2)
        let empty = d.pop(from: .back)
        #expect(empty == nil)
    }

    @Test
    func `peek at both ends; take aliases pop; forEach walks front-to-back`() {
        var d = MoveDeque<Int>(minimumCapacity: 4)
        d.push(10, to: .back)
        d.push(20, to: .back)
        d.push(5, to: .front)
        let f = d.peek(at: .front)
        #expect(f == 5)
        let b = d.peek(at: .back)
        #expect(b == 20)
        let doubled = d.peek(at: .front) { $0 * 2 }
        #expect(doubled == 10)
        var walked: [Int] = []
        d.forEach { walked.append($0) }
        #expect(walked == [5, 10, 20])
        let taken = d.take(from: .back)
        #expect(taken == 20)
        var seen: [Int] = []
        d.drain { seen.append($0) }
        #expect(seen == [5, 10])
    }

    @Test
    func `the bounded column carries the fixed contract at both ends`() throws {
        var d = FixedDeque<Int>(capacity: 2)
        try d.push(1, to: .back)
        try d.push(0, to: .front)
        var thrown = false
        do {
            try d.push(9, to: .back)
        } catch {
            thrown = true
        }
        #expect(thrown)
        let front = d.pop(from: .front)
        #expect(front == 0)
        try d.push(2, to: .back)
        var seen: [Int] = []
        d.drain { seen.append($0) }
        #expect(seen == [1, 2])
    }

    @Test
    func `clear and reserve reshape; clone detaches the direct column`() {
        var d = MoveDeque<Int>(minimumCapacity: 2)
        d.push(1, to: .back)
        d.reserve(Index<Int>.Count(8))
        let grown = d.capacity >= Index<Int>.Count(8)
        #expect(grown)
        var c = d.clone()
        _ = c.pop(from: .front)
        let mine = d.count
        let theirs = c.count
        #expect(mine == Index<Int>.Count(1))
        #expect(theirs == Index<Int>.Count(0))
        d.clear(keepingCapacity: true)
        let isEmpty = d.isEmpty
        #expect(isEmpty)
    }
}

@Suite(.serialized)
struct DequeCoWTests {

    @Test
    func `pushes at both ends detach from siblings through the box`() {
        var d1 = CoWDeque<Int>(minimumCapacity: 4)
        d1.push(2, to: .back)
        let d2 = d1
        d1.push(1, to: .front)  // withUnique(consuming:) detaches first
        let mine = d1.count
        let theirs = d2.count
        #expect(mine == Index<Int>.Count(2))
        #expect(theirs == Index<Int>.Count(1))
        let myFront = d1.peek(at: .front)
        #expect(myFront == 1)
        let theirFront = d2.peek(at: .front)
        #expect(theirFront == 2)
    }

    @Test
    func `pops detach; generic clone always detaches; carriers chain via S5`() {
        var d1 = CoWDeque<Int>(minimumCapacity: 4)
        d1.push(1, to: .back)
        d1.push(2, to: .back)
        let d2 = d1
        let popped = d1.pop(from: .back)
        #expect(popped == 2)
        let theirs = d2.count
        #expect(theirs == Index<Int>.Count(2))

        var x = CoWDeque<Int>(minimumCapacity: 2)
        x.push(1, to: .back)
        var y = CoWDeque<Int>(minimumCapacity: 8)
        y.push(1, to: .back)
        #expect(x == y)
        y.push(2, to: .back)
        #expect(x != y)

        var c = x.clone()
        _ = c.pop(from: .front)
        let xCount = x.count
        #expect(xCount == Index<Int>.Count(1))
    }
}

@Suite(.serialized)
struct DequeTeardownTests {

    @Test
    func `move-only elements at both ends tear down exactly once`() {
        DequeProbe.reset()
        do {
            var d = MoveDeque<DequeItem>(minimumCapacity: 4)
            d.push(DequeItem(2), to: .back)
            d.push(DequeItem(1), to: .front)  // wrapped two-run state
            d.push(DequeItem(3), to: .back)
            if let front = d.pop(from: .front) {
                let id = front.id
                #expect(id == 1)
            } else {
                Issue.record("expected the front element")
            }
            let mid = DequeProbe.destroyedSorted
            #expect(mid == [1])
        }
        let all = DequeProbe.destroyedSorted
        #expect(all == [1, 2, 3])
    }

    @Test
    func `the boxed lane tears down via the box drain`() {
        DequeProbe2.reset()
        do {
            var d = Deque<Ownership.Shared<DequeItem2, GrowableRing<DequeItem2>>>(minimumCapacity: 2)
            d.push(DequeItem2(7), to: .back)
            d.push(DequeItem2(8), to: .front)
            let n = d.count
            #expect(n == Index<DequeItem2>.Count(2))
        }
        let all = DequeProbe2.destroyedSorted
        #expect(all == [7, 8])
    }
}

private struct DequeItem: ~Copyable {
    let id: Int
    init(_ id: Int) { self.id = id }
    deinit { DequeProbe.recordDestroy(id) }
}

private enum DequeProbe {
    nonisolated(unsafe) static var _destroyed: [Int] = []
    static func reset() { unsafe _destroyed = [] }
    static func recordDestroy(_ id: Int) { unsafe _destroyed.append(id) }
    static var destroyedSorted: [Int] { unsafe _destroyed.sorted() }
}

private struct DequeItem2: ~Copyable {
    let id: Int
    init(_ id: Int) { self.id = id }
    deinit { DequeProbe2.recordDestroy(id) }
}

private enum DequeProbe2 {
    nonisolated(unsafe) static var _destroyed: [Int] = []
    static func reset() { unsafe _destroyed = [] }
    static func recordDestroy(_ id: Int) { unsafe _destroyed.append(id) }
    static var destroyedSorted: [Int] { unsafe _destroyed.sorted() }
}

@Suite
struct DequeSendableTests {

    @Test
    func `sendable composes through the columns`() {
        let a = MoveDeque<Int>(minimumCapacity: 1)
        requireSendable(a)
        let b = CoWDeque<Int>(minimumCapacity: 1)
        requireSendable(b)
        #expect(Bool(true))
    }
}

private func requireSendable<T: Sendable & ~Copyable>(_ value: borrowing T) {}
