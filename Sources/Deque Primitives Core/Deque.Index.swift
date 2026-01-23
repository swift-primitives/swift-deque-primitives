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

import Index_Primitives

extension Deque where Element: ~Copyable {
    /// Type-safe index for deque elements.
    ///
    /// Uses `Index<Element>` to provide compile-time safety preventing
    /// cross-collection index confusion.
    ///
    /// ## Position Semantics
    ///
    /// Position 0 is the front of the deque (oldest element from front pushes).
    /// Position `count - 1` is the back (newest element from back pushes).
    public typealias Index = Index_Primitives.Index<Element>
}

// MARK: - Typed Subscript (Deque)

extension Deque where Element: ~Copyable {
    /// Accesses the element at the given typed index.
    ///
    /// - Parameter index: The typed index of the element to access (0 = front).
    /// - Precondition: `index.position` must be in `0..<count`.
    @inlinable
    public subscript(index: Index) -> Element {
        _read {
            precondition(index >= .zero && index.position.rawValue < count, "Index out of bounds")
            let physicalIndex = _storage.physicalIndex(index.position.rawValue)
            yield unsafe _cachedPtr[physicalIndex]
        }
        _modify {
            precondition(index >= .zero && index.position.rawValue < count, "Index out of bounds")
            let physicalIndex = _storage.physicalIndex(index.position.rawValue)
            yield &(unsafe _cachedPtr[physicalIndex])
        }
    }
}

extension Deque where Element: Copyable {
    /// Accesses the element at the given typed index with copy-on-write semantics.
    ///
    /// - Parameter index: The typed index of the element to access (0 = front).
    /// - Precondition: `index.position` must be in `0..<count`.
    @inlinable
    public subscript(index: Index) -> Element {
        _read {
            precondition(index >= .zero && index.position.rawValue < count, "Index out of bounds")
            yield _readElement(at: index.position.rawValue)
        }
        _modify {
            makeUnique()
            precondition(index >= .zero && index.position.rawValue < count, "Index out of bounds")
            let physicalIndex = _storage.physicalIndex(index.position.rawValue)
            yield &(unsafe _cachedPtr[physicalIndex])
        }
    }
}

// MARK: - Typed Subscript (Deque.Bounded)

extension Deque.Bounded where Element: ~Copyable {
    /// Accesses the element at the given typed index.
    ///
    /// - Parameter index: The typed index of the element to access (0 = front).
    /// - Precondition: `index.position` must be in `0..<count`.
    @inlinable
    public subscript(index: Deque<Element>.Index) -> Element {
        _read {
            precondition(index >= .zero && index.position.rawValue < count, "Index out of bounds")
            let physicalIndex = _storage.physicalIndex(index.position.rawValue)
            yield unsafe _cachedPtr[physicalIndex]
        }
        _modify {
            precondition(index >= .zero && index.position.rawValue < count, "Index out of bounds")
            let physicalIndex = _storage.physicalIndex(index.position.rawValue)
            yield &(unsafe _cachedPtr[physicalIndex])
        }
    }
}

extension Deque.Bounded where Element: Copyable {
    /// Accesses the element at the given typed index with copy-on-write semantics.
    ///
    /// - Parameter index: The typed index of the element to access (0 = front).
    /// - Precondition: `index.position` must be in `0..<count`.
    @inlinable
    public subscript(index: Deque<Element>.Index) -> Element {
        _read {
            precondition(index >= .zero && index.position.rawValue < count, "Index out of bounds")
            let physicalIndex = _storage.physicalIndex(index.position.rawValue)
            yield unsafe _cachedPtr[physicalIndex]
        }
        _modify {
            makeUnique()
            precondition(index >= .zero && index.position.rawValue < count, "Index out of bounds")
            let physicalIndex = _storage.physicalIndex(index.position.rawValue)
            yield &(unsafe _cachedPtr[physicalIndex])
        }
    }
}

// MARK: - Safe Access

extension Deque where Element: Copyable {
    /// Returns the element at the typed index, or nil if out of bounds.
    ///
    /// - Parameter index: The typed index of the element to access.
    /// - Returns: The element at the index, or `nil` if out of bounds.
    @inlinable
    public func element(at index: Index) -> Element? {
        guard index >= .zero && index.position.rawValue < count else { return nil }
        return _readElement(at: index.position.rawValue)
    }
}

extension Deque.Bounded where Element: Copyable {
    /// Returns the element at the typed index, or nil if out of bounds.
    ///
    /// - Parameter index: The typed index of the element to access.
    /// - Returns: The element at the index, or `nil` if out of bounds.
    @inlinable
    public func element(at index: Deque<Element>.Index) -> Element? {
        guard index >= .zero && index.position.rawValue < count else { return nil }
        let physicalIndex = _storage.physicalIndex(index.position.rawValue)
        return unsafe _storage.withUnsafeMutablePointerToElements { elements in
            unsafe elements[physicalIndex]
        }
    }
}
