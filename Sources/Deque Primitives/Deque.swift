// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-standards open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-standards project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

public import Index_Primitives
public import Input_Primitives

/// Double-ended queue with O(1) amortized operations at both ends.
///
/// `Deque` is a value type with copy-on-write semantics backed by a ring buffer.
/// It supports efficient insertion and removal at both the front and back.
///
/// ## API
///
/// Operations use nested accessors with positional naming (for Copyable elements):
///
/// ```swift
/// var deque = Deque<Int>()
///
/// // Push
/// deque.push.back(1)    // push to back
/// deque.push.front(0)   // push to front
///
/// // Pop
/// let x = try deque.pop.back()   // pop from back
/// let y = try deque.pop.front()  // pop from front
///
/// // Peek (non-throwing)
/// if let back = deque.peek.back { ... }
/// if let front = deque.peek.front { ... }
/// ```
///
/// Direct method API (for all elements including ~Copyable):
///
/// ```swift
/// var deque = Deque<MoveOnlyType>()
///
/// deque.push(element, to: .back)
/// let x = deque.pop(from: .front)
/// deque.peek(at: .back) { element in ... }
/// ```
///
/// ## Variants
///
/// - ``Deque``: Dynamically-growing with amortized O(1) operations (this type)
/// - ``Deque/Bounded``: Fixed-capacity with upfront allocation, throws on overflow
/// - ``Deque/Inline``: Zero-allocation inline storage with compile-time capacity
/// - ``Deque/Small``: Inline storage with spill to heap when exceeded
///
/// ## Move-Only Support
///
/// Both the deque and its elements can be `~Copyable`:
///
/// ```swift
/// struct FileHandle: ~Copyable { ... }
/// var handles = Deque<FileHandle>()
/// handles.push(FileHandle(), to: .back)
/// ```
///
/// ## Sequence Conformance
///
/// When `Element` is `Copyable`, `Deque` conforms to `Sequence` and `Collection`:
///
/// ```swift
/// var deque = Deque<Int>()
/// deque.push.back(1)
/// deque.push.back(2)
/// for element in deque {
///     print(element)  // 1, then 2
/// }
/// ```
///
/// For `~Copyable` elements, use ``forEach(_:)`` instead.
///
/// ## Copy-on-Write
///
/// When `Element` is `Copyable`, `Deque` uses copy-on-write semantics:
/// copies share storage until mutation, providing efficient value semantics.
///
/// ## Thread Safety
///
/// Not thread-safe for concurrent mutation. Synchronize externally.
///
/// ## Complexity
///
/// - Push/pop at either end: O(1) amortized
/// - Random access: O(1)
/// - Insertion/removal in middle: O(n)
@safe
public struct Deque<Element: ~Copyable>: ~Copyable {

    // MARK: - Ring Buffer Header

    /// Header for ring buffer storage: (count, head, bufferCapacity)
    /// Using tuple instead of struct to avoid ~Copyable propagation issues.
    @usableFromInline
    typealias _Header = (count: Int, head: Int, bufferCapacity: Int)

    // MARK: - Unified Storage (nested to inherit Element's ~Copyable context)

    /// Internal storage class for Deque and Deque.Bounded.
    ///
    /// Uses `ManagedBuffer` with a ring buffer layout for efficient double-ended operations.
    /// Declared as a nested class inside `Deque` so that the `Element` generic
    /// inherits the `~Copyable` suppression from the outer type.
    @usableFromInline
    final class Storage: ManagedBuffer<_Header, Element> {

        /// Creates empty storage with no capacity.
        @usableFromInline
        static func create() -> Storage {
            let storage = Storage.create(minimumCapacity: 0) { _ in
                (count: 0, head: 0, bufferCapacity: 0)
            }
            return unsafe unsafeDowncast(storage, to: Storage.self)
        }

        /// Creates storage with the specified minimum capacity.
        @usableFromInline
        static func create(minimumCapacity: Int) -> Storage {
            let requestedCapacity = Swift.max(minimumCapacity, 4)
            let storage = Storage.create(minimumCapacity: requestedCapacity) { buffer in
                (count: 0, head: 0, bufferCapacity: buffer.capacity)
            }
            return unsafe unsafeDowncast(storage, to: Storage.self)
        }

        deinit {
            let count = header.count
            guard count > 0 else { return }
            let cap = header.bufferCapacity
            let head = header.head

            _ = unsafe withUnsafeMutablePointerToElements { elements in
                for i in 0..<count {
                    let index = (head + i) % cap
                    unsafe (elements + index).deinitialize(count: 1)
                }
            }
        }

        /// Returns pointer to element storage.
        @usableFromInline
        var _elementsPointer: UnsafeMutablePointer<Element> {
            unsafe withUnsafeMutablePointerToElements { unsafe $0 }
        }

        /// Physical index for a logical index.
        @usableFromInline
        func physicalIndex(_ logicalIndex: Int) -> Int {
            (header.head + logicalIndex) % header.bufferCapacity
        }

        /// Appends an element to the back.
        @usableFromInline
        func append(_ element: consuming Element) {
            let tail = (header.head + header.count) % header.bufferCapacity
            let ptr = unsafe _elementsPointer
            unsafe (ptr + tail).initialize(to: element)
            header.count += 1
        }

        /// Prepends an element to the front.
        @usableFromInline
        func prepend(_ element: consuming Element) {
            let capacity = header.bufferCapacity
            let newHead = (header.head - 1 + capacity) % capacity
            let ptr = unsafe _elementsPointer
            unsafe (ptr + newHead).initialize(to: element)
            header.head = newHead
            header.count += 1
        }

        /// Removes and returns the last element.
        @usableFromInline
        func removeLast() -> Element {
            header.count -= 1
            let tail = (header.head + header.count) % header.bufferCapacity
            let ptr = unsafe _elementsPointer
            return unsafe (ptr + tail).move()
        }

