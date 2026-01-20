// MARK: - Investigation: ASSUMP-005 Deque.Inline Deinit Order
// Trigger: deque-deinit-order Test 5 showed empty deinit order for Deque.Inline
// Source: Deque.swift:268-282 (Inline deinit)
//
// Hypothesis: Deque.Inline deinit should fire for all elements in front-to-back order
// Investigation: Isolate Inline deinit behavior from other variants
//
// Toolchain: swift-6.2-RELEASE
// Result: BUG CONFIRMED AND FIXED
// Date: 2026-01-20
//
// ROOT CAUSE:
// Swift compiler bug where deinit element cleanup doesn't work correctly for
// ~Copyable structs that contain ONLY value types. Adding a reference type
// property (even unused `AnyObject? = nil`) changes compiler codegen and fixes it.
//
// FIX APPLIED:
// Added `_deinitWorkaround: AnyObject? = nil` property to Deque.Inline struct.
// This triggers correct deinit codegen without changing observable behavior.
//
// EVIDENCE:
// - Without workaround: Inline deinit does not call element deinits (FAIL)
// - With AnyObject? workaround: All tests pass
// - With UnsafeRawPointer? workaround: Still fails (must be reference type)
// - Deque.Small works because it has `_heap: Storage?` (reference type)
//
// TODO: File Swift compiler bug report and remove workaround when fixed.

import Deque_Primitives

// --- Tracker with nonisolated(unsafe) for Swift 6 concurrency ---
final class Tracker: @unchecked Sendable {
    nonisolated(unsafe) static var deinitOrder: [Int] = []
    nonisolated(unsafe) static var initOrder: [Int] = []
    static func reset() {
        deinitOrder = []
        initOrder = []
    }
}

struct TrackedElement: ~Copyable {
    let id: Int
    init(_ id: Int) {
        Tracker.initOrder.append(id)
        self.id = id
        print("  TrackedElement(\(id)) init")
    }
    deinit {
        Tracker.deinitOrder.append(id)
        print("  TrackedElement(\(id)) deinit")
    }
}

// ============================================================
// Test 1: Minimal Inline - single element
// ============================================================
print("=== Test 1: Deque.Inline with single element ===")
Tracker.reset()
do {
    print("Creating Inline<4>...")
    var inline = Deque<TrackedElement>.Inline<4>()
    print("Pushing element 1...")
    try! inline.push(TrackedElement(1), to: .back)
    print("Count: \(inline.count)")
    print("About to exit scope...")
}
print("After scope exit")
print("  Init order: \(Tracker.initOrder)")
print("  Deinit order: \(Tracker.deinitOrder)")
print("  Test 1: \(Tracker.deinitOrder == [1] ? "PASSED" : "FAILED")")

// ============================================================
// Test 2: Inline - multiple elements, back only
// ============================================================
print("\n=== Test 2: Deque.Inline with 3 elements (back push) ===")
Tracker.reset()
do {
    var inline = Deque<TrackedElement>.Inline<4>()
    try! inline.push(TrackedElement(1), to: .back)
    try! inline.push(TrackedElement(2), to: .back)
    try! inline.push(TrackedElement(3), to: .back)
    print("Count: \(inline.count)")
    print("Exiting scope...")
}
print("After scope exit")
print("  Init order: \(Tracker.initOrder)")
print("  Deinit order: \(Tracker.deinitOrder)")
print("  Test 2: \(Tracker.deinitOrder == [1, 2, 3] ? "PASSED" : "FAILED")")

// ============================================================
// Test 3: Inline - elements with front push (ring buffer shift)
// ============================================================
print("\n=== Test 3: Deque.Inline with front push (ring buffer) ===")
Tracker.reset()
do {
    var inline = Deque<TrackedElement>.Inline<4>()
    try! inline.push(TrackedElement(2), to: .back)   // [2]
    try! inline.push(TrackedElement(1), to: .front)  // [1, 2] - head shifted
    try! inline.push(TrackedElement(3), to: .back)   // [1, 2, 3]
    print("Count: \(inline.count)")
    print("Logical order should be: [1, 2, 3]")
    print("Exiting scope...")
}
print("After scope exit")
print("  Init order: \(Tracker.initOrder)")
print("  Deinit order: \(Tracker.deinitOrder)")
print("  Expected deinit: [1, 2, 3] (front to back)")
print("  Test 3: \(Tracker.deinitOrder == [1, 2, 3] ? "PASSED" : "FAILED")")

