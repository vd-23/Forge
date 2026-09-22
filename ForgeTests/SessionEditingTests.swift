import Testing
import SwiftData
import ForgeCore
@testable import Forge

/// History edits reuse the controller's set operations on a session that has
/// already ended. They must not reopen it, and volume follows the sets.
@Suite @MainActor
struct SessionEditingTests {
    let container = PersistenceController.makeInMemoryContainer()
    var ctx: ModelContext { container.mainContext }

    private func finishedSession() throws -> (WorkoutController, WorkoutSession, WorkoutExercise) {
        let squat = Exercise(name: "Squat", primaryBodyPart: .quads)
        ctx.insert(squat)
        let routine = Routine(name: "Legs")
        routine.items = [RoutineItem(exercise: squat, order: 0)]
        ctx.insert(routine)

        let controller = WorkoutController(context: ctx)
        let session = try controller.start(from: routine)
        let we = session.orderedExercises[0]
        controller.toggleComplete(try #require(controller.addSet(to: we, weightKg: 100, addedWeightKg: nil, reps: 5, rpe: nil, isWarmup: false)))
        controller.toggleComplete(try #require(controller.addSet(to: we, weightKg: 100, addedWeightKg: nil, reps: 5, rpe: nil, isWarmup: false)))
        controller.finish(session)
        return (controller, session, we)
    }

    @Test func editingAFinishedSessionKeepsItFinishedAndInactive() throws {
        let (controller, session, we) = try finishedSession()
        let endedAt = session.endedAt

        let added = try #require(controller.addSet(to: we, weightKg: 110, addedWeightKg: nil, reps: 3, rpe: nil, isWarmup: false))
        controller.toggleComplete(added)
        controller.deleteSet(we.orderedSets[0])

        #expect(session.endedAt == endedAt)
        #expect(!controller.hasActiveSession)
        #expect(WorkoutController(context: ctx).hasActiveSession == false)
    }

    @Test func volumeIsDerivedFromTheEditedSets() throws {
        let (controller, session, we) = try finishedSession()
        #expect(sessionVolumeKg(session.coreInput) == 1000)

        we.orderedSets[0].weightKg = 120
        #expect(sessionVolumeKg(session.coreInput) == 1100)

        let added = try #require(controller.addSet(to: we, weightKg: 100, addedWeightKg: nil, reps: 5, rpe: nil, isWarmup: false))
        #expect(sessionVolumeKg(session.coreInput) == 1100, "an unticked set doesn't count yet")
        controller.toggleComplete(added)
        #expect(sessionVolumeKg(session.coreInput) == 1600)

        controller.deleteSet(added)
        #expect(sessionVolumeKg(session.coreInput) == 1100)
        #expect(we.orderedSets.map(\.order) == [0, 1])
    }
}