        /// Removes and returns the first element.
        @usableFromInline
        func removeFirst() -> Element {
            let oldHead = header.head
            let capacity = header.bufferCapacity
            header.head = (oldHead + 1) % capacity
            header.count -= 1
            let ptr = unsafe _elementsPointer
            return unsafe (ptr + oldHead).move()
        }

        /// Deinitializes all elements.
        @usableFromInline
        func deinitializeAll() {
            let count = header.count
            guard count > 0 else { return }
            let cap = header.bufferCapacity
            let head = header.head

            _ = unsafe withUnsafeMutablePointerToElements { elements in
                for i in 0..<count {
                    let index = (head + i) % cap
                    unsafe (elements + index).deinitialize(count: 1)
                }
            }
            header.count = 0
            header.head = 0
        }
    }

    @usableFromInline
    var _storage: Storage

    /// Cached pointer to element storage. Stored in struct to enable property-based Span access.
    /// CRITICAL: Must be updated whenever _storage is replaced (reallocation, CoW copy).
    @usableFromInline
    var _cachedPtr: UnsafeMutablePointer<Element>

    // MARK: - Inline (declared here due to Swift compiler bug with ~Copyable in extensions)

    /// A fixed-capacity, inline-storage deque with compile-time capacity.
    ///
    /// `Deque.Inline` stores elements directly within the struct's memory layout,
    /// requiring no heap allocation. The capacity is specified as a compile-time
    /// generic parameter.
    ///
    /// - Note: This type is declared inside `Deque` (not in an extension) due to a
    ///   Swift compiler bug where nested types with value generic parameters declared
    ///   in extensions do not properly inherit `~Copyable` constraints from the outer type.
    public struct Inline<let capacity: Int>: ~Copyable {
        /// Maximum element stride supported by inline storage (64 bytes per slot).
        @usableFromInline
        static var _maxStride: Int { 64 }

        /// Ring buffer state.
        @usableFromInline
        var _head: Int

        @usableFromInline
        var _count: Int

        /// Raw byte storage. Each slot is 64 bytes (8 Ints on 64-bit).
        @usableFromInline
        var _storage: InlineArray<capacity, (Int, Int, Int, Int, Int, Int, Int, Int)>

        /// Workaround for Swift compiler bug where deinit element cleanup
        /// fails for ~Copyable structs that contain only value-type properties.
        /// Adding a reference type property (`AnyObject?`) fixes the bug.
        /// See: https://github.com/swiftlang/swift/issues/86652
        @usableFromInline
        var _deinitWorkaround: AnyObject? = nil

        /// Creates an empty inline deque.
        @inlinable
        public init() {
            precondition(
                MemoryLayout<Element>.stride <= Self._maxStride,
                "Element stride (\(MemoryLayout<Element>.stride)) exceeds inline storage slot size (\(Self._maxStride) bytes). Use Deque.Bounded instead."
            )
            precondition(
                MemoryLayout<Element>.alignment <= MemoryLayout<Int>.alignment,
                "Element alignment (\(MemoryLayout<Element>.alignment)) exceeds inline storage alignment (\(MemoryLayout<Int>.alignment)). Use Deque.Bounded instead."
            )
            self._head = 0
            self._count = 0
            self._storage = InlineArray(repeating: (0, 0, 0, 0, 0, 0, 0, 0))
        }

        deinit {
            let count = _count
            guard count > 0 else { return }

            let stride = MemoryLayout<Element>.stride
            var index = _head
            unsafe Swift.withUnsafeBytes(of: _storage) { bytes in
                let basePtr = unsafe UnsafeMutableRawPointer(mutating: bytes.baseAddress!)
                for _ in 0..<count {
                    let elementPtr = unsafe (basePtr + index * stride)
                        .assumingMemoryBound(to: Element.self)
                    unsafe elementPtr.deinitialize(count: 1)
                    index = (index + 1) % capacity
                }
            }
        }

        /// Returns a mutable pointer to the element at the given physical index.
        @usableFromInline
        @unsafe
        mutating func _pointerToElement(at physicalIndex: Int) -> UnsafeMutablePointer<Element> {
            let stride = MemoryLayout<Element>.stride
            return unsafe Swift.withUnsafeMutablePointer(to: &_storage) { storagePtr in
                let basePtr = UnsafeMutableRawPointer(storagePtr)
                let elementPtr = unsafe (basePtr + physicalIndex * stride)
                    .assumingMemoryBound(to: Element.self)
                return unsafe elementPtr
            }
        }

        /// Returns a read-only pointer to the element at the given physical index.
        @usableFromInline
        @unsafe
        func _readPointerToElement(at physicalIndex: Int) -> UnsafePointer<Element> {
            let stride = MemoryLayout<Element>.stride
            return unsafe Swift.withUnsafePointer(to: _storage) { storagePtr in
                let basePtr = unsafe UnsafeRawPointer(storagePtr)
                let elementPtr = unsafe (basePtr + physicalIndex * stride)
                    .assumingMemoryBound(to: Element.self)
                return unsafe elementPtr
            }
        }

        /// Physical index for a logical index.
        @usableFromInline
        func _physicalIndex(_ logicalIndex: Int) -> Int {
            (_head + logicalIndex) % Self.capacity
        }
    }

    // MARK: - Small (SmallVec-style: inline then spill to heap)

    /// A deque with small-buffer optimization (SmallVec pattern).
    ///
    /// `Deque.Small` stores up to `inlineCapacity` elements in inline storage,
    /// then automatically spills to heap storage when that capacity is exceeded.
    ///
    /// ## Non-Copyable
    ///
    /// `Deque.Small` is unconditionally `~Copyable` (move-only) because it requires
    /// a deinitializer to clean up inline storage.
    ///
    /// - Note: This type is declared inside `Deque` (not in an extension) due to a
    ///   Swift compiler bug where nested types with value generic parameters declared
    ///   in extensions do not properly inherit `~Copyable` constraints from the outer type.
    @safe
    public struct Small<let inlineCapacity: Int>: ~Copyable {
        /// Maximum element stride supported by inline storage (64 bytes per slot).
        @usableFromInline
        static var _maxStride: Int { 64 }

