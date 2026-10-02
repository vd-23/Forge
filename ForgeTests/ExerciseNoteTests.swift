import Testing
import Foundation
import SwiftData
@testable import Forge

@Suite @MainActor
struct ExerciseNoteTests {
    let container = PersistenceController.makeInMemoryContainer()
    var ctx: ModelContext { container.mainContext }

    private func makeRoutine() -> (Routine, Exercise, Exercise) {
        let curl = Exercise(name: "Curl", primaryBodyPart: .biceps)
        let row = Exercise(name: "Row", primaryBodyPart: .back)
        ctx.insert(curl)
        ctx.insert(row)
        let routine = Routine(name: "Pull")
        routine.items = [RoutineItem(exercise: curl, order: 0)]
        ctx.insert(routine)
        try? ctx.save()
        return (routine, curl, row)
    }

    @Test func startingAWorkoutCarriesTheRoutineNote() throws {
        let (routine, _, _) = makeRoutine()
        routine.orderedItems[0].note = "EZ bar attachment"
        let session = try WorkoutController(context: ctx).start(from: routine)
        #expect(session.orderedExercises[0].note == "EZ bar attachment")
    }

    @Test func settingANoteMidWorkoutSavesItToTheRoutine() throws {
        let (routine, _, _) = makeRoutine()
        let controller = WorkoutController(context: ctx)
        let session = try controller.start(from: routine)

        controller.setNote("  EZ bar attachment \n", for: session.orderedExercises[0])

        #expect(session.orderedExercises[0].note == "EZ bar attachment")
        #expect(routine.orderedItems[0].note == "EZ bar attachment")
    }

    @Test func clearingTheNoteClearsItOnTheRoutineToo() throws {
        let (routine, _, _) = makeRoutine()
        routine.orderedItems[0].note = "old"
        let controller = WorkoutController(context: ctx)
        let session = try controller.start(from: routine)

        controller.setNote("   ", for: session.orderedExercises[0])

        #expect(session.orderedExercises[0].note == nil)
        #expect(routine.orderedItems[0].note == nil)
    }

    @Test func notesAreCappedInLength() throws {
        let (routine, _, _) = makeRoutine()
        let controller = WorkoutController(context: ctx)
        let session = try controller.start(from: routine)

        controller.setNote(String(repeating: "x", count: Limits.maxExerciseNoteLength + 50), for: session.orderedExercises[0])

        #expect(session.orderedExercises[0].note?.count == Limits.maxExerciseNoteLength)
    }

    @Test func aNoteOnAnAddedExerciseFollowsItIntoTheRoutineWhenAccepted() throws {
        let (routine, _, row) = makeRoutine()
        let controller = WorkoutController(context: ctx)
        let session = try controller.start(from: routine)
        controller.addExercise(row, to: session)
        let added = try #require(session.orderedExercises.last)

        controller.setNote("Neutral grip", for: added)
        #expect(routine.items.count == 1)   // not in the routine yet

        controller.updateRoutine(routine, toMatch: RoutineSync.plan(from: session))
        #expect(routine.orderedItems.last?.note == "Neutral grip")
    }

    @Test func backupKeepsNotes() throws {
        let (routine, _, _) = makeRoutine()
        routine.orderedItems[0].note = "EZ bar"
        let controller = WorkoutController(context: ctx)
        let session = try controller.start(from: routine)
        controller.toggleComplete(try #require(session.orderedExercises[0].orderedSets.first ?? controller.addSet(
            to: session.orderedExercises[0], weightKg: 20, addedWeightKg: nil, reps: 10, rpe: nil, isWarmup: false)))
        controller.finish(session)

        let suite = "ExerciseNoteTests-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        let data = try BackupCoder.export(from: ctx, defaults: defaults)

        let target = PersistenceController.makeInMemoryContainer()
        _ = try BackupCoder.restore(data, into: target.mainContext, defaults: defaults)
        let restored = try target.mainContext.fetch(FetchDescriptor<Routine>())
        #expect(restored.first?.orderedItems.first?.note == "EZ bar")
        let sessions = try target.mainContext.fetch(FetchDescriptor<WorkoutSession>())
        #expect(sessions.first?.orderedExercises.first?.note == "EZ bar")
    }
}
