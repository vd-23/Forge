import Foundation
import Testing
@testable import ForgeCore

@Suite struct VolumeTests {
    let barbell = ExerciseInput(id: UUID(), isBodyweight: false, isUnilateral: false)
    let unilateral = ExerciseInput(id: UUID(), isBodyweight: false, isUnilateral: true)
    let bodyweight = ExerciseInput(id: UUID(), isBodyweight: true, isUnilateral: false)

    @Test func standardSetVolumeIsWeightTimesReps() {
        let set = SetInput(weightKg: 100, reps: 5)
        #expect(setVolumeKg(set, exercise: barbell) == 500)
    }

    @Test func unilateralSetVolumeIsDoubled() {
        let set = SetInput(weightKg: 20, reps: 10)
        #expect(setVolumeKg(set, exercise: unilateral) == 400)
    }

    @Test func bodyweightSetsContributeNoVolume() {
        let set = SetInput(weightKg: nil, addedWeightKg: 20, reps: 12)
        #expect(setVolumeKg(set, exercise: bodyweight) == 0)
    }

    @Test func nilWeightOnANonBodyweightExerciseIsZero() {
        let set = SetInput(weightKg: nil, reps: 5)
        #expect(setVolumeKg(set, exercise: barbell) == 0)
    }

    @Test func workingSetsDropsWarmupsAndIncomplete() {
        let sets = [
            SetInput(weightKg: 40, reps: 10, isWarmup: true, isComplete: true),
            SetInput(weightKg: 100, reps: 5, isComplete: true),
            SetInput(weightKg: 100, reps: 5, isComplete: false),
        ]
        #expect(workingSets(sets).count == 1)
        #expect(workingSets(sets).first?.weightKg == 100)
    }

    @Test func sessionVolumeSumsWorkingSetsAcrossExercises() {
        let session = SessionInput(
            id: UUID(),
            startedAt: .now,
            endedAt: .now,
            exercises: [
                WorkoutExerciseInput(exercise: barbell, sets: [
                    SetInput(weightKg: 60, reps: 10, isWarmup: true),
                    SetInput(weightKg: 100, reps: 5),
                    SetInput(weightKg: 100, reps: 5),
                ]),
                WorkoutExerciseInput(exercise: unilateral, sets: [
                    SetInput(weightKg: 20, reps: 10),
                ]),
                WorkoutExerciseInput(exercise: bodyweight, sets: [
                    SetInput(weightKg: nil, reps: 15),
                ]),
            ]
        )
        #expect(sessionVolumeKg(session) == 1400)
    }
}