        /// Ring buffer state for inline storage.
        @usableFromInline
        var _head: Int

        @usableFromInline
        var _count: Int

        /// Raw byte storage for inline elements.
        @usableFromInline
        var _inline: InlineArray<inlineCapacity, (Int, Int, Int, Int, Int, Int, Int, Int)>

        /// Heap storage when spilled. Nil when using inline storage.
        @usableFromInline
        var _heap: Storage?

        /// Cached pointer to heap elements. Only valid when _heap is non-nil.
        @usableFromInline
        var _heapPtr: UnsafeMutablePointer<Element>?

        /// Creates an empty small deque.
        @inlinable
        public init() {
            precondition(
                MemoryLayout<Element>.stride <= Self._maxStride,
                "Element stride (\(MemoryLayout<Element>.stride)) exceeds inline storage slot size (\(Self._maxStride) bytes). Use Deque.Bounded instead."
            )
            precondition(
                MemoryLayout<Element>.alignment <= MemoryLayout<Int>.alignment,
                "Element alignment (\(MemoryLayout<Element>.alignment)) exceeds inline storage alignment (\(MemoryLayout<Int>.alignment)). Use Deque.Bounded instead."
            )
            self._head = 0
            self._count = 0
            self._inline = InlineArray(repeating: (0, 0, 0, 0, 0, 0, 0, 0))
            self._heap = nil
            unsafe self._heapPtr = nil
        }

        deinit {
            let count = _count
            guard count > 0 else { return }

            if let heap = _heap {
                // Elements are on heap - Storage handles cleanup via its deinit
                heap.header.count = count
            } else {
                // Elements are inline - clean up manually
                let stride = MemoryLayout<Element>.stride
                unsafe Swift.withUnsafeBytes(of: _inline) { bytes in
                    let basePtr = unsafe UnsafeMutableRawPointer(mutating: bytes.baseAddress!)
                    for i in 0..<count {
                        let physicalIndex = (_head + i) % inlineCapacity
                        let elementPtr = unsafe (basePtr + physicalIndex * stride)
                            .assumingMemoryBound(to: Element.self)
                        unsafe elementPtr.deinitialize(count: 1)
                    }
                }
            }
        }

        /// Whether the deque is currently using heap storage.
        @inlinable
        public var isSpilled: Bool { _heap != nil }

        // MARK: - Internal Helpers

        /// Returns a mutable pointer to the inline element at the given physical index.
        @usableFromInline
        @unsafe
        mutating func _inlinePointerToElement(at physicalIndex: Int) -> UnsafeMutablePointer<Element> {
            let stride = MemoryLayout<Element>.stride
            return unsafe Swift.withUnsafeMutablePointer(to: &_inline) { storagePtr in
                let basePtr = UnsafeMutableRawPointer(storagePtr)
                let elementPtr = unsafe (basePtr + physicalIndex * stride)
                    .assumingMemoryBound(to: Element.self)
                return unsafe elementPtr
            }
        }

        /// Returns a read-only pointer to the inline element at the given physical index.
        @usableFromInline
        @unsafe
        func _inlineReadPointerToElement(at physicalIndex: Int) -> UnsafePointer<Element> {
            let stride = MemoryLayout<Element>.stride
            return unsafe Swift.withUnsafePointer(to: _inline) { storagePtr in
                let basePtr = unsafe UnsafeRawPointer(storagePtr)
                let elementPtr = unsafe (basePtr + physicalIndex * stride)
                    .assumingMemoryBound(to: Element.self)
                return unsafe elementPtr
            }
        }

        /// Physical index for a logical index (inline storage).
        @usableFromInline
        func _inlinePhysicalIndex(_ logicalIndex: Int) -> Int {
            (_head + logicalIndex) % inlineCapacity
        }

        /// Spills inline storage to heap.
        @usableFromInline
        mutating func _spillToHeap(minimumCapacity: Int) {
            precondition(_heap == nil, "Already spilled")

            // Create heap storage with growth factor
            let newCapacity = Swift.max(minimumCapacity, inlineCapacity * 2, 8)
            let newStorage = Storage.create(minimumCapacity: newCapacity)
            (newStorage.header.count = _count)
            (newStorage.header.head = 0)

            // Move elements from inline to heap (linearizing the ring buffer)
            let stride = MemoryLayout<Element>.stride
            _ = unsafe Swift.withUnsafeBytes(of: _inline) { bytes in
                unsafe newStorage.withUnsafeMutablePointerToElements { heapPtr in
                    let inlineBase = unsafe UnsafeMutableRawPointer(mutating: bytes.baseAddress!)
                    for i in 0..<_count {
                        let physicalIndex = (_head + i) % inlineCapacity
                        let inlineElement = unsafe (inlineBase + physicalIndex * stride)
                            .assumingMemoryBound(to: Element.self)
                        unsafe (heapPtr + i).initialize(to: inlineElement.move())
                    }
                }
            }

            _head = 0  // Reset head since heap storage is linearized
            _heap = newStorage
            unsafe (_heapPtr = newStorage._elementsPointer)
        }
    }

    // MARK: - Bounded

    /// A fixed-capacity deque supporting move-only elements.
    ///
    /// `Deque.Bounded` allocates storage upfront and throws on overflow.
    /// Use this variant when capacity is known or in contexts requiring
    /// predictable memory behavior (embedded, real-time).
    ///
    /// ## Sequence Conformance
    ///
    /// When `Element` is `Copyable`, `Deque.Bounded` conforms to `Sequence`.
    ///
    /// ## Copy-on-Write
    ///
    /// When `Element` is `Copyable`, `Deque.Bounded` uses copy-on-write semantics.
    @safe
    public struct Bounded: ~Copyable {
        @usableFromInline
        var _storage: Storage  // Uses unified nested storage class

