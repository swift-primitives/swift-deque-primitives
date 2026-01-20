// MARK: - Assumption Verification: ASSUMP-005
// Source: Deque.swift Storage.deinit, Deque.Inline deinit, Deque.Small deinit
// Assumption: "deinit properly deinitializes all elements in ring buffer order"
//
// Verification method: Runtime behavior test with observable deinit
// Hypothesis: When deque goes out of scope, all elements are deinitialized
//             in logical order (front to back), handling ring buffer wraparound
//
// Toolchain: swift-6.2-RELEASE
// Result: MIXED - Most variants pass, Deque.Inline deinit order unexpected
// Date: 2026-01-20
//
// Evidence:
// - Deque: PASSED (deinit in front-to-back order)
// - Deque (wraparound): PASSED (ring buffer handled correctly)
// - Deque.Bounded: PASSED (deinit in front-to-back order)
// - Deque.Inline: FAILED (deinit order was empty - investigate)
// - Deque.Small (inline): PASSED
// - Deque.Small (spilled): PASSED
// - Empty deques: PASSED (no crash)
//
// NOTE: Deque.Inline test showed empty deinit order which is unexpected.
// This may indicate a deinit issue or test artifact. Requires investigation.

import Deque_Primitives

// --- Observable deinit type ---
final class Tracker: @unchecked Sendable {
    nonisolated(unsafe) static var deinitOrder: [Int] = []
    static func reset() { deinitOrder = [] }
}

struct TrackedElement: ~Copyable {
    let id: Int
    init(_ id: Int) {
        self.id = id
    }
    deinit {
        Tracker.deinitOrder.append(id)
    }
}

print("=== Test 1: Deque deinit order (simple) ===")
Tracker.reset()
do {
    var deque = Deque<TrackedElement>()
    deque.push(TrackedElement(1), to: .back)
    deque.push(TrackedElement(2), to: .back)
    deque.push(TrackedElement(3), to: .back)
    // Logical order: [1, 2, 3]
}
print("  Deinit order: \(Tracker.deinitOrder)")
print("  Expected: [1, 2, 3] (front to back)")
print("  Test 1: \(Tracker.deinitOrder == [1, 2, 3] ? "PASSED" : "FAILED")")

print("\n=== Test 2: Deque deinit order (with front pushes) ===")
Tracker.reset()
do {
    var deque = Deque<TrackedElement>()
    deque.push(TrackedElement(2), to: .back)
    deque.push(TrackedElement(1), to: .front)  // Now front
    deque.push(TrackedElement(3), to: .back)
    // Logical order: [1, 2, 3]
}
print("  Deinit order: \(Tracker.deinitOrder)")
print("  Expected: [1, 2, 3] (front to back)")
print("  Test 2: \(Tracker.deinitOrder == [1, 2, 3] ? "PASSED" : "FAILED")")

print("\n=== Test 3: Deque deinit order (ring buffer wraparound) ===")
Tracker.reset()
do {
    var deque = Deque<TrackedElement>()
    // Fill and pop to create wraparound
    for i in 1...10 {
        deque.push(TrackedElement(i), to: .back)
    }
    // Pop some from front to shift head
    for _ in 1...5 {
        _ = deque.pop(from: .front)
    }
    // Now add more to wrap around
    for i in 11...15 {
        deque.push(TrackedElement(i), to: .back)
    }
    // Logical order should be: [6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
    Tracker.reset()  // Reset to only capture final deinit
}
print("  Deinit order: \(Tracker.deinitOrder)")
print("  Expected: [6, 7, 8, 9, 10, 11, 12, 13, 14, 15] (front to back)")
print("  Test 3: \(Tracker.deinitOrder == [6, 7, 8, 9, 10, 11, 12, 13, 14, 15] ? "PASSED" : "FAILED")")

print("\n=== Test 4: Deque.Bounded deinit order ===")
Tracker.reset()
do {
    var bounded = try! Deque<TrackedElement>.Bounded(capacity: 5)
    try! bounded.push(TrackedElement(1), to: .back)
    try! bounded.push(TrackedElement(2), to: .back)
    try! bounded.push(TrackedElement(0), to: .front)
    // Logical order: [0, 1, 2]
}
print("  Deinit order: \(Tracker.deinitOrder)")
print("  Expected: [0, 1, 2] (front to back)")
print("  Test 4: \(Tracker.deinitOrder == [0, 1, 2] ? "PASSED" : "FAILED")")

print("\n=== Test 5: Deque.Inline deinit order ===")
Tracker.reset()
do {
    var inline = Deque<TrackedElement>.Inline<4>()
    try! inline.push(TrackedElement(1), to: .back)
    try! inline.push(TrackedElement(2), to: .back)
    try! inline.push(TrackedElement(0), to: .front)
    // Logical order: [0, 1, 2]
}
print("  Deinit order: \(Tracker.deinitOrder)")
print("  Expected: [0, 1, 2] (front to back)")
print("  Test 5: \(Tracker.deinitOrder == [0, 1, 2] ? "PASSED" : "FAILED")")

print("\n=== Test 6: Deque.Small deinit order (inline) ===")
Tracker.reset()
do {
    var small = Deque<TrackedElement>.Small<4>()
    small.push(TrackedElement(1), to: .back)
    small.push(TrackedElement(2), to: .back)
    // Still inline
}
print("  Deinit order: \(Tracker.deinitOrder)")
print("  Expected: [1, 2] (front to back)")
print("  Test 6: \(Tracker.deinitOrder == [1, 2] ? "PASSED" : "FAILED")")

print("\n=== Test 7: Deque.Small deinit order (spilled to heap) ===")
Tracker.reset()
do {
    var small = Deque<TrackedElement>.Small<2>()
    small.push(TrackedElement(1), to: .back)
    small.push(TrackedElement(2), to: .back)
    small.push(TrackedElement(3), to: .back)  // Triggers spill
    // Now on heap, logical order: [1, 2, 3]
}
print("  Deinit order: \(Tracker.deinitOrder)")
print("  Expected: [1, 2, 3] (front to back)")
print("  Test 7: \(Tracker.deinitOrder == [1, 2, 3] ? "PASSED" : "FAILED")")

print("\n=== Test 8: Empty deque deinit (no crash) ===")
Tracker.reset()
do {
    let _: Deque<TrackedElement> = Deque()
    let _: Deque<TrackedElement>.Bounded = try! Deque<TrackedElement>.Bounded(capacity: 5)
    let _: Deque<TrackedElement>.Inline<4> = Deque<TrackedElement>.Inline<4>()
    let _: Deque<TrackedElement>.Small<4> = Deque<TrackedElement>.Small<4>()
}
print("  Deinit order: \(Tracker.deinitOrder)")
print("  Expected: [] (no elements)")
print("  Test 8: \(Tracker.deinitOrder == [] ? "PASSED" : "FAILED")")

print("\n=== All deinit order tests completed ===")
