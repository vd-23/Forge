import Foundation
import ForgeCore

extension Exercise {
    var coreInput: ExerciseInput {
        ExerciseInput(id: id, isBodyweight: isBodyweight, isUnilateral: isUnilateral)
    }
}

extension ExerciseSet {
    var coreInput: SetInput {
        SetInput(
            weightKg: weightKg,
            addedWeightKg: addedWeightKg,
            reps: reps,
            rpe: rpe,
            isWarmup: isWarmup,
            isComplete: isComplete
        )
    }
}

extension WorkoutExercise {
    /// Uses the live `exercise` relationship for flags; falls back to a plain
    /// non-bodyweight exercise if the relationship is somehow missing.
    var coreInput: WorkoutExerciseInput {
        let exerciseInput = exercise?.coreInput
            ?? ExerciseInput(id: exerciseID, isBodyweight: false, isUnilateral: false)
        return WorkoutExerciseInput(
            exercise: exerciseInput,
            sets: orderedSets.map(\.coreInput)
        )
    }
}

extension WorkoutSession {
    var coreInput: SessionInput {
        SessionInput(
            id: id,
            startedAt: startedAt,
            endedAt: endedAt,
            exercises: orderedExercises.map(\.coreInput)
        )
    }
}
