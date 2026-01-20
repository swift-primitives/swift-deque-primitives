// Supplementary test: Does withUnsafeBytes(of:) work correctly in deinit for small structs?

// This tests the hypothesis that withUnsafeBytes(of:) in deinit might copy
// the value rather than access it in place.

struct SmallStruct: ~Copyable {
    var value: Int = 42
    var storage: (Int, Int, Int, Int) = (0, 0, 0, 0)
    
    deinit {
        print("SmallStruct deinit - value: \(value)")
        unsafe Swift.withUnsafeBytes(of: storage) { bytes in
            print("  withUnsafeBytes address: \(bytes.baseAddress!)")
        }
    }
}

struct LargerStruct: ~Copyable {
    var value: Int = 42
    var storage: (Int, Int, Int, Int, Int, Int, Int, Int) = (0, 0, 0, 0, 0, 0, 0, 0)
    var extra: Int? = nil  // Adding optional to match Small's structure
    
    deinit {
        print("LargerStruct deinit - value: \(value)")
        unsafe Swift.withUnsafeBytes(of: storage) { bytes in
            print("  withUnsafeBytes address: \(bytes.baseAddress!)")
        }
    }
}

// Note: This test is informational - the actual fix needs to be in Deque.swift
