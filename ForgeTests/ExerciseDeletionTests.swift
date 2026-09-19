import Testing
import SwiftData
@testable import Forge

@Suite @MainActor
struct ExerciseDeletionTests {
    /// Held as a stored property so the container outlives the context.
    /// A temporary (`makeInMemoryContainer().mainContext`) is deallocated
    /// out from under its context and crashes on first store access.
    let container = PersistenceController.makeInMemoryContainer()
    var ctx: ModelContext { container.mainContext }

    @Test func unreferencedExerciseCanBeHardDeleted() throws {
        let ex = Exercise(name: "Curl", primaryBodyPart: .biceps)
        ctx.insert(ex)
        try ctx.save()
        #expect(ExerciseDeletion.canHardDelete(ex) == true)
    }

    @Test func exerciseUsedByARoutineCannotBeHardDeleted() throws {
        let ex = Exercise(name: "Squat", primaryBodyPart: .quads)
        let routine = Routine(name: "Legs")
        let item = RoutineItem(exercise: ex, order: 0)
        routine.items.append(item)
        ctx.insert(ex)
        ctx.insert(routine)
        try ctx.save()
        #expect(ExerciseDeletion.canHardDelete(ex) == false)
    }

    @Test func exerciseUsedByAPastWorkoutCannotBeHardDeleted() throws {
        let ex = Exercise(name: "Bench", primaryBodyPart: .chest)
        let session = WorkoutSession(sourceRoutine: nil, sourceRoutineName: "x")
        let we = WorkoutExercise(exercise: ex, exerciseID: ex.id, order: 0)
        session.exercises.append(we)
        ctx.insert(ex)
        ctx.insert(session)
        try ctx.save()
        #expect(ExerciseDeletion.canHardDelete(ex) == false)
    }
}
