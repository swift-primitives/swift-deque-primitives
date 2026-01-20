// MARK: - Root Cause Analysis: Inline Deinit Bug
// Status: BUG CONFIRMED
// Date: 2026-01-20
//
// ============================================================
// CONFIRMED ROOT CAUSE
// ============================================================
//
// The issue is in Deque.Inline deinit (Deque.swift:268-282):
//
// CURRENT (BROKEN):
//     unsafe Swift.withUnsafeBytes(of: _storage) { bytes in
//         let basePtr = unsafe UnsafeMutableRawPointer(mutating: bytes.baseAddress!)
//         ...elementPtr.deinitialize(count: 1)
//     }
//
// The `withUnsafeBytes(of:)` function takes its argument by value for read-only
// access. In the deinit context, this appears to copy the storage, causing
// deinitialize() to run on a COPY rather than the actual storage.
//
// ============================================================
// EVIDENCE
// ============================================================
//
// 1. pop() WORKS - uses _pointerToElement() with withUnsafeMutablePointer(to: &_storage)
// 2. deinit FAILS - uses withUnsafeBytes(of: _storage) with read-only access
// 3. Deque.Small inline path WORKS - same pattern but struct has reference type properties
//
// The key difference: Small has optional reference properties (_heap, _heapPtr) which
// may force the compiler to handle the struct differently, preventing the copy optimization.
//
// ============================================================
// PROPOSED FIX (Deque.swift:268-282)
// ============================================================
//
// Change the deinit to use the same pattern as _pointerToElement():
//
// ```swift
// deinit {
//     let count = _count
//     guard count > 0 else { return }
//
//     let stride = MemoryLayout<Element>.stride
//     unsafe Swift.withUnsafeMutablePointer(to: &_storage) { storagePtr in
//         let basePtr = UnsafeMutableRawPointer(storagePtr)
//         for i in 0..<count {
//             let physicalIndex = (_head + i) % Self.capacity
//             let elementPtr = unsafe (basePtr + physicalIndex * stride)
//                 .assumingMemoryBound(to: Element.self)
//             unsafe elementPtr.deinitialize(count: 1)
//         }
//     }
// }
// ```
//
// ============================================================
// ALTERNATIVE FIX (if &self not allowed in deinit)
// ============================================================
//
// If Swift doesn't allow `&_storage` in deinit, use the same approach as
// _pointerToElement but inline it:
//
// ```swift
// deinit {
//     let count = _count
//     guard count > 0 else { return }
//
//     let stride = MemoryLayout<Element>.stride
//     for i in 0..<count {
//         let physicalIndex = (_head + i) % Self.capacity
//         // Direct pointer computation matching _pointerToElement logic
//         unsafe Swift.withUnsafeMutablePointer(to: &_storage) { storagePtr in
//             let basePtr = UnsafeMutableRawPointer(storagePtr)
//             let elementPtr = unsafe (basePtr + physicalIndex * stride)
//                 .assumingMemoryBound(to: Element.self)
//             unsafe elementPtr.deinitialize(count: 1)
//         }
//     }
// }
// ```
//
