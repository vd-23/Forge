import Foundation

/// The best estimated 1RM among a given exercise's working sets in one session.
/// Returns `nil` when that exercise has no qualifying sets.
public func sessionBestE1RM(_ session: SessionInput, exerciseID: UUID) -> Double? {
    let estimates = session.exercises
        .filter { $0.exercise.id == exerciseID }
        .flatMap { workingSets($0.sets) }
        .compactMap { set -> Double? in
            guard let weight = set.weightKg else { return nil }
            return estimatedOneRepMax(weightKg: weight, reps: set.reps)
        }
    return estimates.max()
}
