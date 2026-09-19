import Foundation
import Testing
@testable import ForgeCore

@Suite struct ProgressionTests {
    let squatID = UUID()

    func session(sets: [SetInput], exerciseID: UUID) -> SessionInput {
        let exercise = ExerciseInput(id: exerciseID, isBodyweight: false, isUnilateral: false)
        return SessionInput(
            id: UUID(), startedAt: .now, endedAt: .now,
            exercises: [WorkoutExerciseInput(exercise: exercise, sets: sets)]
        )
    }

    @Test func picksTheHighestEstimateAcrossWorkingSets() {
        let s = session(sets: [
            SetInput(weightKg: 140, reps: 1),          // 140
            SetInput(weightKg: 120, reps: 5),          // 140.0
            SetInput(weightKg: 100, reps: 10),         // 133.3
            SetInput(weightKg: 200, reps: 5, isWarmup: true), // excluded
        ], exerciseID: squatID)
        let best = sessionBestE1RM(s, exerciseID: squatID)
        #expect(best != nil)
        #expect(abs(best! - 140) < 0.001)
    }

    @Test func nilWhenTheExerciseHasNoWorkingSets() {
        let s = session(sets: [SetInput(weightKg: 100, reps: 5, isWarmup: true)], exerciseID: squatID)
        #expect(sessionBestE1RM(s, exerciseID: squatID) == nil)
        #expect(sessionBestE1RM(s, exerciseID: UUID()) == nil)
    }
}
