import Testing
import SwiftData
import ForgeCore
@testable import Forge

@Suite @MainActor
struct ModelMappingTests {
    @Test func sessionMapsToCoreInputWithOrderedExercisesAndSets() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = container.mainContext

        let squat = Exercise(name: "Squat", primaryBodyPart: .quads, isUnilateral: false)
        context.insert(squat)

        let session = WorkoutSession(startedAt: .now, sourceRoutine: nil, sourceRoutineName: "Legs")
        let we = WorkoutExercise(exercise: squat, exerciseID: squat.id, order: 0)
        let warm = ExerciseSet(order: 0, weightKg: 60, reps: 8, isWarmup: true)
        let work = ExerciseSet(order: 1, weightKg: 120, reps: 5)
        work.isComplete = true
        we.sets = [work, warm]                // deliberately out of order
        session.exercises = [we]
        context.insert(session)
        try context.save()

        let input = session.coreInput
        #expect(input.exercises.count == 1)
        #expect(input.exercises[0].sets.map(\.reps) == [8, 5])   // reordered by `order`
        #expect(input.exercises[0].sets[0].isWarmup == true)
        #expect(input.exercises[0].exercise.id == squat.id)
        #expect(sessionVolumeKg(input) == 600)                   // only the working set
    }
}
