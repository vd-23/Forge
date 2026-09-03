import Foundation

/// Estimated one-rep max using the Epley formula: `weight * (1 + reps / 30)`.
///
/// A single rep returns the weight unchanged. Non-positive `reps` or `weightKg`
/// return `0` — there is no meaningful estimate to make.
public func estimatedOneRepMax(weightKg: Double, reps: Int) -> Double {
    guard weightKg > 0, reps > 0 else { return 0 }
    if reps == 1 { return weightKg }
    return weightKg * (1 + Double(reps) / 30)
}
