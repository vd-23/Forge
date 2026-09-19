import Foundation
import ForgeCore
import SwiftData
import Testing
@testable import Forge

@Suite @MainActor
struct HomeSummaryTests {
    /// Held as a stored property so the container outlives the context.
    let container = PersistenceController.makeInMemoryContainer()
    var ctx: ModelContext { container.mainContext }

    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 9))!
    }

    /// Reused across sessions: a fresh `Exercise` per session would have a new
    /// id, so every session would look like the first time that lift was
    /// trained and PR detection would never see any history.
    private func exercise(named name: String) -> Exercise {
        let existing = (try? ctx.fetch(FetchDescriptor<Exercise>()))?.first { $0.name == name }
        if let existing { return existing }

        let exercise = Exercise(name: name, primaryBodyPart: .chest)
        ctx.insert(exercise)
        return exercise
    }

    @discardableResult
    private func logSession(
        on date: Date,
        exerciseName: String = "Bench Press",
        weightKg: Double = 100,
        reps: Int = 5,
        sets: Int = 2,
        finished: Bool = true
    ) -> WorkoutSession {
        let exercise = exercise(named: exerciseName)

        let session = WorkoutSession(startedAt: date, sourceRoutine: nil, sourceRoutineName: "Push")
        session.endedAt = finished ? date.addingTimeInterval(3600) : nil
        ctx.insert(session)

        let workoutExercise = WorkoutExercise(exercise: exercise, exerciseID: exercise.id, order: 0)
        for index in 0..<sets {
            let set = ExerciseSet(order: index, weightKg: weightKg, reps: reps)
            set.isComplete = true
            workoutExercise.sets.append(set)
        }
        session.exercises.append(workoutExercise)

        try? ctx.save()
        return session
    }

    private func build(today: Date) -> HomeSummary {
        let sessions = (try? ctx.fetch(FetchDescriptor<WorkoutSession>())) ?? []
        return HomeSummaryBuilder.build(sessions: sessions, today: today, calendar: calendar)
    }

    // MARK: Empty

    @Test func noHistoryProducesTheEmptySummary() {
        let summary = build(today: day(2026, 9, 19))

        #expect(summary.hasHistory == false)
        #expect(summary.currentStreak == 0)
        #expect(summary.recentPRs.isEmpty)
    }

    /// An in-progress session is not history — Home must stay empty until
    /// something is actually finished.
    @Test func anUnfinishedSessionDoesNotCountAsHistory() {
        logSession(on: day(2026, 9, 19), finished: false)

        #expect(build(today: day(2026, 9, 19)).hasHistory == false)
    }

    // MARK: Streaks and weekly stats

    @Test func reportsCurrentAndLongestStreak() {
        logSession(on: day(2026, 8, 3))
        logSession(on: day(2026, 8, 4))
        logSession(on: day(2026, 8, 5))
        logSession(on: day(2026, 9, 18))
        logSession(on: day(2026, 9, 19))

        let summary = build(today: day(2026, 9, 19))

        #expect(summary.currentStreak == 2)
        #expect(summary.longestStreak == 3)
    }

    @Test func thisWeekCountsOnlySessionsInTheCurrentWeek() {
        logSession(on: day(2026, 9, 10))                     // previous week
        logSession(on: day(2026, 9, 18), sets: 2)            // 1000 kg
        logSession(on: day(2026, 9, 19), sets: 3)            // 1500 kg

        let summary = build(today: day(2026, 9, 19))

        #expect(summary.thisWeekWorkouts == 2)
        #expect(summary.thisWeekVolumeKg == 2500)
    }

    // MARK: Heatmap grid

    @Test func theGridIsRectangularAndEndsWithThisWeek() {
        logSession(on: day(2026, 9, 19))

        let summary = build(today: day(2026, 9, 19))

        #expect(summary.weeks.count == 18)
        #expect(summary.weeks.allSatisfy { $0.days.count == 7 })
        let thisWeekStart = calendar.dateInterval(of: .weekOfYear, for: day(2026, 9, 19))!.start
        #expect(summary.weeks.last?.start == thisWeekStart)
    }

    @Test func gridColumnsRunOldestToNewest() {
        logSession(on: day(2026, 9, 19))

        let starts = build(today: day(2026, 9, 19)).weeks.map(\.start)

        #expect(starts == starts.sorted())
    }

    @Test func aTrainedDayIsColouredAndTheRestAreNot() {
        let trained = day(2026, 9, 17)
        logSession(on: trained, sets: 3)

        let summary = build(today: day(2026, 9, 19))
        let allDays = summary.weeks.flatMap(\.days)
        let cell = allDays.first { calendar.isDate($0.date, inSameDayAs: trained) }

        #expect(cell?.level == .light)
        #expect(allDays.filter { $0.level != .none }.count == 1)
    }

    @Test func daysAfterTodayAreMarkedAsFuture() {
        logSession(on: day(2026, 9, 15))

        let summary = build(today: day(2026, 9, 16))
        let future = summary.weeks.flatMap(\.days).filter(\.isFuture)

        #expect(future.allSatisfy { $0.date > day(2026, 9, 16) })
        #expect(!future.isEmpty)
    }

    /// Only the first column of a month is labelled, so the strip above the
    /// grid doesn't repeat the same month over and over.
    @Test func monthLabelsAppearOncePerMonth() {
        logSession(on: day(2026, 9, 19))

        let labels = build(today: day(2026, 9, 19)).weeks.compactMap(\.monthLabel)

        #expect(labels.count == Set(labels).count)
        #expect(labels.contains("Sep"))
    }

    // MARK: Volume and records

    @Test func dailyVolumeCoversTheLastThirtyDaysOnly() {
        logSession(on: day(2026, 7, 1))     // well outside the window
        logSession(on: day(2026, 9, 18))
        logSession(on: day(2026, 9, 19))

        let summary = build(today: day(2026, 9, 19))

        #expect(summary.dailyVolume.count == 2)
    }

    @Test func recordsAreNamedDatedAndNewestFirst() {
        logSession(on: day(2026, 9, 12), weightKg: 100)
        logSession(on: day(2026, 9, 19), weightKg: 110)

        let summary = build(today: day(2026, 9, 19))

        #expect(summary.recentPRs.allSatisfy { $0.exerciseName == "Bench Press" })
        #expect(summary.recentPRs.first?.date == day(2026, 9, 19))
        // Heavier for the same reps: a weight and an e1RM PR, but not reps.
        let latestKinds = Set(summary.recentPRs.filter { $0.date == day(2026, 9, 19) }.map(\.kind))
        #expect(latestKinds == [.weight, .e1rm])
    }
}