        /// Cached pointer to element storage.
        @usableFromInline
        @unsafe
        var _cachedPtr: UnsafeMutablePointer<Element>

        /// The maximum number of elements the deque can hold.
        public let capacity: Int

        /// Creates a deque with the specified capacity.
        ///
        /// - Parameter capacity: Maximum number of elements. Must be non-negative.
        /// - Throws: ``Deque/Bounded/Error/invalidCapacity`` if capacity is negative.
        @inlinable
        public init(capacity: Int) throws(__Deque.Bounded.Error) {
            guard capacity >= 0 else {
                throw .invalidCapacity
            }

            self._storage = Storage.create(minimumCapacity: capacity)
            unsafe (self._cachedPtr = _storage._elementsPointer)
            self.capacity = capacity
        }

        // Note: No deinit needed - Storage handles cleanup
    }

    // MARK: - Position

    /// Which end of the deque to operate on.
    public enum Position: Sendable, Equatable {
        /// The front (head) of the deque.
        case front
        /// The back (tail) of the deque.
        case back
    }

    // MARK: - Initialization

    /// Creates an empty deque.
    ///
    /// No allocation occurs until the first push.
    @inlinable
    public init() {
        self._storage = Storage.create()
        unsafe (self._cachedPtr = _storage._elementsPointer)
    }

    /// Creates a deque with reserved capacity.
    ///
    /// Pre-allocates storage for the specified number of elements.
    ///
    /// - Parameter capacity: Number of elements to reserve space for. Must be non-negative.
    /// - Throws: ``Deque/Error/invalidCapacity`` if capacity is negative.
    @inlinable
    public init(reservingCapacity capacity: Int) throws(Deque<Element>.Error) {
        guard capacity >= 0 else {
            throw .invalidCapacity
        }

        if capacity == 0 {
            self._storage = Storage.create()
        } else {
            self._storage = Storage.create(minimumCapacity: capacity)
        }
        unsafe (self._cachedPtr = _storage._elementsPointer)
    }

    // Note: No deinit needed - Storage handles cleanup
}

// MARK: - Conditional Copyable

/// `Deque` is `Copyable` when its elements are `Copyable`.
extension Deque: Copyable where Element: Copyable {}

/// `Deque.Bounded` is `Copyable` when its elements are `Copyable`.
extension Deque.Bounded: Copyable where Element: Copyable {}

// Note: Deque.Inline and Deque.Small are UNCONDITIONALLY ~Copyable due to deinit requirement

// MARK: - Bounded Properties

extension Deque.Bounded where Element: ~Copyable {
    /// The current number of elements in the deque.
    @inlinable
    public var count: Int { _storage.header.count }

    /// Whether the deque is empty.
    @inlinable
    public var isEmpty: Bool { _storage.header.count == 0 }

    /// Whether the deque is full.
    @inlinable
    public var isFull: Bool { _storage.header.count == capacity }
}

// MARK: - Bounded Core Operations (Base - for ~Copyable elements)

extension Deque.Bounded where Element: ~Copyable {
    /// Pushes an element to the specified end of the deque.
    ///
    /// - Parameters:
    ///   - element: The element to push.
    ///   - position: Which end to push to (.front or .back).
    /// - Throws: ``Deque/Bounded/Error/overflow`` if the deque is full.
    /// - Complexity: O(1)
    @inlinable
    public mutating func push(_ element: consuming Element, to position: Deque<Element>.Position) throws(Deque<Element>.Bounded.Error) {
        guard !isFull else {
            throw .overflow
        }
        switch position {
        case .front:
            _storage.prepend(element)
        case .back:
            _storage.append(element)
        }
    }

    /// Pops and returns an element from the specified end, or nil if empty.
    ///
    /// - Parameter position: Which end to pop from (.front or .back).
    /// - Returns: The removed element, or `nil` if the deque is empty.
    /// - Complexity: O(1)
    @inlinable
    public mutating func pop(from position: Deque<Element>.Position) -> Element? {
        guard !isEmpty else { return nil }
        switch position {
        case .front:
            return _storage.removeFirst()
        case .back:
            return _storage.removeLast()
        }
    }

    /// Takes and returns an element from the specified end, or nil if empty.
    ///
    /// - Parameter position: Which end to take from (.front or .back).
    /// - Returns: The removed element, or `nil` if the deque is empty.
    /// - Complexity: O(1)
    @inlinable
    public mutating func take(from position: Deque<Element>.Position) -> Element? {
        pop(from: position)
    }

    /// Removes all elements from the deque.
    ///
    /// The capacity remains unchanged.
    ///
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public mutating func clear() {
        _storage.deinitializeAll()
    }
}

// MARK: - Bounded Copy-on-Write (Copyable elements only)

extension Deque.Bounded where Element: Copyable {
    /// Ensures the storage is uniquely referenced before mutation.
    @usableFromInline
    mutating func makeUnique() {
        if !isKnownUniquelyReferenced(&_storage) {
            _storage = _storage.copy()
            unsafe _cachedPtr = _storage._elementsPointer
        }
    }

    /// Pushes an element to the specified end of the deque (CoW-aware).
    @inlinable
    public mutating func push(_ element: Element, to position: Deque<Element>.Position) throws(Deque<Element>.Bounded.Error) {
        makeUnique()
        guard !isFull else {
            throw .overflow
        }
        switch position {
        case .front:
            _storage.prepend(element)
        case .back:
            _storage.append(element)
        }
    }

    /// Pops and returns an element from the specified end (CoW-aware).
    @inlinable
    public mutating func pop(from position: Deque<Element>.Position) -> Element? {
        makeUnique()
        guard !isEmpty else { return nil }
        switch position {
        case .front:
            return _storage.removeFirst()
        case .back:
            return _storage.removeLast()
        }
    }

    /// Takes and returns an element from the specified end (CoW-aware).
    @inlinable
    public mutating func take(from position: Deque<Element>.Position) -> Element? {
        pop(from: position)
    }

