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
// NOTE: Bounded subscripts are defined in Deque.swift to avoid ~Copyable constraint poisoning
// during emit-module when extensions are in separate files.


// NOTE: Bounded.element(at:) is defined in Deque.swift to avoid ~Copyable constraint poisoning
