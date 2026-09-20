import Foundation
import Testing
import SwiftData
@testable import Forge

@Suite @MainActor
struct RoutineSyncTests {
    let container = PersistenceController.makeInMemoryContainer()
    var ctx: ModelContext { container.mainContext }

    private func setup() throws -> (WorkoutController, Routine, WorkoutSession, [Exercise]) {
        let squat = Exercise(name: "Squat", primaryBodyPart: .quads)
        let curl = Exercise(name: "Curl", primaryBodyPart: .biceps)
        let row = Exercise(name: "Row", primaryBodyPart: .back)
        for exercise in [squat, curl, row] { ctx.insert(exercise) }

        let routine = Routine(name: "Day A")
        routine.items = [
            RoutineItem(exercise: squat, order: 0, targetSets: 3, targetRepMin: 5, targetRepMax: 5),
            RoutineItem(exercise: curl, order: 1, targetSets: 2),
        ]
        ctx.insert(routine)
        let controller = WorkoutController(context: ctx)
        let session = try controller.start(from: routine)
        return (controller, routine, session, [squat, curl, row])
    }

    @Test func noChangesMeansNoDiff() throws {
        let (_, routine, session, _) = try setup()
        #expect(RoutineSync.diff(plan: RoutineSync.plan(from: session), against: routine) == nil)
    }

    @Test func addingRemovingAndReorderingAreReported() throws {
        let (controller, routine, session, exercises) = try setup()
        controller.addExercise(exercises[2], to: session)                       // + Row
        controller.removeExercise(session.orderedExercises[1])                  // − Curl
        controller.moveExercises(in: session, from: IndexSet(integer: 1), to: 0) // Row before Squat

        let diff = try #require(RoutineSync.diff(plan: RoutineSync.plan(from: session), against: routine))
        #expect(diff.added == ["Row"])
        #expect(diff.removed == ["Curl"])
        #expect(diff.reordered == false, "only one shared exercise remains, so no relative order to break")
        #expect(session.orderedExercises.map(\.order) == [0, 1])
    }

    @Test func reorderAloneIsDetected() throws {
        let (controller, routine, session, _) = try setup()
        controller.moveExercises(in: session, from: IndexSet(integer: 0), to: 2)
        let diff = try #require(RoutineSync.diff(plan: RoutineSync.plan(from: session), against: routine))
        #expect(diff.added.isEmpty && diff.removed.isEmpty && diff.reordered)
    }

    @Test func skippedExerciseIsNotARemoval() throws {
        // Finish prunes exercises with nothing logged; the plan is captured first.
        let (controller, routine, session, _) = try setup()
        controller.toggleComplete(session.orderedExercises[0].orderedSets[0])
        let plan = RoutineSync.plan(from: session)
        controller.finish(session)
        #expect(session.orderedExercises.count == 1)
        #expect(RoutineSync.diff(plan: plan, against: routine) == nil)
    }

    @Test func archivedRoutineNeverPrompts() throws {
        let (controller, routine, session, exercises) = try setup()
        controller.addExercise(exercises[2], to: session)
        routine.isArchived = true
        #expect(RoutineSync.diff(plan: RoutineSync.plan(from: session), against: routine) == nil)
    }

    @Test func updateRoutineKeepsTargetsAndRewritesOrder() throws {
        let (controller, routine, session, exercises) = try setup()
        controller.addExercise(exercises[2], to: session)
        controller.removeExercise(session.orderedExercises[1])
        controller.moveExercises(in: session, from: IndexSet(integer: 1), to: 0)

        controller.updateRoutine(routine, toMatch: RoutineSync.plan(from: session))

        let items = routine.orderedItems
        #expect(items.map { $0.exercise?.name } == ["Row", "Squat"])
        #expect(items.map(\.order) == [0, 1])
        #expect(items[1].targetSets == 3 && items[1].targetRepMin == 5, "Squat's targets survive")
        #expect(items[0].targetSets == nil, "Row was added mid-workout with no target")
        #expect(routine.items.count == 2, "Curl's item is gone")
    }
}
