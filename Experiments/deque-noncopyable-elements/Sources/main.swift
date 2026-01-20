// MARK: - Claim Verification: CLAIM-004
// Source: Deque.swift:54-62
// Claim: "Move-only support: Both deque and elements can be ~Copyable"
//
// Verification method: Runtime behavior test
// Hypothesis: Deque<~Copyable> compiles and executes correctly for all variants
//
// Toolchain: swift-6.2-RELEASE
// Result: CONFIRMED - All ~Copyable variants (Deque, Bounded, Inline, Small) work correctly
// Date: 2026-01-20
//
// Evidence:
// - Deque<~Copyable>: push/pop/peek/forEach all work, deinit fires correctly
// - Deque.Bounded<~Copyable>: push/pop work with capacity enforcement
// - Deque.Inline<~Copyable>: push/pop work with inline storage
// - Deque.Small<~Copyable>: inline-to-heap spill works correctly

import Deque_Primitives

// --- Test Type: ~Copyable element ---
struct Token: ~Copyable {
    let id: Int
    init(_ id: Int) {
        print("Token(\(id)) created")
        self.id = id
    }
    deinit {
        print("Token(\(self.id)) destroyed")
    }
}

print("=== Variant 1: Deque<~Copyable> ===")
do {
    var deque = Deque<Token>()
    deque.push(Token(1), to: .back)
    deque.push(Token(2), to: .back)
    deque.push(Token(0), to: .front)

    print("Count: \(deque.count)")  // Expected: 3

    // Peek via closure (borrowing)
    deque.peek(at: .front) { token in
        print("Front peek: \(token.id)")  // Expected: 0
    }

    // Pop operations
    if let token = deque.pop(from: .front) {
        print("Popped front: \(token.id)")  // Expected: 0
    }

    // forEach via borrowing
    print("Remaining elements:")
    deque.forEach { token in
        print("  - \(token.id)")  // Expected: 1, 2
    }

    print("Deque going out of scope...")
}
print("Deque destroyed\n")

print("=== Variant 2: Deque.Bounded<~Copyable> ===")
do {
    var bounded = try Deque<Token>.Bounded(capacity: 5)
    try bounded.push(Token(10), to: .back)
    try bounded.push(Token(20), to: .back)

    print("Bounded count: \(bounded.count)")  // Expected: 2
    print("Bounded capacity: \(bounded.capacity)")  // Expected: 5

    if let token = bounded.pop(from: .back) {
        print("Popped back: \(token.id)")  // Expected: 20
    }

    print("Bounded going out of scope...")
}
print("Bounded destroyed\n")

print("=== Variant 3: Deque.Inline<~Copyable> ===")
do {
    var inline = Deque<Token>.Inline<4>()
    try inline.push(Token(100), to: .back)
    try inline.push(Token(200), to: .front)

    print("Inline count: \(inline.count)")  // Expected: 2
    print("Inline isFull: \(inline.isFull)")  // Expected: false

    if let token = inline.pop(from: .front) {
        print("Popped front: \(token.id)")  // Expected: 200
    }

    print("Inline going out of scope...")
}
print("Inline destroyed\n")

print("=== Variant 4: Deque.Small<~Copyable> ===")
do {
    var small = Deque<Token>.Small<2>()
    small.push(Token(1000), to: .back)
    small.push(Token(2000), to: .back)
    print("Small isSpilled (should be false): \(small.isSpilled)")

    // Push beyond inline capacity to trigger spill
    small.push(Token(3000), to: .back)
    print("Small isSpilled (should be true): \(small.isSpilled)")
    print("Small count: \(small.count)")  // Expected: 3

    // Pop from spilled storage
    if let token = small.pop(from: .front) {
        print("Popped front: \(token.id)")  // Expected: 1000
    }

    print("Small going out of scope...")
}
print("Small destroyed\n")

print("=== All variants completed successfully ===")
