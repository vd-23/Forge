import Foundation
import ForgeCore
import SwiftData
import Testing
@testable import Forge

@Suite @MainActor
struct ExerciseProgressTests {
    /// Held as a stored property so the container outlives the context.
    let container = PersistenceController.makeInMemoryContainer()
    var ctx: ModelContext { container.mainContext }

    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private let today = Date(timeIntervalSince1970: 1_790_000_000)   // fixed anchor

    private func daysAgo(_ days: Int) -> Date {
        calendar.date(byAdding: .day, value: -days, to: today)!
    }

    /// Reused across sessions so the exercise keeps one id — a fresh instance
    /// per session would make every workout look like the first.
    private func exercise(named name: String, bodyweight: Bool = false) -> Exercise {
        let existing = (try? ctx.fetch(FetchDescriptor<Exercise>()))?.first { $0.name == name }
        if let existing { return existing }

        let exercise = Exercise(name: name, primaryBodyPart: .chest, isBodyweight: bodyweight)
        ctx.insert(exercise)
        return exercise
    }

    @discardableResult
    private func log(
        _ exercise: Exercise,
        on date: Date,
        weightKg: Double? = 100,
        addedWeightKg: Double? = nil,
        reps: Int = 5,
        sets: Int = 2,
        complete: Bool = true,
        finished: Bool = true
    ) -> WorkoutSession {
        let session = WorkoutSession(startedAt: date, sourceRoutine: nil, sourceRoutineName: "Push")
        session.endedAt = finished ? date.addingTimeInterval(3600) : nil
        ctx.insert(session)

        let workoutExercise = WorkoutExercise(exercise: exercise, exerciseID: exercise.id, order: 0)
        for index in 0..<sets {
            let set = ExerciseSet(order: index, weightKg: weightKg, addedWeightKg: addedWeightKg, reps: reps)
            set.isComplete = complete
            workoutExercise.sets.append(set)
        }
        session.exercises.append(workoutExercise)

        try? ctx.save()
        return session
    }

    private func build(
        _ exercise: Exercise,
        metric: ExerciseMetric,
        range: ChartRange = .all
    ) -> ExerciseProgress {
        let sessions = (try? ctx.fetch(FetchDescriptor<WorkoutSession>())) ?? []
        return ExerciseProgressBuilder.build(
            exerciseID: exercise.id,
            sessions: sessions,
            metric: metric,
            range: range,
            today: today,
            calendar: calendar
        )
    }

    // MARK: Empty

    @Test func anUntrainedExerciseHasNoProgress() {
        let bench = exercise(named: "Bench Press")
        let progress = build(bench, metric: .e1rm)

        #expect(progress.hasHistory == false)
        #expect(progress.points.isEmpty)
        #expect(progress.lastPerformed == nil)
    }

    @Test func unfinishedAndUntickedWorkDoesNotCount() {
        let bench = exercise(named: "Bench Press")
        log(bench, on: daysAgo(2), finished: false)
        log(bench, on: daysAgo(3), complete: false)

        #expect(build(bench, metric: .e1rm).hasHistory == false)
    }

    // MARK: Lifetime facts

    @Test func countsSessionsAndRemembersTheLatest() {
        let bench = exercise(named: "Bench Press")
        log(bench, on: daysAgo(30))
        log(bench, on: daysAgo(10))
        log(bench, on: daysAgo(3))

        let progress = build(bench, metric: .e1rm)

        #expect(progress.sessionCount == 3)
        #expect(progress.lastPerformed == daysAgo(3))
    }

    @Test func recordsAreLifetimeEvenWhenTheRangeIsShort() {
        let bench = exercise(named: "Bench Press")
        log(bench, on: daysAgo(300), weightKg: 140)   // outside an 8-week window
        log(bench, on: daysAgo(3), weightKg: 100)

        let progress = build(bench, metric: .e1rm, range: .eightWeeks)

        #expect(progress.records.maxWeightKg == 140)
        #expect(progress.points.count == 1)          // but the chart respects the range
    }

    // MARK: Range

