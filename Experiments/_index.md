# Experiments Index

Package audit experiments for `swift-deque-primitives`.

## Triage Status

Per [EXP-002a] Experiment Triage, the original discovery audit experiments tested **implementation correctness** (unit test territory), not **Swift language capabilities** (experiment territory).

### Migrated to Unit Tests

The following discovery audit experiments have been migrated to unit tests in `Tests/Deque Primitives Tests/`:

| Original Directory | Unit Test File | Subject |
|-------------------|----------------|---------|
| deque-noncopyable-elements | `Deque.NonCopyable Tests.swift` | ~Copyable element support |
| deque-conditional-copyable | `Deque.ConditionalCopyable Tests.swift` | Conditional Copyable conformance |
| deque-deinit-order | `Deque.DeinitOrder Tests.swift` | Deinit order (front-to-back) |
| deque-sendable-conformance | `Deque.Sendable Tests.swift` | Sendable conformance |
| deque-small-spill | `Deque.Small.Spill Tests.swift` | Small inline-to-heap spill |

### Valid Experiments

| Directory | Purpose | Date | Toolchain | Status |
|-----------|---------|------|-----------|--------|
| deque-inline-deinit-investigation | Investigate Swift compiler behavior with withUnsafeBytes in deinit | 2026-01-20 | Swift 6.2 | BUG CONFIRMED |

## Bug Found and Fixed: Deque.Inline Deinit Memory Leak

**Location**: `Deque.swift` - `Inline` struct

**Symptom**: `Deque.Inline` deinit did not call element deinitializers. Elements were leaked when the deque went out of scope.

**Root Cause**: Swift compiler bug where deinit element cleanup doesn't work correctly for `~Copyable` structs that contain **only value types**. The `withUnsafeBytes(of:)` pattern works in `Deque.Small` (which has `_heap: Storage?`) but fails in `Deque.Inline` (which had only value type properties).

**Fix Applied**: Added `_deinitWorkaround: AnyObject? = nil` property to `Deque.Inline`. This triggers correct deinit codegen without changing observable behavior.

**Verification**:
- `UnsafeRawPointer?` does NOT work - must be a reference type
- All 78 package tests pass (45 original + 33 migrated)
- All 9 investigation tests pass

See `deque-inline-deinit-investigation/` for full analysis.

**TODO**: File Swift compiler bug report and remove workaround when fixed.

## Summary of Discovery Audit Findings

All claims verified and now covered by unit tests:

| Claim | Status | Unit Test Coverage |
|-------|--------|-------------------|
| CLAIM-004: ~Copyable support | VERIFIED | `Deque.NonCopyable Tests.swift` |
| CLAIM-006: Sendable conformance | VERIFIED | `Deque.Sendable Tests.swift` |
| CLAIM-007: Conditional Copyable | VERIFIED | `Deque.ConditionalCopyable Tests.swift` |
| CLAIM-009: Small spill | VERIFIED | `Deque.Small.Spill Tests.swift` |
| ASSUMP-005: Deinit order | **FIXED** | `Deque.DeinitOrder Tests.swift` |
