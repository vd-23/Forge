import Foundation
import SwiftData
import Testing
@testable import Forge

@Suite @MainActor
struct SessionDeletionTests {
    /// Held as a stored property so the container outlives the context.
    let container = PersistenceController.makeInMemoryContainer()
    var ctx: ModelContext { container.mainContext }

    @discardableResult
    private func makeSession(routineName: String = "Push") -> WorkoutSession {
        let exercise = Exercise(name: "Bench Press", primaryBodyPart: .chest)
        ctx.insert(exercise)

        let session = WorkoutSession(startedAt: .now, sourceRoutine: nil, sourceRoutineName: routineName)
        session.endedAt = .now
        ctx.insert(session)

        let workoutExercise = WorkoutExercise(exercise: exercise, exerciseID: exercise.id, order: 0)
        for index in 0..<2 {
            let set = ExerciseSet(order: index, weightKg: 100, reps: 5)
            set.isComplete = true
            workoutExercise.sets.append(set)
        }
        session.exercises.append(workoutExercise)

        try? ctx.save()
        return session
    }

    @Test func deletingASessionCascadesToItsExercisesAndSets() throws {
        let session = makeSession()
        #expect(try ctx.fetch(FetchDescriptor<ExerciseSet>()).count == 2)

        ctx.delete(session)
        try ctx.save()

        #expect(try ctx.fetch(FetchDescriptor<WorkoutSession>()).isEmpty)
        #expect(try ctx.fetch(FetchDescriptor<WorkoutExercise>()).isEmpty)
        #expect(try ctx.fetch(FetchDescriptor<ExerciseSet>()).isEmpty)
    }

    /// History is the only thing referencing an exercise's past work, but the
    /// exercise itself is a separate record and must survive.
    @Test func deletingASessionLeavesTheExerciseLibraryIntact() throws {
        let session = makeSession()

        ctx.delete(session)
        try ctx.save()

        #expect(try ctx.fetch(FetchDescriptor<Exercise>()).map(\.name) == ["Bench Press"])
    }

    @Test func deletingOneSessionLeavesTheOthers() throws {
        makeSession(routineName: "Push")
        let pull = makeSession(routineName: "Pull")

        ctx.delete(pull)
        try ctx.save()

        #expect(try ctx.fetch(FetchDescriptor<WorkoutSession>()).map(\.sourceRoutineName) == ["Push"])
        #expect(try ctx.fetch(FetchDescriptor<ExerciseSet>()).count == 2)
    }
}
