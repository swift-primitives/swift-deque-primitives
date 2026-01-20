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

// MARK: - Hoisted Error Types (Module Level)
//
// Swift does not allow nested types inside generic types to be easily accessed.
// These error types are hoisted to module level and exposed via typealiases to
// provide the expected Nest.Name API (Deque.Error, Deque.Bounded.Error, etc.).
//
// This is a documented exception per [API-EXC-001] due to Swift language
// limitations with generic nested types.
//
// Use the typealias forms in your code:
// - Deque<Element>.Error
// - Deque<Element>.Bounded.Error
// - Deque<Element>.Inline.Error

/// Hoisted implementation of ``Deque/Error``.
///
/// - Note: Use ``Deque/Error`` in your code, not this type directly.
public enum __DequeError: Swift.Error, Sendable, Equatable {
    /// An operation was attempted on an empty deque.
    case empty

    /// An index was out of bounds.
    case bounds(index: Int, count: Int)

    /// The requested capacity is invalid (negative).
    case invalidCapacity
}

/// Hoisted implementation of ``Deque/Bounded/Error``.
///
/// - Note: Use ``Deque/Bounded/Error`` in your code, not this type directly.
public enum __DequeBoundedError: Swift.Error, Sendable, Equatable {
    /// The requested capacity is invalid (negative).
    case invalidCapacity

    /// The deque is full and cannot accept more elements.
    case overflow

    /// An operation was attempted on an empty deque.
    case empty

    /// An index was out of bounds.
    case bounds(index: Int, count: Int)
}

/// Hoisted implementation of ``Deque/Inline/Error``.
///
/// - Note: Use ``Deque/Inline/Error`` in your code, not this type directly.
public enum __DequeInlineError: Swift.Error, Sendable, Equatable {
    /// The deque is full and cannot accept more elements.
    case overflow

    /// An operation was attempted on an empty deque.
    case empty
}

/// Hoisted implementation of ``Deque/Small/Error``.
///
/// - Note: Use ``Deque/Small/Error`` in your code, not this type directly.
public enum __DequeSmallError: Swift.Error, Sendable, Equatable {
    /// An operation was attempted on an empty deque.
    case empty
}

// MARK: - Typealiases (Nest.Name API)
//
// IMPORTANT: Extensions MUST include `where Element: ~Copyable` to prevent
// implicit Copyable constraint. This is a documented Swift compiler limitation.

extension Deque where Element: ~Copyable {
    /// Errors that can occur during unbounded deque operations.
    ///
    /// ## Cases
    ///
    /// - ``Deque/Error/empty``: An operation was attempted on an empty deque.
    /// - ``Deque/Error/bounds(index:count:)``: An index was out of bounds.
    /// - ``Deque/Error/invalidCapacity``: The requested capacity is invalid.
    public typealias Error = __DequeError
}

extension Deque.Bounded where Element: ~Copyable {
    /// Errors that can occur during bounded deque operations.
    ///
    /// ## Cases
    ///
    /// - ``Deque/Bounded/Error/invalidCapacity``: The requested capacity is invalid (negative).
    /// - ``Deque/Bounded/Error/overflow``: The deque is full and cannot accept more elements.
    /// - ``Deque/Bounded/Error/empty``: An operation was attempted on an empty deque.
    /// - ``Deque/Bounded/Error/bounds(index:count:)``: An index was out of bounds.
    public typealias Error = __DequeBoundedError
}

extension Deque.Inline where Element: ~Copyable {
    /// Errors that can occur during inline deque operations.
    ///
    /// ## Cases
    ///
    /// - ``Deque/Inline/Error/overflow``: The deque is full and cannot accept more elements.
    /// - ``Deque/Inline/Error/empty``: An operation was attempted on an empty deque.
    public typealias Error = __DequeInlineError
}

extension Deque.Small where Element: ~Copyable {
    /// Errors that can occur during small deque operations.
    ///
    /// ## Cases
    ///
    /// - ``Deque/Small/Error/empty``: An operation was attempted on an empty deque.
    public typealias Error = __DequeSmallError
}

// MARK: - CustomStringConvertible

extension __DequeError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .empty:
            return "operation attempted on empty deque"
        case .bounds(let index, let count):
            return "index \(index) out of bounds for count \(count)"
        case .invalidCapacity:
            return "invalid capacity (negative)"
        }
    }
}

extension __DequeBoundedError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .invalidCapacity:
            return "invalid capacity (negative)"
        case .overflow:
            return "deque is full"
        case .empty:
            return "operation attempted on empty deque"
        case .bounds(let index, let count):
            return "index \(index) out of bounds for count \(count)"
        }
    }
}

extension __DequeInlineError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .overflow:
            return "deque is full"
        case .empty:
            return "operation attempted on empty deque"
        }
    }
}

extension __DequeSmallError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .empty:
            return "operation attempted on empty deque"
        }
    }
}
