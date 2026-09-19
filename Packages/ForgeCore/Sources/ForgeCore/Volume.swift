import Foundation

/// Sets that count toward volume, 1RM, and PRs: completed and not a warmup.
public func workingSets(_ sets: [SetInput]) -> [SetInput] {
    sets.filter { $0.isComplete && !$0.isWarmup }
}

/// Training volume for one set, in kilograms.
///
/// - Bodyweight exercises contribute `0` (they are tracked by reps, not load).
/// - Unilateral exercises double the volume, since the logged reps are per side.
/// - A `nil` `weightKg` on a non-bodyweight exercise contributes `0`.
public func setVolumeKg(_ set: SetInput, exercise: ExerciseInput) -> Double {
    guard !exercise.isBodyweight, let weight = set.weightKg else { return 0 }
    let sides = exercise.isUnilateral ? 2.0 : 1.0
    return weight * Double(set.reps) * sides
}

/// Total working-set volume across every exercise in the session, in kilograms.
public func sessionVolumeKg(_ session: SessionInput) -> Double {
    session.exercises.reduce(0) { runningTotal, workoutExercise in
        let exerciseVolume = workingSets(workoutExercise.sets).reduce(0) { setTotal, set in
            setTotal + setVolumeKg(set, exercise: workoutExercise.exercise)
        }
        return runningTotal + exerciseVolume
    }
}