    /// Removes all elements from the deque (CoW-aware).
    @inlinable
    public mutating func clear() {
        makeUnique()
        _storage.deinitializeAll()
    }
}

// MARK: - Bounded Peek

extension Deque.Bounded where Element: ~Copyable {
    /// Peeks at the element at the specified end without removing it.
    ///
    /// Uses a closure to support `~Copyable` elements via borrowing.
    ///
    /// - Parameters:
    ///   - position: Which end to peek at (.front or .back).
    ///   - body: A closure that receives a borrowed reference to the element.
    /// - Returns: The result of the closure, or `nil` if the deque is empty.
    /// - Complexity: O(1)
    @inlinable
    public func peek<R>(at position: Deque<Element>.Position, _ body: (borrowing Element) -> R) -> R? {
        guard !isEmpty else { return nil }
        let logicalIndex = position == .front ? 0 : count - 1
        let physicalIndex = _storage.physicalIndex(logicalIndex)
        return unsafe body((_cachedPtr + physicalIndex).pointee)
    }
}

extension Deque.Bounded where Element: Copyable {
    /// Returns the element at the specified end without removing it, or nil if empty.
    @inlinable
    public func peek(at position: Deque<Element>.Position) -> Element? {
        guard !isEmpty else { return nil }
        let logicalIndex = position == .front ? 0 : count - 1
        let physicalIndex = _storage.physicalIndex(logicalIndex)
        return unsafe _storage.withUnsafeMutablePointerToElements { elements in
            unsafe elements[physicalIndex]
        }
    }
}

// MARK: - Bounded Iteration (for ~Copyable elements)

extension Deque.Bounded where Element: ~Copyable {
    /// Calls the given closure for each element in the deque.
    ///
    /// Elements are visited from front to back.
    ///
    /// - Parameter body: A closure that receives each element.
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public func forEach(_ body: (borrowing Element) -> Void) {
        let count = self.count
        guard count > 0 else { return }
        let cap = _storage.header.bufferCapacity
        let head = _storage.header.head

        for i in 0..<count {
            let physicalIndex = (head + i) % cap
            body(unsafe (_cachedPtr + physicalIndex).pointee)
        }
    }
}

// MARK: - Bounded Truncate

extension Deque.Bounded where Element: ~Copyable {
    /// Removes elements beyond the specified count.
    ///
    /// If `newCount >= count`, this method has no effect.
    ///
    /// - Parameter newCount: The maximum number of elements to retain.
    /// - Complexity: O(k) where k is the number of removed elements.
    @inlinable
    public mutating func truncate(to newCount: Int) {
        let currentCount = count
        guard newCount < currentCount else { return }
        let targetCount = Swift.max(0, newCount)

        let cap = _storage.header.bufferCapacity
        let head = _storage.header.head

        for i in targetCount..<currentCount {
            let physicalIndex = (head + i) % cap
            unsafe (_cachedPtr + physicalIndex).deinitialize(count: 1)
        }
        _storage.header.count = targetCount
    }
}

extension Deque.Bounded where Element: Copyable {
    /// Removes elements beyond the specified count (CoW-aware).
    @inlinable
    public mutating func truncate(to newCount: Int) {
        makeUnique()
        let currentCount = count
        guard newCount < currentCount else { return }
        let targetCount = Swift.max(0, newCount)

        let cap = _storage.header.bufferCapacity
        let head = _storage.header.head

        for i in targetCount..<currentCount {
            let physicalIndex = (head + i) % cap
            unsafe (_cachedPtr + physicalIndex).deinitialize(count: 1)
        }
        _storage.header.count = targetCount
    }
}

// MARK: - End (Backwards Compatibility)

extension Deque where Element: ~Copyable {
    /// Which end of the deque to operate on.
    ///
    /// - Note: Deprecated. Use ``Position`` instead.
    @available(*, deprecated, renamed: "Position")
    public typealias End = Position
}

// MARK: - Properties

extension Deque where Element: ~Copyable {
    /// The current number of elements in the deque.
    @inlinable
    public var count: Int { _storage.header.count }

    /// Whether the deque is empty.
    @inlinable
    public var isEmpty: Bool { _storage.header.count == 0 }

    /// The current capacity of the deque.
    @inlinable
    public var capacity: Int { _storage.header.bufferCapacity }
}

// MARK: - Capacity Management

extension Deque where Element: ~Copyable {
    /// Ensures the storage has capacity for at least the specified number of elements.
    @usableFromInline
    mutating func ensureCapacity(_ minimumCapacity: Int) {
        let currentCapacity = _storage.header.bufferCapacity
        guard currentCapacity < minimumCapacity else { return }

        // Growth factor 2.0, minimum capacity 4
        let newCapacity = Swift.max(minimumCapacity, currentCapacity * 2, 4)
        let newStorage = Storage.create(minimumCapacity: newCapacity)

        // Copy elements in logical order (linearizing the ring buffer)
        let count = _storage.header.count
        let head = _storage.header.head
        let oldCapacity = currentCapacity

        if count > 0 {
            unsafe _storage.withUnsafeMutablePointerToElements { src in
                unsafe newStorage.withUnsafeMutablePointerToElements { dst in
                    for i in 0..<count {
                        let srcIndex = (head + i) % oldCapacity
                        unsafe (dst + i).initialize(to: (src + srcIndex).move())
                    }
                }
            }
        }

        newStorage.header.count = count
        newStorage.header.head = 0
        _storage.header.count = 0  // Prevent double-free

        _storage = newStorage
        unsafe _cachedPtr = unsafe _storage._elementsPointer  // CRITICAL: Update cached pointer
    }

    /// Reserves enough space to store the specified number of elements.
    ///
    /// - Parameter minimumCapacity: The minimum number of elements to reserve space for.
    @inlinable
    public mutating func reserve(_ minimumCapacity: Int) {
        ensureCapacity(minimumCapacity)
    }
}

