//
//  Deque.Property.swift
//  swift-deque-primitives
//
//  Created by Coen ten Thije Boonkkamp on 21/01/2026.
//

import Property_Primitives

extension Deque where Element: Copyable {
    /// Shorthand for `Property_Primitives.Property<Tag, Deque<Element>>`.
    ///
    /// Used for method-based accessors where generic where clauses work.
    public typealias Property<Tag> = Property_Primitives.Property<Tag, Deque<Element>>
}
