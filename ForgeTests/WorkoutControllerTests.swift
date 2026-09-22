import Testing
import SwiftData
@testable import Forge

@Suite @MainActor
struct WorkoutControllerTests {
    let container = PersistenceController.makeInMemoryContainer()
    var ctx: ModelContext { container.mainContext }

    private func makeRoutine(name: String = "Day A") -> (Routine, Exercise, Exercise) {
        let squat = Exercise(name: "Squat", primaryBodyPart: .quads, defaultRestSeconds: 180)
        let curl = Exercise(name: "Curl", primaryBodyPart: .biceps)
        ctx.insert(squat)
        ctx.insert(curl)

        let routine = Routine(name: name)
        routine.items = [
            RoutineItem(exercise: squat, order: 0, targetSets: 3, targetRepMin: 5, targetRepMax: 5),
            RoutineItem(exercise: curl, order: 1, targetRestSeconds: 60),
        ]
        ctx.insert(routine)
        try? ctx.save()
        return (routine, squat, curl)
    }

    @Test func startFromRoutineCopiesItemsInOrderWithResolvedRest() throws {
        let (routine, _, _) = makeRoutine()
        let controller = WorkoutController(context: ctx)

        let session = try controller.start(from: routine)

        #expect(controller.hasActiveSession)
        #expect(session.sourceRoutineName == "Day A")
        #expect(session.orderedExercises.map { $0.exercise?.name } == ["Squat", "Curl"])
        #expect(session.orderedExercises[0].restSeconds == 180)   // exercise default
        #expect(session.orderedExercises[0].targetSets == 3)
        #expect(session.orderedExercises[1].restSeconds == 60)    // routine item override
    }