// MARK: - Core Operations (Base - for ~Copyable elements)

extension Deque where Element: ~Copyable {
    /// Pushes an element to the specified end of the deque.
    ///
    /// - Parameters:
    ///   - element: The element to push.
    ///   - position: Which end to push to (.front or .back).
    /// - Complexity: O(1) amortized
    @inlinable
    public mutating func push(_ element: consuming Element, to position: Position) {
        ensureCapacity(count + 1)
        switch position {
        case .front:
            _storage.prepend(element)
        case .back:
            _storage.append(element)
        }
    }

    /// Pops and returns an element from the specified end, or nil if empty.
    ///
    /// - Parameter position: Which end to pop from (.front or .back).
    /// - Returns: The removed element, or `nil` if the deque is empty.
    /// - Complexity: O(1)
    @inlinable
    public mutating func pop(from position: Position) -> Element? {
        guard !isEmpty else { return nil }
        switch position {
        case .front:
            return _storage.removeFirst()
        case .back:
            return _storage.removeLast()
        }
    }

    /// Takes and returns an element from the specified end, or nil if empty.
    ///
    /// This is an alias for ``pop(from:)`` with clearer semantics for queue usage.
    ///
    /// - Parameter position: Which end to take from (.front or .back).
    /// - Returns: The removed element, or `nil` if the deque is empty.
    /// - Complexity: O(1)
    @inlinable
    public mutating func take(from position: Position) -> Element? {
        pop(from: position)
    }

    /// Removes all elements from the deque.
    ///
    /// - Parameter keepingCapacity: If `true`, the deque keeps its current capacity.
    ///   If `false`, the storage is released. Default is `true`.
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public mutating func clear(keepingCapacity: Bool = true) {
        if !keepingCapacity {
            _storage = Storage.create()
            unsafe (_cachedPtr = _storage._elementsPointer)
        } else {
            _storage.deinitializeAll()
        }
    }
}

// MARK: - Copy-on-Write (Copyable elements only)

extension Deque where Element: Copyable {
    /// Ensures the storage is uniquely referenced before mutation.
    @usableFromInline
    mutating func makeUnique() {
        if !isKnownUniquelyReferenced(&_storage) {
            _storage = _storage.copy()
            unsafe (_cachedPtr = _storage._elementsPointer)  // CRITICAL: Update cached pointer
        }
    }

    /// Pushes an element to the specified end of the deque (CoW-aware).
    @inlinable
    public mutating func push(_ element: Element, to position: Position) {
        makeUnique()
        ensureCapacity(count + 1)
        switch position {
        case .front:
            _storage.prepend(element)
        case .back:
            _storage.append(element)
        }
    }

    /// Pops and returns an element from the specified end, or nil if empty (CoW-aware).
    @inlinable
    public mutating func pop(from position: Position) -> Element? {
        makeUnique()
        guard !isEmpty else { return nil }
        switch position {
        case .front:
            return _storage.removeFirst()
        case .back:
            return _storage.removeLast()
        }
    }

    /// Takes and returns an element from the specified end, or nil if empty (CoW-aware).
    @inlinable
    public mutating func take(from position: Position) -> Element? {
        pop(from: position)
    }

    /// Removes all elements from the deque (CoW-aware).
    @inlinable
    public mutating func clear(keepingCapacity: Bool = true) {
        makeUnique()
        if !keepingCapacity {
            _storage = Storage.create()
            unsafe (_cachedPtr = _storage._elementsPointer)
        } else {
            _storage.deinitializeAll()
        }
    }
}

// MARK: - Peek

extension Deque where Element: ~Copyable {
    /// Peeks at the element at the specified end without removing it.
    ///
    /// Uses a closure to support `~Copyable` elements via borrowing.
    ///
    /// - Parameters:
    ///   - position: Which end to peek at (.front or .back).
    ///   - body: A closure that receives a borrowed reference to the element.
    /// - Returns: The result of the closure, or `nil` if the deque is empty.
    /// - Complexity: O(1)
    @inlinable
    public func peek<R>(at position: Position, _ body: (borrowing Element) -> R) -> R? {
        guard !isEmpty else { return nil }
        let logicalIndex = position == .front ? 0 : count - 1
        let physicalIndex = _storage.physicalIndex(logicalIndex)
        return unsafe _storage.withUnsafeMutablePointerToElements { elements in
            body(unsafe (elements + physicalIndex).pointee)
        }
    }
}

extension Deque where Element: Copyable {
    /// Returns the element at the specified end without removing it, or nil if empty.
    ///
    /// This is a convenience method for `Copyable` elements.
    ///
    /// - Parameter position: Which end to peek at (.front or .back).
    /// - Returns: A copy of the element, or `nil` if the deque is empty.
    /// - Complexity: O(1)
    @inlinable
    public func peek(at position: Position) -> Element? {
        guard !isEmpty else { return nil }
        let logicalIndex = position == .front ? 0 : count - 1
        return _readElement(at: logicalIndex)
    }
}

// MARK: - Element Access (Copyable)

extension Deque where Element: Copyable {
    /// Reads the element at the given logical index.
    @usableFromInline
    func _readElement(at logicalIndex: Int) -> Element {
        let physicalIndex = _storage.physicalIndex(logicalIndex)
        return unsafe _storage.withUnsafeMutablePointerToElements { elements in
            unsafe elements[physicalIndex]
        }
    }
}

// MARK: - Sendable

/// `Deque` is `Sendable` when its elements are `Sendable`.
extension Deque: @unchecked Sendable where Element: Sendable {}

/// `Deque.Bounded` is `Sendable` when its elements are `Sendable`.
extension Deque.Bounded: @unchecked Sendable where Element: Sendable {}

/// `Deque.Inline` is `Sendable` when its elements are `Sendable`.
extension Deque.Inline: @unchecked Sendable where Element: Sendable {}

