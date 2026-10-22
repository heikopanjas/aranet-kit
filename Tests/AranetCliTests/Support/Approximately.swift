import Foundation

/// Compares two floating-point values within an absolute tolerance.
func isApproximately(_ value: Double, _ expected: Double, tolerance: Double = 1e-9) -> Bool {
    return abs(value - expected) <= tolerance
}