// ============================================================
// Test 4: Compare with Deque (heap) - same operations
// ============================================================
print("\n=== Test 4: Deque (heap) for comparison ===")
Tracker.reset()
do {
    var deque = Deque<TrackedElement>()
    deque.push(TrackedElement(2), to: .back)
    deque.push(TrackedElement(1), to: .front)
    deque.push(TrackedElement(3), to: .back)
    print("Count: \(deque.count)")
    print("Exiting scope...")
}
print("After scope exit")
print("  Init order: \(Tracker.initOrder)")
print("  Deinit order: \(Tracker.deinitOrder)")
print("  Test 4 (Deque heap): \(Tracker.deinitOrder == [1, 2, 3] ? "PASSED" : "FAILED")")

// ============================================================
// Test 5: Inline with pop before scope exit
// ============================================================
print("\n=== Test 5: Deque.Inline with pop before exit ===")
Tracker.reset()
do {
    var inline = Deque<TrackedElement>.Inline<4>()
    try! inline.push(TrackedElement(1), to: .back)
    try! inline.push(TrackedElement(2), to: .back)
    try! inline.push(TrackedElement(3), to: .back)
    print("Before pop - count: \(inline.count)")

    // Pop one element
    if let popped = inline.pop(from: .front) {
        print("Popped: \(popped.id)")
    }
    print("After pop - count: \(inline.count)")
    print("Remaining elements should be [2, 3]")
    print("Exiting scope...")
}
print("After scope exit")
print("  Init order: \(Tracker.initOrder)")
print("  Deinit order: \(Tracker.deinitOrder)")
print("  Expected: [1] (from pop) then [2, 3] (from scope exit)")
print("  Test 5: \(Tracker.deinitOrder == [1, 2, 3] ? "PASSED" : "FAILED")")

// ============================================================
// Test 6: Check if Inline deinit is even being called
// ============================================================
print("\n=== Test 6: Verify Inline deinit code path ===")
Tracker.reset()

// Use a separate function to ensure scope is clear
func testInlineDeinit() {
    var inline = Deque<TrackedElement>.Inline<4>()
    try! inline.push(TrackedElement(100), to: .back)
    print("Inside function - count: \(inline.count)")
    // inline goes out of scope here
}

print("Calling function...")
testInlineDeinit()
print("Function returned")
print("  Deinit order: \(Tracker.deinitOrder)")
print("  Test 6: \(Tracker.deinitOrder == [100] ? "PASSED" : "FAILED")")

// ============================================================
// Test 7: Empty Inline (should not crash, no deinit calls)
// ============================================================
print("\n=== Test 7: Empty Inline (guard check) ===")
Tracker.reset()
do {
    let _: Deque<TrackedElement>.Inline<4> = Deque<TrackedElement>.Inline<4>()
}
print("  Deinit order: \(Tracker.deinitOrder)")
print("  Expected: [] (empty)")
print("  Test 7: \(Tracker.deinitOrder == [] ? "PASSED" : "FAILED")")

// ============================================================
// Test 8: Deque.Small INLINE path (not spilled) - for comparison
// ============================================================
print("\n=== Test 8: Deque.Small inline path (not spilled) ===")
Tracker.reset()
do {
    var small = Deque<TrackedElement>.Small<4>()
    small.push(TrackedElement(1), to: .back)
    small.push(TrackedElement(2), to: .back)
    print("Count: \(small.count)")
    print("isSpilled: \(small.isSpilled)")  // Should be false
    print("Exiting scope...")
}
print("After scope exit")
print("  Init order: \(Tracker.initOrder)")
print("  Deinit order: \(Tracker.deinitOrder)")
print("  Test 8 (Small inline): \(Tracker.deinitOrder == [1, 2] ? "PASSED" : "FAILED")")

// ============================================================
// Test 9: Deque.Small SPILLED path - for comparison
// ============================================================
print("\n=== Test 9: Deque.Small spilled path ===")
Tracker.reset()
do {
    var small = Deque<TrackedElement>.Small<2>()
    small.push(TrackedElement(1), to: .back)
    small.push(TrackedElement(2), to: .back)
    small.push(TrackedElement(3), to: .back)  // Triggers spill
    print("Count: \(small.count)")
    print("isSpilled: \(small.isSpilled)")  // Should be true
    print("Exiting scope...")
}
print("After scope exit")
print("  Init order: \(Tracker.initOrder)")
print("  Deinit order: \(Tracker.deinitOrder)")
print("  Test 9 (Small spilled): \(Tracker.deinitOrder == [1, 2, 3] ? "PASSED" : "FAILED")")

print("\n=== Investigation Complete ===")