/// `Deque.Small` is `Sendable` when its elements are `Sendable`.
extension Deque.Small: @unchecked Sendable where Element: Sendable {}

/// `Deque.Storage` is `Sendable` when its elements are `Sendable`.
//extension Deque.Storage: @unchecked Sendable where Element: Sendable {}

// MARK: - Iteration (for ~Copyable elements)

extension Deque where Element: ~Copyable {
    /// Calls the given closure for each element in the deque.
    ///
    /// Elements are visited from front to back.
    ///
    /// - Parameter body: A closure that receives each element.
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public func forEach(_ body: (borrowing Element) -> Void) {
        let count = self.count
        guard count > 0 else { return }
        let cap = _storage.header.bufferCapacity
        let head = _storage.header.head

        _ = unsafe _storage.withUnsafeMutablePointerToElements { elements in
            for i in 0..<count {
                let physicalIndex = (head + i) % cap
                body(unsafe (elements + physicalIndex).pointee)
            }
        }
    }
}

// MARK: - Sequence (Copyable elements only)

/// `Deque` conforms to `Sequence` when `Element` is `Copyable`.
extension Deque: Swift.Sequence where Element: Copyable {

    /// An iterator over the elements of a deque.
    public struct Iterator: IteratorProtocol {
        @usableFromInline
        let _storage: Deque<Element>.Storage

        @usableFromInline
        var _index: Int = 0

        @usableFromInline
        let _count: Int

        @usableFromInline
        init(storage: Deque<Element>.Storage) {
            self._storage = storage
            self._count = storage.header.count
        }

        /// Advances to the next element and returns it, or nil if no next element exists.
        @inlinable
        public mutating func next() -> Element? {
            guard _index < _count else { return nil }
            defer { _index += 1 }
            let physicalIndex = _storage.physicalIndex(_index)
            return unsafe _storage.withUnsafeMutablePointerToElements { elements in
                unsafe elements[physicalIndex]
            }
        }
    }

    /// Returns an iterator over the elements of the deque.
    ///
    /// Elements are yielded from front to back.
    @inlinable
    public func makeIterator() -> Iterator {
        Iterator(storage: _storage)
    }
}

extension Deque.Iterator: @unchecked Sendable where Element: Sendable {}

// MARK: - Collection (Copyable elements only)

extension Deque: Swift.Collection where Element: Copyable {
    /// Type-safe index for deque elements.
    ///
    /// Uses `Index<Element>` to provide compile-time safety preventing
    /// cross-collection index confusion.
    public typealias Index = Index_Primitives.Index<Element>

    @inlinable
    public var startIndex: Index { .zero }

    @inlinable
    public var endIndex: Index { Index(__unchecked: (), position: count) }

    @inlinable
    public func index(after i: Index) -> Index {
        // Force unwrap safe: Collection requires i != endIndex, so i+1 is always valid
        (i + Index.Offset(1))!
    }

    /// Accesses the element at the specified index.
    @inlinable
    public subscript(index: Index) -> Element {
        get {
            precondition(index >= startIndex && index < endIndex, "Index out of bounds")
            return _readElement(at: index.position.rawValue)
        }
        set {
            precondition(index >= startIndex && index < endIndex, "Index out of bounds")
            makeUnique()
            let physicalIndex = _storage.physicalIndex(index.position.rawValue)
            unsafe _storage.withUnsafeMutablePointerToElements { elements in
                unsafe (elements[physicalIndex] = newValue)
            }
        }
    }
}

// MARK: - BidirectionalCollection

extension Deque: BidirectionalCollection where Element: Copyable {
    @inlinable
    public func index(before i: Index) -> Index {
        // Force unwrap safe: BidirectionalCollection requires i != startIndex, so i-1 is always valid
        (i - Index.Offset(1))!
    }
}

// MARK: - RandomAccessCollection

extension Deque: RandomAccessCollection where Element: Copyable {
    @inlinable
    public func distance(from start: Index, to end: Index) -> Int {
        (end.position - start.position).rawValue
    }

    @inlinable
    public func index(_ i: Index, offsetBy distance: Int) -> Index {
        // Force unwrap safe: Collection requires result be valid index; caller's precondition
        (i + Index.Offset(distance))!
    }

    @inlinable
    public func index(_ i: Index, offsetBy distance: Int, limitedBy limit: Index) -> Index? {
        guard let result = i + Index.Offset(distance) else { return nil }
        if distance >= 0 {
            return result <= limit ? result : nil
        } else {
            return result >= limit ? result : nil
        }
    }
}

// MARK: - MutableCollection

extension Deque: MutableCollection where Element: Copyable {}

// MARK: - Bounded Sequence (Copyable elements)

/// `Deque.Bounded` conforms to `Sequence` when `Element` is `Copyable`.
extension Deque.Bounded: Swift.Sequence where Element: Copyable {

    /// An iterator over the elements of a bounded deque.
    public struct Iterator: IteratorProtocol {
        @usableFromInline
        let _storage: Deque<Element>.Storage

        @usableFromInline
        var _index: Int = 0

        @usableFromInline
        let _count: Int

        @usableFromInline
        init(storage: Deque<Element>.Storage) {
            self._storage = storage
            self._count = storage.header.count
        }

        @inlinable
        public mutating func next() -> Element? {
            guard _index < _count else { return nil }
            defer { _index += 1 }
            let physicalIndex = _storage.physicalIndex(_index)
            return unsafe _storage.withUnsafeMutablePointerToElements { elements in
                unsafe elements[physicalIndex]
            }
        }
    }

    @inlinable
    public func makeIterator() -> Iterator {
        Iterator(storage: _storage)
    }
}

// MARK: - Bounded Input Conformance
// NOTE: Per [MEM-COPY-006], protocol conformances for nested types MUST be in the
// same file as the type declaration to avoid breaking ~Copyable propagation.

extension Deque.Bounded: Input.Streaming where Element: Copyable {
    @inlinable
    public var isEmpty: Bool { count == 0 }

