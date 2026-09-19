import Foundation
import SwiftData

@Model
final class ExerciseSet {
    var workoutExercise: WorkoutExercise?
    var order: Int
    var weightKg: Double?
    var addedWeightKg: Double?
    var reps: Int
    var rpe: Double?
    var isWarmup: Bool
    var isComplete: Bool
    var completedAt: Date?

    init(
        order: Int,
        weightKg: Double? = nil,
        addedWeightKg: Double? = nil,
        reps: Int,
        rpe: Double? = nil,
        isWarmup: Bool = false
    ) {
        self.order = order
        self.weightKg = weightKg
        self.addedWeightKg = addedWeightKg
        self.reps = reps
        self.rpe = rpe
        self.isWarmup = isWarmup
        self.isComplete = false
        self.completedAt = nil
    }
}
