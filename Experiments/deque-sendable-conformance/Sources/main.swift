// MARK: - Claim Verification: CLAIM-006
// Source: Deque.swift:1046-1058
// Claim: "Deque is Sendable when Element is Sendable"
//
// Verification method: Compile-time conformance check + async usage
// Hypothesis: Deque<Sendable> can be passed across isolation boundaries
//
// Toolchain: swift-6.2-RELEASE
// Result: CONFIRMED - All types are Sendable when Element: Sendable
// Date: 2026-01-20
//
// Evidence:
// - Deque<Int> is Sendable (compile-time + async transfer)
// - Deque<String> is Sendable
// - Deque.Bounded<Int> is Sendable
// - Deque.Inline<Int> is Sendable (with ~Copyable)
// - Deque.Small<Int> is Sendable (with ~Copyable)
// - Deque.Iterator is Sendable
// - Async task sum: 15 (correct)

import Deque_Primitives

// --- Helper to verify Sendable (Copyable types) ---
func requireSendable<T: Sendable>(_ value: T) {
    print("  \(type(of: value)) is Sendable")
}

// --- Helper to verify Sendable (~Copyable types) ---
func requireSendableNC<T: Sendable & ~Copyable>(_ value: borrowing T) {
    print("  \(type(of: value)) is Sendable (~Copyable)")
}

// --- Non-Sendable type ---
class NonSendable {
    var value: Int
    init(_ value: Int) { self.value = value }
}

print("=== Test 1: Deque<Int> should be Sendable ===")
do {
    let deque: Deque<Int> = [1, 2, 3]
    requireSendable(deque)  // Should compile
    print("  Test 1: PASSED")
}

print("\n=== Test 2: Deque<String> should be Sendable ===")
do {
    let deque: Deque<String> = ["a", "b", "c"]
    requireSendable(deque)  // Should compile
    print("  Test 2: PASSED")
}

print("\n=== Test 3: Deque.Bounded<Int> should be Sendable ===")
do {
    var bounded = try! Deque<Int>.Bounded(capacity: 10)
    try! bounded.push(1, to: .back)
    requireSendable(bounded)  // Should compile
    print("  Test 3: PASSED")
}

print("\n=== Test 4: Deque.Inline<Int> should be Sendable ===")
do {
    var inline = Deque<Int>.Inline<4>()
    try! inline.push(1, to: .back)
    requireSendableNC(inline)  // Use ~Copyable-aware helper
    print("  Test 4: PASSED")
}

print("\n=== Test 5: Deque.Small<Int> should be Sendable ===")
do {
    var small = Deque<Int>.Small<4>()
    small.push(1, to: .back)
    requireSendableNC(small)  // Use ~Copyable-aware helper
    print("  Test 5: PASSED")
}

print("\n=== Test 6: Deque.Iterator should be Sendable ===")
do {
    let deque: Deque<Int> = [1, 2, 3]
    var iterator = deque.makeIterator()
    requireSendable(iterator)  // Should compile
    _ = iterator.next()  // Use it
    print("  Test 6: PASSED")
}

print("\n=== Test 7: Async task transfer (runtime verification) ===")
// This test verifies that Deque can actually be used across isolation boundaries

@Sendable
func processInBackground(_ deque: Deque<Int>) async -> Int {
    var sum = 0
    for element in deque {
        sum += element
    }
    return sum
}

do {
    let deque: Deque<Int> = [1, 2, 3, 4, 5]

    // Create a task that receives the deque
    let task = Task {
        await processInBackground(deque)
    }

    let result = await task.value
    print("  Sum computed in background: \(result)")
    print("  Expected: 15")
    print("  Test 7: \(result == 15 ? "PASSED" : "FAILED")")
}

// Note: Deque<NonSendable> would NOT be Sendable
// This would fail to compile:
// func testNonSendable() {
//     let deque = Deque<NonSendable>()
//     requireSendable(deque)  // ERROR: Type 'Deque<NonSendable>' does not conform to 'Sendable'
// }

print("\n=== All Sendable conformance tests completed ===")
