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

// NOTE: Index and Offset typealiases are defined in the Swift.Collection
// conformance in Deque.swift (where Element: Copyable) to avoid triggering
// ~Copyable constraint evaluation on nested types like Deque.Bounded.
//
// This file is intentionally empty - all Index-related typealiases and
// subscripts are defined in Deque.swift to maintain compatibility with
// Swift's ~Copyable constraint propagation rules.