    @Test func eachRangeKeepsOnlyWhatFallsInsideIt() {
        let bench = exercise(named: "Bench Press")
        log(bench, on: daysAgo(400))
        log(bench, on: daysAgo(200))
        log(bench, on: daysAgo(30))
        log(bench, on: daysAgo(3))

        #expect(build(bench, metric: .e1rm, range: .eightWeeks).points.count == 2)
        #expect(build(bench, metric: .e1rm, range: .sixMonths).points.count == 2)
        #expect(build(bench, metric: .e1rm, range: .year).points.count == 3)
        #expect(build(bench, metric: .e1rm, range: .all).points.count == 4)
    }

    @Test func pointsRunOldestToNewest() {
        let bench = exercise(named: "Bench Press")
        log(bench, on: daysAgo(3))
        log(bench, on: daysAgo(30))

        let dates = build(bench, metric: .e1rm).points.map(\.date)

        #expect(dates == dates.sorted())
    }

    // MARK: Metrics

    @Test func e1rmUsesEpleyOnTheBestWorkingSet() {
        let bench = exercise(named: "Bench Press")
        log(bench, on: daysAgo(3), weightKg: 100, reps: 5, sets: 1)

        let value = build(bench, metric: .e1rm).points.first?.value

        #expect(abs((value ?? 0) - 100 * (1 + 5.0 / 30)) < 0.001)
    }

    @Test func volumeSumsTheWorkingSets() {
        let bench = exercise(named: "Bench Press")
        log(bench, on: daysAgo(3), weightKg: 100, reps: 5, sets: 3)

        #expect(build(bench, metric: .volume).points.map(\.value) == [1500])
    }

    @Test func bodyweightGetsRepsAndAddedWeightInsteadOfLoadMetrics() {
        #expect(ExerciseMetric.options(bodyweight: true) == [.maxReps, .addedWeight])
        #expect(ExerciseMetric.options(bodyweight: false) == [.e1rm, .volume])
    }

    @Test func maxRepsTracksTheBestSetOfEachSession() {
        let pullUp = exercise(named: "Pull-up", bodyweight: true)
        log(pullUp, on: daysAgo(10), weightKg: nil, reps: 8, sets: 2)
        log(pullUp, on: daysAgo(3), weightKg: nil, reps: 12, sets: 2)

        #expect(build(pullUp, metric: .maxReps).points.map(\.value) == [8, 12])
    }

    /// Unloaded sessions are skipped so the line tracks weighted work rather
    /// than dropping to zero every time you train at bodyweight.
    @Test func addedWeightIgnoresUnloadedSessions() {
        let pullUp = exercise(named: "Pull-up", bodyweight: true)
        log(pullUp, on: daysAgo(10), weightKg: nil, reps: 10, sets: 2)
        log(pullUp, on: daysAgo(3), weightKg: nil, addedWeightKg: 15, reps: 5, sets: 2)

        #expect(build(pullUp, metric: .addedWeight).points.map(\.value) == [15])
    }

    @Test func anotherExercisesSessionsAreIgnored() {
        let bench = exercise(named: "Bench Press")
        let squat = exercise(named: "Back Squat")
        log(bench, on: daysAgo(3))
        log(squat, on: daysAgo(4), weightKg: 200)

        let progress = build(bench, metric: .e1rm)

        #expect(progress.sessionCount == 1)
        #expect(progress.records.maxWeightKg == 100)
    }

    // MARK: Range maths

    @Test func allHasNoLowerBound() {
        #expect(ChartRange.all.start(endingOn: today, calendar: calendar) == nil)
    }

    @Test func eachRangeStartsWhereItSays() {
        #expect(ChartRange.eightWeeks.start(endingOn: today, calendar: calendar) == calendar.date(byAdding: .weekOfYear, value: -8, to: today))
        #expect(ChartRange.sixMonths.start(endingOn: today, calendar: calendar) == calendar.date(byAdding: .month, value: -6, to: today))
        #expect(ChartRange.year.start(endingOn: today, calendar: calendar) == calendar.date(byAdding: .year, value: -1, to: today))
    }
}
