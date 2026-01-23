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
// - Deque<Element>.Small.Error

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

// MARK: - Main Error Typealias

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

// MARK: - Hoisted Variant Error Types
//
// Uses nested namespace pattern per [API-NAME-002] to avoid compound identifiers
// like `__DequeBoundedError`. Instead uses `__Deque.Bounded.Error`.

/// Hoisted namespace for Deque variant error types.
///
/// This namespace enum avoids compound identifiers like `__DequeBoundedError`
/// per [API-NAME-002], providing the preferred `__Deque.Bounded.Error` pattern.
///
/// - Note: Use the typealias forms (e.g., ``Deque/Bounded/Error``) in your code,
///   not this namespace directly.
public enum __Deque {
    /// Namespace for Deque.Bounded error types.
    public enum Bounded {
        /// Errors that can occur during bounded deque operations.
        ///
        /// ## Cases
        ///
        /// - ``__Deque/Bounded/Error/invalidCapacity``: The requested capacity is invalid (negative).
        /// - ``__Deque/Bounded/Error/overflow``: The deque is full and cannot accept more elements.
        /// - ``__Deque/Bounded/Error/empty``: An operation was attempted on an empty deque.
        /// - ``__Deque/Bounded/Error/bounds(index:count:)``: An index was out of bounds.
        public enum Error: Swift.Error, Sendable, Equatable {
            /// The requested capacity is invalid (negative).
            case invalidCapacity
            /// The deque is full and cannot accept more elements.
            case overflow
            /// An operation was attempted on an empty deque.
            case empty
            /// An index was out of bounds.
            case bounds(index: Int, count: Int)
        }
    }

    /// Namespace for Deque.Inline error types.
    public enum Inline {
        /// Errors that can occur during inline deque operations.
        ///
        /// ## Cases
        ///
        /// - ``__Deque/Inline/Error/overflow``: The deque is full and cannot accept more elements.
        /// - ``__Deque/Inline/Error/empty``: An operation was attempted on an empty deque.
        public enum Error: Swift.Error, Sendable, Equatable {
            /// The deque is full and cannot accept more elements.
            case overflow
            /// An operation was attempted on an empty deque.
            case empty
        }
    }

    /// Namespace for Deque.Small error types.
    public enum Small {
        /// Errors that can occur during small deque operations.
        ///
        /// ## Cases
        ///
        /// - ``__Deque/Small/Error/empty``: An operation was attempted on an empty deque.
        ///
        /// - Note: Small deques grow to heap storage on overflow, so overflow is not possible.
        public enum Error: Swift.Error, Sendable, Equatable {
            /// An operation was attempted on an empty deque.
            case empty
        }
    }
}

// MARK: - Hoisted Variant Error CustomStringConvertible

extension __Deque.Bounded.Error: CustomStringConvertible {
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

extension __Deque.Inline.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .overflow:
            return "deque is full"
        case .empty:
            return "operation attempted on empty deque"
        }
    }
}

extension __Deque.Small.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .empty:
            return "operation attempted on empty deque"
        }
    }
}

// MARK: - Variant Error Typealiases (Nest.Name API)
//
// IMPORTANT: Extensions MUST include `where Element: ~Copyable` to prevent
// implicit Copyable constraint. This is a documented Swift compiler limitation.

extension Deque.Bounded where Element: ~Copyable {
    /// Errors that can occur during bounded deque operations.
    ///
    /// ## Cases
    ///
    /// - ``Deque/Bounded/Error/invalidCapacity``: The requested capacity is invalid (negative).
    /// - ``Deque/Bounded/Error/overflow``: The deque is full and cannot accept more elements.
    /// - ``Deque/Bounded/Error/empty``: An operation was attempted on an empty deque.
    /// - ``Deque/Bounded/Error/bounds(index:count:)``: An index was out of bounds.
    public typealias Error = __Deque.Bounded.Error
}
//
//extension Deque.Inline where Element: ~Copyable {
//    /// Errors that can occur during inline deque operations.
//    ///
//    /// ## Cases
//    ///
//    /// - ``Deque/Inline/Error/overflow``: The deque is full and cannot accept more elements.
//    /// - ``Deque/Inline/Error/empty``: An operation was attempted on an empty deque.
//    public typealias Error = __Deque.Inline.Error
//}
//
//extension Deque.Small where Element: ~Copyable {
//    /// Errors that can occur during small deque operations.
//    ///
//    /// ## Cases
//    ///
//    /// - ``Deque/Small/Error/empty``: An operation was attempted on an empty deque.
//    public typealias Error = __Deque.Small.Error
//}