    @inlinable
    public var first: Element? {
        peek(at: .front)
    }

    @inlinable
    @discardableResult
    public mutating func advance() -> Element {
        guard let element = pop(from: .front) else {
            preconditionFailure("Cannot advance from empty deque")
        }
        return element
    }
}

extension Deque.Bounded: Input.`Protocol` where Element: Copyable {
    public struct Checkpoint: Sendable, Comparable {
        @usableFromInline
        let head: Int

        @usableFromInline
        let count: Int

        @usableFromInline
        init(head: Int, count: Int) {
            self.head = head
            self.count = count
        }

        @inlinable
        public static func < (lhs: Checkpoint, rhs: Checkpoint) -> Bool {
            // Earlier checkpoints have higher counts (less consumed)
            lhs.count > rhs.count
        }
    }

    @inlinable
    public var checkpoint: Checkpoint {
        Checkpoint(head: _storage.header.head, count: _storage.header.count)
    }

    @inlinable
    public var checkpointRange: ClosedRange<Checkpoint> {
        checkpoint...checkpoint
    }

    @inlinable
    public mutating func setPosition(to checkpoint: Checkpoint) {
        makeUnique()
        _storage.header.head = checkpoint.head
        _storage.header.count = checkpoint.count
    }

    @inlinable
    public mutating func advance(by n: Int) {
        precondition(n >= 0 && n <= count, "Cannot advance by more elements than available")
        makeUnique()
        for _ in 0..<n {
            _ = _storage.removeFirst()
        }
    }

    @inlinable
    public var remaining: Self {
        self
    }
}

extension Deque.Bounded: Input.Access.Random where Element: Copyable {
    @inlinable
    public subscript(offset offset: Int) -> Element {
        precondition(offset >= 0 && offset < count, "Offset out of bounds")
        let physicalIndex = _storage.physicalIndex(offset)
        return unsafe _storage.withUnsafeMutablePointerToElements { elements in
            unsafe elements[physicalIndex]
        }
    }
}

// MARK: - Storage Copyable Helpers

extension Deque.Storage where Element: Copyable {

    /// Creates a copy of this storage with all elements duplicated.
    @usableFromInline
    func copy() -> Deque.Storage {
        let count = header.count
        guard count > 0 else {
            return Deque.Storage.create()
        }

        let new = Deque.Storage.create(minimumCapacity: header.bufferCapacity)
        (new.header.count = count)
        (new.header.head = 0)

        // Copy elements in logical order (linearizing)
        let cap = header.bufferCapacity
        let head = header.head

        _ = unsafe withUnsafeMutablePointerToElements { src in
            unsafe new.withUnsafeMutablePointerToElements { dst in
                for i in 0..<count {
                    let srcIndex = (head + i) % cap
                    unsafe (dst + i).initialize(to: src[srcIndex])
                }
            }
        }

        return new
    }
}

// MARK: - Equatable (Copyable)

extension Deque: Equatable where Element: Equatable & Copyable {
    @inlinable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        guard lhs.count == rhs.count else { return false }
        for i in 0..<lhs.count {
            if lhs._readElement(at: i) != rhs._readElement(at: i) {
                return false
            }
        }
        return true
    }
}

// MARK: - Hashable (Copyable)

extension Deque: Hashable where Element: Hashable & Copyable {
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(count)
        for i in 0..<count {
            hasher.combine(_readElement(at: i))
        }
    }
}

// MARK: - ExpressibleByArrayLiteral (Copyable)

extension Deque: ExpressibleByArrayLiteral where Element: Copyable {
    @inlinable
    public init(arrayLiteral elements: Element...) {
        self.init()
        for element in elements {
            push(element, to: .back)
        }
    }
}

// MARK: - Sequence Initializer (Copyable)

extension Deque where Element: Copyable {
    /// Creates a deque containing the elements of a sequence.
    ///
    /// - Parameter elements: The sequence of elements.
    @inlinable
    public init<S: Swift.Sequence>(_ elements: S) where S.Element == Element {
        self.init()
        for element in elements {
            push(element, to: .back)
        }
    }
}

// MARK: - CustomStringConvertible

#if !hasFeature(Embedded)
extension Deque: CustomStringConvertible where Element: Copyable {
    public var description: String {
        var result = "Deque(["
        var first = true
        for i in 0..<count {
            if !first { result += ", " }
            result += String(describing: _readElement(at: i))
            first = false
        }
        result += "])"
        return result
    }
}
#endif

// MARK: - Element Access (Throwing)

extension Deque where Element: Copyable {
    /// Accesses the element at the specified index.
    ///
    /// - Parameter index: The index of the element to access.
    /// - Returns: The element at the index.
    /// - Throws: `Deque.Error.bounds` if the index is out of bounds.
    @inlinable
    public func element(at index: Index) throws(Deque<Element>.Error) -> Element {
        guard index >= startIndex && index < endIndex else {
            throw .bounds(index: index.position.rawValue, count: count)
        }
        return _readElement(at: index.position.rawValue)
    }
}

// MARK: - Internal CoW Identity (for testing)

extension Deque where Element: Copyable {
    /// Buffer identity for CoW testing.
    @usableFromInline
    internal var _identity: ObjectIdentifier {
        ObjectIdentifier(_storage)
    }
}

// MARK: - Legacy Internal Helpers (for backward compatibility with accessor files)

extension Deque where Element: Copyable {
    /// Internal helper for push operations (legacy compatibility).
    @inlinable
    mutating func _push(_ element: Element, to end: Position) {
        push(element, to: end)
    }

    /// Internal helper for pop operations (legacy compatibility).
    @inlinable
    mutating func _pop(from end: Position) throws(Deque<Element>.Error) -> Element {
        guard let element = pop(from: end) else {
            throw .empty
        }
        return element
    }

    /// Internal helper for peek operations (legacy compatibility).
    @inlinable
    func _peek(at end: Position) -> Element? {
        peek(at: end)
    }
}
