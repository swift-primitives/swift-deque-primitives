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

extension Deque {
    /// Type-local CoW storage for Deque.
    ///
    /// Implements a ring buffer with copy-on-write semantics.
    @safe
    @usableFromInline
    struct Storage {
        @usableFromInline
        var buffer: Buffer

        @usableFromInline
        init() {
            unsafe self.buffer = Buffer.create(minimumCapacity: 0)
        }

        @usableFromInline
        init(buffer: Buffer) {
            unsafe self.buffer = buffer
        }
    }
}

// MARK: - Buffer Header

extension Deque.Storage {
    /// Header for the ring buffer.
    @usableFromInline
    struct Header {
        /// Current number of elements.
        @usableFromInline
        var count: Int

        /// Index of the first element in the buffer.
        @usableFromInline
        var head: Int

        /// Total capacity of the buffer.
        @usableFromInline
        var capacity: Int

        @usableFromInline
        init(count: Int = 0, head: Int = 0, capacity: Int = 0) {
            self.count = count
            self.head = head
            self.capacity = capacity
        }
    }
}

// MARK: - Buffer

// MARK: - Debug Copy Counter

#if DEBUG
/// Debug-only copy counter for testing CoW behavior.
/// Must be outside generic Buffer class since static stored properties
/// are not supported in generic types.
@usableFromInline
enum _DequeBufferDebug {
    @usableFromInline
    nonisolated(unsafe) static var _copyCount: Int = 0
}
#endif

extension Deque.Storage {
    /// ManagedBuffer-based storage for the ring buffer.
    @unsafe
    @usableFromInline
    final class Buffer: ManagedBuffer<Header, Element> {
        @usableFromInline
        static func create(minimumCapacity: Int) -> Buffer {
            let requestedCapacity = Swift.max(minimumCapacity, 4)
            let buffer = unsafe self.create(minimumCapacity: requestedCapacity) { buffer in
                // Use the actual capacity from ManagedBuffer, not the requested one
                Header(count: 0, head: 0, capacity: buffer.capacity)
            }
            return unsafe unsafeDowncast(buffer, to: Buffer.self)
        }

        @usableFromInline
        func copy(minimumCapacity: Int) -> Buffer {
            #if DEBUG
            unsafe (_DequeBufferDebug._copyCount += 1)
            #endif
            let requestedCapacity = Swift.max(minimumCapacity, unsafe header.count, 4)
            let newBuffer = unsafe Buffer.create(minimumCapacity: requestedCapacity)
            // Note: newBuffer.header.capacity is already set to actual capacity by create()

            unsafe (newBuffer.header.count = header.count)
            unsafe (newBuffer.header.head = 0)

            // Copy elements in logical order
            unsafe withUnsafeMutablePointerToElements { src in
                unsafe newBuffer.withUnsafeMutablePointerToElements { dst in
                    let count = unsafe header.count
                    let cap = unsafe header.capacity
                    let head = unsafe header.head

                    for i in 0..<count {
                        let srcIndex = (head + i) % cap
                        unsafe (dst + i).initialize(to: src[srcIndex])
                    }
                }
            }

            return unsafe newBuffer
        }

        deinit {
            unsafe withUnsafeMutablePointers { header, elements in
                let count = unsafe header.pointee.count
                let capacity = unsafe header.pointee.capacity
                let head = unsafe header.pointee.head

                for i in 0..<count {
                    let index = (head + i) % capacity
                    unsafe (elements + index).deinitialize(count: 1)
                }
            }
        }
    }
}

// MARK: - Storage Properties

extension Deque.Storage {
    @usableFromInline
    var count: Int {
        unsafe buffer.header.count
    }

    @usableFromInline
    var capacity: Int {
        unsafe buffer.header.capacity
    }

    @usableFromInline
    var isEmpty: Bool {
        // swiftlint:disable:next empty_count
        count == 0  // Defining isEmpty in terms of count is correct here
    }
}

// MARK: - Uniqueness

extension Deque.Storage {
    /// Ensures the buffer is uniquely referenced with at least the specified capacity.
    @usableFromInline
    mutating func ensureUnique(minimumCapacity: Int = 0) {
        let requiredCapacity = Swift.max(minimumCapacity, count)

        if unsafe !isKnownUniquelyReferenced(&buffer) || capacity < requiredCapacity {
            let newCapacity = Swift.max(requiredCapacity, capacity * 2, 4)
            unsafe self.buffer = buffer.copy(minimumCapacity: newCapacity)
        }
    }
}

// MARK: - Element Access

