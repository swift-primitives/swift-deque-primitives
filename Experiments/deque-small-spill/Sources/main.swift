// MARK: - Claim Verification: CLAIM-009 + ASSUMP-004
// Source: Deque.swift:319-464 (Deque.Small)
// Claim: "Inline storage with automatic spill to heap when exceeded"
// Assumption: "Spill operation correctly moves all elements to heap"
//
// Verification method: Runtime behavior test
// Hypothesis: Deque.Small stores elements inline until capacity exceeded,
//             then correctly moves all elements to heap storage
//
// Toolchain: swift-6.2-RELEASE
// Result: CONFIRMED - All Small spill behaviors work correctly
// Date: 2026-01-20
//
// Evidence:
// - Stays inline under capacity: PASSED
// - Spills when exceeding capacity: PASSED
// - Preserves ring buffer order on spill: PASSED (elements [1,2,3,4,5])
// - ~Copyable elements spill correctly: PASSED (deinit count: 3)
// - Operations work after spill: PASSED (push/pop/peek)
// - Clear does not shrink to inline: PASSED (documented behavior)
// - Capacity reflects storage: PASSED (4 -> 9 after spill)

import Deque_Primitives

// --- Observable element for tracking ---
final class SpillTracker: @unchecked Sendable {
    nonisolated(unsafe) static var moveCount = 0
    nonisolated(unsafe) static var deinitCount = 0
    static func reset() {
        moveCount = 0
        deinitCount = 0
    }
}

struct TrackedValue: ~Copyable {
    let id: Int
    init(_ id: Int) {
        self.id = id
    }
    deinit {
        SpillTracker.deinitCount += 1
    }
}

print("=== Test 1: Small stays inline under capacity ===")
do {
    var small = Deque<Int>.Small<4>()
    small.push(1, to: .back)
    small.push(2, to: .back)
    small.push(3, to: .back)

    print("  Count: \(small.count)")  // Expected: 3
    print("  isSpilled: \(small.isSpilled)")  // Expected: false
    print("  Test 1: \(small.count == 3 && !small.isSpilled ? "PASSED" : "FAILED")")
}

print("\n=== Test 2: Small spills when exceeding capacity ===")
do {
    var small = Deque<Int>.Small<4>()
    for i in 1...4 {
        small.push(i, to: .back)
    }
    print("  At capacity - isSpilled: \(small.isSpilled)")  // Expected: false

    small.push(5, to: .back)  // Triggers spill
    print("  After overflow - isSpilled: \(small.isSpilled)")  // Expected: true
    print("  Count: \(small.count)")  // Expected: 5

    // Verify elements are preserved
    var elements: [Int] = []
    small.forEach { elements.append($0) }
    print("  Elements: \(elements)")  // Expected: [1, 2, 3, 4, 5]

    print("  Test 2: \(small.isSpilled && elements == [1, 2, 3, 4, 5] ? "PASSED" : "FAILED")")
}

print("\n=== Test 3: Small spill preserves ring buffer order ===")
do {
    var small = Deque<Int>.Small<4>()

    // Create ring buffer wraparound scenario
    small.push(1, to: .back)
    small.push(2, to: .back)
    small.push(0, to: .front)  // Now [0, 1, 2] with head shifted

    _ = small.pop(from: .front)  // Remove 0, now [1, 2]
    small.push(3, to: .back)  // [1, 2, 3]
    small.push(4, to: .back)  // [1, 2, 3, 4] - at capacity

    print("  Before spill - isSpilled: \(small.isSpilled)")

    // This push should trigger spill and preserve order
    small.push(5, to: .back)

    print("  After spill - isSpilled: \(small.isSpilled)")

    var elements: [Int] = []
    small.forEach { elements.append($0) }
    print("  Elements after spill: \(elements)")  // Expected: [1, 2, 3, 4, 5]

    print("  Test 3: \(elements == [1, 2, 3, 4, 5] ? "PASSED" : "FAILED")")
}

print("\n=== Test 4: Small with ~Copyable elements spills correctly ===")
SpillTracker.reset()
do {
    var small = Deque<TrackedValue>.Small<2>()
    small.push(TrackedValue(1), to: .back)
    small.push(TrackedValue(2), to: .back)

    print("  Before spill - isSpilled: \(small.isSpilled)")  // false

    small.push(TrackedValue(3), to: .back)  // Triggers spill

    print("  After spill - isSpilled: \(small.isSpilled)")  // true
    print("  Count: \(small.count)")  // 3

    // Verify elements are accessible
    var ids: [Int] = []
    small.forEach { ids.append($0.id) }
    print("  Element IDs: \(ids)")  // Expected: [1, 2, 3]

    print("  Test 4: \(small.isSpilled && ids == [1, 2, 3] ? "PASSED" : "FAILED")")
}
print("  Deinit count after scope: \(SpillTracker.deinitCount)")  // Expected: 3

print("\n=== Test 5: Small operations work after spill ===")
do {
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

    print("  Popped back: \(back ?? -1)")  // Expected: 3
    print("  Peek front: \(front ?? -1)")  // Expected: 0
    print("  Remaining: \(elements)")  // Expected: [0, 1, 2]

    let passed = back == 3 && front == 0 && elements == [0, 1, 2]
    print("  Test 5: \(passed ? "PASSED" : "FAILED")")
}

print("\n=== Test 6: Small clear does not shrink back to inline ===")
do {
    var small = Deque<Int>.Small<2>()
    small.push(1, to: .back)
    small.push(2, to: .back)
    small.push(3, to: .back)  // Spills

    print("  isSpilled before clear: \(small.isSpilled)")  // true

    small.clear()

    print("  isSpilled after clear: \(small.isSpilled)")  // Still true (documented behavior)
    print("  isEmpty after clear: \(small.isEmpty)")  // true

    // Can still push after clear
    small.push(10, to: .back)
    print("  Count after push: \(small.count)")  // 1

    print("  Test 6: \(small.isSpilled && small.count == 1 ? "PASSED" : "FAILED")")
}

print("\n=== Test 7: Small capacity reflects current storage ===")
do {
    var small = Deque<Int>.Small<4>()
    print("  Initial capacity (inline): \(small.capacity)")  // 4

    for i in 1...5 {
        small.push(i, to: .back)
    }

    print("  Capacity after spill: \(small.capacity)")  // >= 5 (heap capacity)
    print("  Test 7: \(small.capacity >= 5 ? "PASSED" : "FAILED")")
}

print("\n=== All Small spill tests completed ===")
