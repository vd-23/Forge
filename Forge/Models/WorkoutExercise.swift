import Foundation
import SwiftData

@Model
final class WorkoutExercise {
    var session: WorkoutSession?
    var exercise: Exercise?
    /// Denormalised copy of `exercise.id` for predicate-friendly history queries.
    var exerciseID: UUID
    var order: Int
    var targetSets: Int?
    var targetRepMin: Int?
    var targetRepMax: Int?
    var restSeconds: Int?

    @Relationship(deleteRule: .cascade, inverse: \ExerciseSet.workoutExercise)
    var sets: [ExerciseSet] = []

    init(
        exercise: Exercise,
        exerciseID: UUID,
        order: Int,
        targetSets: Int? = nil,
        targetRepMin: Int? = nil,
        targetRepMax: Int? = nil,
        restSeconds: Int? = nil
    ) {
        self.exercise = exercise
        self.exerciseID = exerciseID
        self.order = order
        self.targetSets = targetSets
        self.targetRepMin = targetRepMin
        self.targetRepMax = targetRepMax
        self.restSeconds = restSeconds
    }

    var orderedSets: [ExerciseSet] {
        sets.sorted { $0.order < $1.order }
    }
}
