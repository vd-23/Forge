import Foundation
import ForgeCore
import SwiftData
import Testing
@testable import Forge

@Suite @MainActor
struct WorkoutSummaryTests {
    /// Held as a stored property so the container outlives the context.
    let container = PersistenceController.makeInMemoryContainer()
    var ctx: ModelContext { container.mainContext }

    /// weight, reps, isWarmup, isComplete
    typealias SetSpec = (Double, Int, Bool, Bool)

    private func makeSession(
        startedAt: Date,
        finished: Bool,
        entries: [(Exercise, [SetSpec])]
    ) -> WorkoutSession {
        let session = WorkoutSession(startedAt: startedAt, sourceRoutine: nil, sourceRoutineName: "Push")
        session.endedAt = finished ? startedAt.addingTimeInterval(3600) : nil
        ctx.insert(session)

        for (order, entry) in entries.enumerated() {
            let workoutExercise = WorkoutExercise(exercise: entry.0, exerciseID: entry.0.id, order: order)
            for (index, spec) in entry.1.enumerated() {
                let set = ExerciseSet(order: index, weightKg: spec.0, reps: spec.1, isWarmup: spec.2)
                set.isComplete = spec.3
                workoutExercise.sets.append(set)
            }
            session.exercises.append(workoutExercise)
        }

        try? ctx.save()
        return session
    }

    private func kinds(_ summary: WorkoutSummary, for exerciseName: String) -> Set<PRKind> {
        Set(summary.prHits.filter { $0.exerciseName == exerciseName }.map(\.kind))
    }

    @Test func summarisesVolumeSetsBodyPartsAndPersonalRecords() {
        let bench = Exercise(name: "Bench Press", primaryBodyPart: .chest)
        let squat = Exercise(name: "Squat", primaryBodyPart: .quads)
        ctx.insert(bench)
        ctx.insert(squat)

        let twoWeeksAgo = Date.now.addingTimeInterval(-14 * 24 * 3600)
        let past = makeSession(startedAt: twoWeeksAgo, finished: true, entries: [
            (bench, [(90, 5, false, true)]),
        ])

        let startedAt = Date.now.addingTimeInterval(-45 * 60)
        let today = makeSession(startedAt: startedAt, finished: false, entries: [
            (bench, [(60, 8, true, true), (100, 5, false, true), (100, 5, false, true)]),
            (squat, [(140, 3, false, true), (140, 3, false, false)]),
        ])

        let summary = WorkoutSummaryBuilder.build(
            session: today,
            finishedAt: startedAt.addingTimeInterval(45 * 60),
            history: [past.coreInput]
        )

        #expect(summary.durationSeconds == 45 * 60)
        #expect(summary.durationLabel == "45 min")
        #expect(summary.totalVolumeKg == 1420)   // 100×5×2 bench + 140×3 squat
        #expect(summary.workingSetCount == 3)    // warm-up and unticked sets excluded
        #expect(summary.bodyParts == [.chest, .quads])

        // Bench beat its old weight and estimated 1RM, but matched its reps.
        #expect(kinds(summary, for: "Bench Press") == [.weight, .e1rm])
        // Squat has no history at all, so every category is a first.
        #expect(kinds(summary, for: "Squat") == [.weight, .reps, .e1rm])
    }

    @Test func aPlannedButUntrainedExerciseIsNotCountedAsTrained() {
        let bench = Exercise(name: "Bench Press", primaryBodyPart: .chest)
        let fly = Exercise(name: "Cable Fly", primaryBodyPart: .chest)
        let curl = Exercise(name: "Curl", primaryBodyPart: .biceps)
        [bench, fly, curl].forEach(ctx.insert)

        let startedAt = Date.now.addingTimeInterval(-30 * 60)
        let session = makeSession(startedAt: startedAt, finished: false, entries: [
            (bench, [(100, 5, false, true)]),
            (fly, [(20, 12, false, true)]),
            (curl, [(15, 10, false, false)]),   // skipped
        ])

        let summary = WorkoutSummaryBuilder.build(
            session: session,
            finishedAt: startedAt.addingTimeInterval(30 * 60),
            history: []
        )

        #expect(summary.bodyParts == [.chest])   // de-duplicated, biceps never worked
        #expect(summary.workingSetCount == 2)
        #expect(kinds(summary, for: "Curl").isEmpty)
    }

    @Test func durationLabelSwitchesToHoursPastAnHour() {
        let summary = WorkoutSummary(
            durationSeconds: 65 * 60,
            totalVolumeKg: 0,
            workingSetCount: 0,
            bodyParts: [],
            prHits: []
        )

        #expect(summary.durationLabel == "1h 05m")
    }
}
