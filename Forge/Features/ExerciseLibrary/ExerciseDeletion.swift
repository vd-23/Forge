import Foundation
import SwiftData

/// Rule from the PRD: an exercise referenced by history is archived, not deleted.
enum ExerciseDeletion {
    static func canHardDelete(_ exercise: Exercise) -> Bool {
        exercise.routineItems.isEmpty && workoutExerciseCount(for: exercise) == 0
    }

    private static func workoutExerciseCount(for exercise: Exercise) -> Int {
        guard let context = exercise.modelContext else { return 0 }
        let id = exercise.id
        let descriptor = FetchDescriptor<WorkoutExercise>(
            predicate: #Predicate { $0.exerciseID == id }
        )
        return (try? context.fetchCount(descriptor)) ?? 0
    }
}