    @Test func cannotStartASecondSessionWhileOneIsActive() throws {
        let (routine, _, _) = makeRoutine()
        let controller = WorkoutController(context: ctx)
        _ = try controller.start(from: routine)

        #expect(throws: WorkoutController.WorkoutError.sessionAlreadyActive) {
            _ = try controller.start(from: routine)
        }
    }

    @Test func controllerRecoversAnActiveSessionOnInit() throws {
        let (routine, _, _) = makeRoutine()
        _ = try WorkoutController(context: ctx).start(from: routine)

        let fresh = WorkoutController(context: ctx)
        #expect(fresh.hasActiveSession)
    }

    @Test func addSetAppendsWithIncrementingOrderAndStaysIncomplete() throws {
        let (routine, _, _) = makeRoutine()
        let controller = WorkoutController(context: ctx)
        let session = try controller.start(from: routine)
        let we = session.orderedExercises[0]

        // The routine plans 3 squat sets, so those already exist.
        let planned = we.orderedSets.count
        let first = try #require(controller.addSet(to: we, weightKg: 100, addedWeightKg: nil, reps: 5, rpe: nil, isWarmup: false))
        let second = try #require(controller.addSet(to: we, weightKg: 100, addedWeightKg: nil, reps: 5, rpe: 8, isWarmup: false))

        #expect(planned == 3)
        #expect(first.order == 3)
        #expect(second.order == 4)
        #expect(we.orderedSets.count == 5)
        #expect(we.orderedSets.allSatisfy { !$0.isComplete })
    }

    @Test func startPrefillsPlannedSetsFromLastTime() throws {
        let (routine, _, _) = makeRoutine()
        let controller = WorkoutController(context: ctx)

        let earlier = try controller.start(from: routine)
        let squat = earlier.orderedExercises[0]
        for (index, set) in squat.orderedSets.enumerated() {
            set.weightKg = 100 + Double(index) * 5
            controller.toggleComplete(set)
        }
        controller.finish(earlier)

        let session = try controller.start(from: routine)
        let sets = session.orderedExercises[0].orderedSets
        #expect(sets.map(\.weightKg) == [100, 105, 110])
        #expect(sets.map(\.reps) == [5, 5, 5])
        #expect(sets.allSatisfy { !$0.isComplete })
        // The curl has no target count and no history, so nothing is laid out.
        #expect(session.orderedExercises[1].sets.isEmpty)
    }

    @Test func toggleCompleteStampsAndClearsCompletedAt() throws {
        let (routine, _, _) = makeRoutine()
        let controller = WorkoutController(context: ctx)
        let session = try controller.start(from: routine)
        let set = try #require(controller.addSet(to: session.orderedExercises[0], weightKg: 60, addedWeightKg: nil,
                                    reps: 10, rpe: nil, isWarmup: false))

        controller.toggleComplete(set)
        #expect(set.isComplete)
        #expect(set.completedAt != nil)

        controller.toggleComplete(set)
        #expect(!set.isComplete)
        #expect(set.completedAt == nil)
    }

    @Test func addExerciseMidWorkoutAppendsAtTheEnd() throws {
        let (routine, _, _) = makeRoutine()
        let extra = Exercise(name: "Plank", primaryBodyPart: .core)
        ctx.insert(extra)
        let controller = WorkoutController(context: ctx)
        let session = try controller.start(from: routine)

        controller.addExercise(extra, to: session)

        #expect(session.orderedExercises.count == 3)
        #expect(session.orderedExercises.last?.exercise?.name == "Plank")
        #expect(session.orderedExercises.last?.order == 2)
    }

    @Test func finishStampsEndAndUpdatesRoutineLastPerformed() throws {
        let (routine, _, _) = makeRoutine()
        let controller = WorkoutController(context: ctx)
        let session = try controller.start(from: routine)
        let set = try #require(controller.addSet(to: session.orderedExercises[0], weightKg: 100, addedWeightKg: nil,
                                    reps: 5, rpe: nil, isWarmup: false))
        controller.toggleComplete(set)

        let summary = try #require(controller.finish(session))

        #expect(session.endedAt != nil)
        #expect(controller.hasActiveSession == false)
        #expect(routine.lastPerformedAt != nil)
        #expect(summary.workingSetCount == 1)
        #expect(summary.totalVolumeKg == 500)
    }

    @Test func finishDoesNotTreatTheSessionAsItsOwnHistory() throws {
        let (routine, _, _) = makeRoutine()
        let controller = WorkoutController(context: ctx)
        let session = try controller.start(from: routine)
        let set = try #require(controller.addSet(to: session.orderedExercises[0], weightKg: 100, addedWeightKg: nil,
                                    reps: 5, rpe: nil, isWarmup: false))
        controller.toggleComplete(set)

        let summary = try #require(controller.finish(session))

        // A first-ever squat is a PR in all three categories; if the session
        // leaked into its own history, none of them would register.
        #expect(summary.prHits.count == 3)
    }

    @Test func deletingASetRenumbersTheOnesAfterIt() throws {
        let (routine, _, _) = makeRoutine()
        let controller = WorkoutController(context: ctx)
        let session = try controller.start(from: routine)
        let squat = session.orderedExercises[0]

        #expect(squat.orderedSets.map(\.order) == [0, 1, 2])
        controller.deleteSet(squat.orderedSets[1])

        #expect(squat.orderedSets.map(\.order) == [0, 1])
    }

    @Test func finishDropsSetsThatWereNeverTickedOff() throws {
        let (routine, _, _) = makeRoutine()
        let controller = WorkoutController(context: ctx)
        let session = try controller.start(from: routine)
        let squat = session.orderedExercises[0]

        let done = try #require(controller.addSet(to: squat, weightKg: 100, addedWeightKg: nil, reps: 5, rpe: nil, isWarmup: false))
        controller.addSet(to: squat, weightKg: 100, addedWeightKg: nil, reps: 5, rpe: nil, isWarmup: false)
        controller.toggleComplete(done)

        let summary = try #require(controller.finish(session))

        #expect(squat.orderedSets.count == 1)
        #expect(summary.workingSetCount == 1)
    }

    @Test func finishDropsExercisesThatWerePlannedButNeverWorked() throws {
        let (routine, _, _) = makeRoutine()
        let controller = WorkoutController(context: ctx)
        let session = try controller.start(from: routine)
        let set = try #require(controller.addSet(to: session.orderedExercises[0], weightKg: 100, addedWeightKg: nil,
                                    reps: 5, rpe: nil, isWarmup: false))
        controller.toggleComplete(set)

        controller.finish(session)

        #expect(session.orderedExercises.map { $0.exercise?.name } == ["Squat"])
    }

    @Test func finishDiscardsASessionWithNothingLogged() throws {
        let (routine, _, _) = makeRoutine()
        let controller = WorkoutController(context: ctx)
        let session = try controller.start(from: routine)
        controller.addSet(to: session.orderedExercises[0], weightKg: 100, addedWeightKg: nil,
                          reps: 5, rpe: nil, isWarmup: false)

        let summary = controller.finish(session)

        #expect(summary == nil)
        #expect(controller.hasActiveSession == false)
        #expect(try ctx.fetch(FetchDescriptor<WorkoutSession>()).isEmpty)
    }

    @Test func aTickedWarmupIsEnoughToKeepTheSession() throws {
        let (routine, _, _) = makeRoutine()
        let controller = WorkoutController(context: ctx)
        let session = try controller.start(from: routine)
        let warmup = try #require(controller.addSet(to: session.orderedExercises[0], weightKg: 40, addedWeightKg: nil,
                                       reps: 10, rpe: nil, isWarmup: true))
        controller.toggleComplete(warmup)

        let summary = try #require(controller.finish(session))

        #expect(summary.workingSetCount == 0)   // warm-ups never count as working sets
        #expect(try ctx.fetch(FetchDescriptor<WorkoutSession>()).count == 1)
    }

    @Test func discardDeletesTheSession() throws {
        let (routine, _, _) = makeRoutine()
        let controller = WorkoutController(context: ctx)
        let session = try controller.start(from: routine)

        controller.discard(session)

        #expect(controller.hasActiveSession == false)
        #expect(try ctx.fetch(FetchDescriptor<WorkoutSession>()).isEmpty)
    }
}
