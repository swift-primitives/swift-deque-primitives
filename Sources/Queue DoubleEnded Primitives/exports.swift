// exports.swift
// `Queue DoubleEnded Primitives` is the ops module AND the [MOD-005] umbrella for
// this package: it re-exports the `Queue DoubleEnded Primitive` type module (which
// also declares the top-level `Deque` typealias) plus the upstream namespace owner,
// so `import Queue_DoubleEnded_Primitives` surfaces the whole package.

@_exported public import Queue_DoubleEnded_Primitive
@_exported public import Queue_Primitives_Core
