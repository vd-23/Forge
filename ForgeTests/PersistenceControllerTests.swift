import Testing
import SwiftData
@testable import Forge

@Suite @MainActor
struct PersistenceControllerTests {
    @Test func inMemoryContainerInsertsAndFetches() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = container.mainContext

        let exercise = Exercise(name: "Back Squat", primaryBodyPart: .quads)
        context.insert(exercise)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Exercise>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.name == "Back Squat")
        #expect(fetched.first?.primaryBodyPart == .quads)
    }

    @Test func deletingASessionCascadesToExercisesAndSets() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = container.mainContext

        let exercise = Exercise(name: "Bench", primaryBodyPart: .chest)
        let session = WorkoutSession(sourceRoutine: nil, sourceRoutineName: "Ad hoc")
        let we = WorkoutExercise(exercise: exercise, exerciseID: exercise.id, order: 0)
        let set = ExerciseSet(order: 0, weightKg: 100, reps: 5)
        we.sets.append(set)
        session.exercises.append(we)
        context.insert(exercise)
        context.insert(session)
        try context.save()

        context.delete(session)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<WorkoutExercise>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<ExerciseSet>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Exercise>()).count == 1) // exercise survives
    }
}