extension Deque.Storage {
    /// Physical index in the buffer for a logical index.
    @usableFromInline
    func physicalIndex(_ logicalIndex: Int) -> Int {
        unsafe (buffer.header.head + logicalIndex) % buffer.header.capacity
    }

    /// Access element at logical index.
    @usableFromInline
    subscript(_ index: Int) -> Element {
        get {
            unsafe buffer.withUnsafeMutablePointerToElements { elements in
                unsafe elements[physicalIndex(index)]
            }
        }
        set {
            ensureUnique()
            unsafe buffer.withUnsafeMutablePointerToElements { elements in
                unsafe (elements[physicalIndex(index)] = newValue)
            }
        }
    }
}

// MARK: - Append / Prepend

extension Deque.Storage {
    /// Appends an element to the back.
    @usableFromInline
    mutating func append(_ element: Element) {
        ensureUnique(minimumCapacity: count + 1)

        unsafe buffer.withUnsafeMutablePointers { header, elements in
            let tail = unsafe (header.pointee.head + header.pointee.count) % header.pointee.capacity
            unsafe (elements + tail).initialize(to: element)
            unsafe (header.pointee.count += 1)
        }
    }

    /// Prepends an element to the front.
    @usableFromInline
    mutating func prepend(_ element: Element) {
        ensureUnique(minimumCapacity: count + 1)

        unsafe buffer.withUnsafeMutablePointers { header, elements in
            let capacity = unsafe header.pointee.capacity
            let newHead = unsafe (header.pointee.head - 1 + capacity) % capacity
            unsafe (elements + newHead).initialize(to: element)
            unsafe (header.pointee.head = newHead)
            unsafe (header.pointee.count += 1)
        }
    }
}

// MARK: - Remove

extension Deque.Storage {
    /// Removes and returns the last element.
    @usableFromInline
    mutating func removeLast() -> Element {
        precondition(!isEmpty, "Cannot remove from empty deque")
        ensureUnique()

        return unsafe buffer.withUnsafeMutablePointers { header, elements in
            unsafe (header.pointee.count -= 1)
            let tail = unsafe (header.pointee.head + header.pointee.count) % header.pointee.capacity
            return unsafe (elements + tail).move()
        }
    }

    /// Removes and returns the first element.
    @usableFromInline
    mutating func removeFirst() -> Element {
        precondition(!isEmpty, "Cannot remove from empty deque")
        ensureUnique()

        return unsafe buffer.withUnsafeMutablePointers { header, elements in
            let oldHead = unsafe header.pointee.head
            let capacity = unsafe header.pointee.capacity
            unsafe (header.pointee.head = (oldHead + 1) % capacity)
            unsafe (header.pointee.count -= 1)
            return unsafe (elements + oldHead).move()
        }
    }
}

// MARK: - Clear

extension Deque.Storage {
    /// Removes all elements.
    @usableFromInline
    mutating func removeAll(keepingCapacity: Bool = false) {
        if keepingCapacity {
            ensureUnique()
            unsafe buffer.withUnsafeMutablePointers { header, elements in
                let count = unsafe header.pointee.count
                let capacity = unsafe header.pointee.capacity
                let head = unsafe header.pointee.head

                for i in 0..<count {
                    let index = (head + i) % capacity
                    unsafe (elements + index).deinitialize(count: 1)
                }

                unsafe (header.pointee.count = 0)
                unsafe (header.pointee.head = 0)
            }
        } else {
            unsafe self.buffer = Buffer.create(minimumCapacity: 0)
        }
    }
}

// MARK: - Sendable

// ## @unchecked Sendable Justification (MEM-SEND-003)
//
// This conformance disables compiler race checking for internal reference storage.
//
// ### What CoW Does Provide
// - Sequential access from a single task is safe (uniqueness check before mutation)
// - Value copies are independent (mutation triggers buffer copy)
//
// ### What CoW Does NOT Provide
// - No protection against concurrent access to the same Deque instance
// - No synchronization between tasks sharing a reference before CoW triggers
//
// ### Remaining Risks
// - Concurrent read + write to the same Deque instance can race
// - Concurrent writes to the same Deque instance can race
// - The compiler will NOT warn when this creates races
//
// ### Safe Usage
// - Transfer Deque values between tasks (each gets independent copy)
// - Use actor isolation or locks for shared mutable access
//
// ### Why @unchecked Instead of Not Sendable
// - Deque is a value type; transferring it across tasks should be allowed
// - ManagedBuffer does not inherit Sendable, requiring explicit opt-in
extension Deque.Storage: @unchecked Sendable where Element: Sendable {}
