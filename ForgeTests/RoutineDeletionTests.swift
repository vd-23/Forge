import Testing
import SwiftData
@testable import Forge

@Suite @MainActor
struct RoutineDeletionTests {
    let container = PersistenceController.makeInMemoryContainer()
    var ctx: ModelContext { container.mainContext }

    @Test func unusedRoutineCanBeHardDeleted() throws {
        let routine = Routine(name: "Push")
        ctx.insert(routine)
        try ctx.save()
        #expect(RoutineDeletion.canHardDelete(routine) == true)
    }

    @Test func routineWithAPastSessionCannotBeHardDeleted() throws {
        let routine = Routine(name: "Push")
        let session = WorkoutSession(sourceRoutine: routine, sourceRoutineName: routine.name)
        session.endedAt = .now
        ctx.insert(routine)
        ctx.insert(session)
        try ctx.save()
        #expect(RoutineDeletion.canHardDelete(routine) == false)
    }

    @Test func aSessionFromADifferentRoutineDoesNotBlockDeletion() throws {
        let kept = Routine(name: "Push")
        let other = Routine(name: "Pull")
        let session = WorkoutSession(sourceRoutine: other, sourceRoutineName: other.name)
        session.endedAt = .now
        ctx.insert(kept)
        ctx.insert(other)
        ctx.insert(session)
        try ctx.save()
        #expect(RoutineDeletion.canHardDelete(kept) == true)
    }
}
