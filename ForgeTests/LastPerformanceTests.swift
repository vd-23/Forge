import Foundation
import SwiftData
import Testing
@testable import Forge

@Suite @MainActor
struct LastPerformanceTests {
    /// Held as a stored property so the container outlives the context.
    let container = PersistenceController.makeInMemoryContainer()
    var ctx: ModelContext { container.mainContext }

    /// weight, reps, isWarmup, isComplete
    typealias SetSpec = (Double, Int, Bool, Bool)

    private func makeExercise(_ name: String = "Bench Press", bodyweight: Bool = false) -> Exercise {
        let exercise = Exercise(name: name, primaryBodyPart: .chest, isBodyweight: bodyweight)
        ctx.insert(exercise)
        return exercise
    }

    @discardableResult
    private func logSession(
        _ exercise: Exercise,
        startedAt: Date,
        finished: Bool = true,
        sets: [SetSpec]
    ) -> WorkoutSession {
        let session = WorkoutSession(startedAt: startedAt, sourceRoutine: nil, sourceRoutineName: "Push")
        session.endedAt = finished ? startedAt.addingTimeInterval(3600) : nil
        ctx.insert(session)

        let workoutExercise = WorkoutExercise(exercise: exercise, exerciseID: exercise.id, order: 0)
        for (index, spec) in sets.enumerated() {
            let set = ExerciseSet(order: index, weightKg: spec.0, reps: spec.1, isWarmup: spec.2)
            set.isComplete = spec.3
            workoutExercise.sets.append(set)
        }
        session.exercises.append(workoutExercise)

        try? ctx.save()
        return session
    }

    private func daysAgo(_ days: Double) -> Date {
        Date.now.addingTimeInterval(-days * 24 * 3600)
    }

    @Test func picksTheMostRecentFinishedSession() {
        let bench = makeExercise()
        logSession(bench, startedAt: daysAgo(7), sets: [(80, 5, false, true)])
        logSession(bench, startedAt: daysAgo(3), sets: [(100, 5, false, true), (100, 4, false, true)])

        let sets = LastPerformance.mostRecentSets(
            ofExerciseID: bench.id, excludingSession: UUID(), in: ctx
        )

        #expect(sets.map(\.weightKg) == [100, 100])
        #expect(sets.map(\.reps) == [5, 4])
    }

    @Test func excludesTheSessionBeingLogged() {
        let bench = makeExercise()
        logSession(bench, startedAt: daysAgo(7), sets: [(80, 5, false, true)])
        let current = logSession(bench, startedAt: daysAgo(0), sets: [(100, 5, false, true)])

        let sets = LastPerformance.mostRecentSets(
            ofExerciseID: bench.id, excludingSession: current.id, in: ctx
        )

        #expect(sets.map(\.weightKg) == [80])
    }

    @Test func ignoresSessionsStillInProgress() {
        let bench = makeExercise()
        logSession(bench, startedAt: daysAgo(7), sets: [(80, 5, false, true)])
        logSession(bench, startedAt: daysAgo(1), finished: false, sets: [(120, 5, false, true)])

        let sets = LastPerformance.mostRecentSets(
            ofExerciseID: bench.id, excludingSession: UUID(), in: ctx
        )

        #expect(sets.map(\.weightKg) == [80])
    }

    @Test func keepsOnlyCompletedWorkingSets() {
        let bench = makeExercise()
        logSession(bench, startedAt: daysAgo(2), sets: [
            (40, 10, true, true),    // warm-up
            (100, 5, false, true),   // working
            (100, 5, false, false),  // logged but never ticked off
        ])

        let sets = LastPerformance.mostRecentSets(
            ofExerciseID: bench.id, excludingSession: UUID(), in: ctx
        )

        #expect(sets.count == 1)
        #expect(sets.first?.weightKg == 100)
    }

    @Test func skipsPastASessionWhereTheExerciseWasOnlyWarmedUp() {
        let bench = makeExercise()
        logSession(bench, startedAt: daysAgo(9), sets: [(85, 5, false, true)])
        logSession(bench, startedAt: daysAgo(2), sets: [(40, 10, true, true)])

        let sets = LastPerformance.mostRecentSets(
            ofExerciseID: bench.id, excludingSession: UUID(), in: ctx
        )

        #expect(sets.map(\.weightKg) == [85])
    }

    @Test func returnsNothingForAnExerciseWithNoHistory() {
        let bench = makeExercise()
        let sets = LastPerformance.mostRecentSets(
            ofExerciseID: bench.id, excludingSession: UUID(), in: ctx
        )

        #expect(sets.isEmpty)
        #expect(LastPerformance.summary(of: sets, isBodyweight: false, unit: .kg) == nil)
    }

    // MARK: Summary formatting

    @Test func summaryGroupsConsecutiveSetsAtTheSameLoad() {
        let bench = makeExercise()
        let session = logSession(bench, startedAt: daysAgo(1), sets: [
            (100, 5, false, true), (100, 5, false, true), (95, 4, false, true),
        ])
        let sets = session.orderedExercises[0].orderedSets

        #expect(LastPerformance.summary(of: sets, isBodyweight: false, unit: .kg)
            == "100 kg × 5, 5 · 95 kg × 4")
    }

    @Test func summaryWritesBodyweightSetsWithoutALoad() {
        let pullUp = makeExercise("Pull-up", bodyweight: true)
        let session = WorkoutSession(startedAt: .now, sourceRoutine: nil, sourceRoutineName: "Pull")
        ctx.insert(session)
        let workoutExercise = WorkoutExercise(exercise: pullUp, exerciseID: pullUp.id, order: 0)
        let plain = ExerciseSet(order: 0, reps: 12)
        let weighted = ExerciseSet(order: 1, addedWeightKg: 10, reps: 8)
        workoutExercise.sets = [plain, weighted]
        session.exercises.append(workoutExercise)

        #expect(LastPerformance.summary(of: [plain, weighted], isBodyweight: true, unit: .kg)
            == "BW × 12 · BW + 10 kg × 8")
    }
}
