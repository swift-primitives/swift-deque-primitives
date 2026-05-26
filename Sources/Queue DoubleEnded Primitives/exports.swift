// exports.swift
// `Queue DoubleEnded Primitives` is the ops module AND the [MOD-005] umbrella for
// this package: it re-exports the `Queue DoubleEnded Primitive` type module plus the
// upstream namespace owner, so `import Queue_DoubleEnded_Primitives` surfaces the
// Queue.DoubleEnded discipline. The top-level `Deque` typealias lives in the
// package-name-facing `Deque Primitives` module.

@_exported public import Queue_DoubleEnded_Primitive
@_exported public import Queue_Primitives_Core
