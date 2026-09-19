import Foundation
import Testing
@testable import ForgeCore

/// Shared fixtures. A fixed UTC calendar keeps day boundaries from drifting
/// with whatever timezone the tests happen to run in.
enum Fixture {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    static let bench = ExerciseInput(id: UUID(), isBodyweight: false, isUnilateral: false)
    static let pullUp = ExerciseInput(id: UUID(), isBodyweight: true, isUnilateral: false)

    static func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 9))!
    }

    /// A finished session of `workingSets` completed sets at 100 kg × 5.
    static func session(
        on date: Date,
        exercise: ExerciseInput = bench,
        workingSets count: Int = 3,
        warmups: Int = 0,
        finished: Bool = true
    ) -> SessionInput {
        var sets = (0..<warmups).map { _ in
            SetInput(weightKg: 60, reps: 10, isWarmup: true, isComplete: true)
        }
        sets += (0..<count).map { _ in
            SetInput(weightKg: 100, reps: 5, isComplete: true)
        }
        return SessionInput(
            id: UUID(),
            startedAt: date,
            endedAt: finished ? date.addingTimeInterval(3600) : nil,
            exercises: [WorkoutExerciseInput(exercise: exercise, sets: sets)]
        )
    }
}

@Suite
struct CurrentStreakTests {
    private let calendar = Fixture.calendar

    @Test func countsConsecutiveDaysEndingToday() {
        let today = Fixture.day(2026, 9, 19)
        let sessions = [
            Fixture.session(on: Fixture.day(2026, 9, 17)),
            Fixture.session(on: Fixture.day(2026, 9, 18)),
            Fixture.session(on: today),
        ]

        #expect(currentStreakDays(sessions, today: today, calendar: calendar) == 3)
    }

    /// The whole point of anchoring to yesterday: before the morning session the
    /// number would otherwise read 0 and look like the streak had been lost.
    @Test func anchorsToYesterdayWhenTodayHasNoWorkoutYet() {
        let today = Fixture.day(2026, 9, 19)
        let sessions = [
            Fixture.session(on: Fixture.day(2026, 9, 17)),
            Fixture.session(on: Fixture.day(2026, 9, 18)),
        ]

        #expect(currentStreakDays(sessions, today: today, calendar: calendar) == 2)
    }

    @Test func resetsOnceAFullDayIsMissed() {
        let today = Fixture.day(2026, 9, 19)
        let sessions = [
            Fixture.session(on: Fixture.day(2026, 9, 16)),
            Fixture.session(on: Fixture.day(2026, 9, 17)),
        ]

        #expect(currentStreakDays(sessions, today: today, calendar: calendar) == 0)
    }

    @Test func twoSessionsInOneDayCountOnce() {
        let today = Fixture.day(2026, 9, 19)
        let sessions = [
            Fixture.session(on: today),
            Fixture.session(on: today.addingTimeInterval(6 * 3600)),
        ]

        #expect(currentStreakDays(sessions, today: today, calendar: calendar) == 1)
    }

    @Test func ignoresSessionsStillInProgress() {
        let today = Fixture.day(2026, 9, 19)
        let sessions = [Fixture.session(on: today, finished: false)]

        #expect(currentStreakDays(sessions, today: today, calendar: calendar) == 0)
    }

    @Test func noHistoryIsNoStreak() {
        #expect(currentStreakDays([], today: Fixture.day(2026, 9, 19), calendar: calendar) == 0)
    }
}

@Suite
struct LongestStreakTests {
    private let calendar = Fixture.calendar

    @Test func findsTheLongestRunAnywhereInHistory() {
        let sessions = [
            // A four-day run in August…
            Fixture.session(on: Fixture.day(2026, 8, 3)),
            Fixture.session(on: Fixture.day(2026, 8, 4)),
            Fixture.session(on: Fixture.day(2026, 8, 5)),
            Fixture.session(on: Fixture.day(2026, 8, 6)),
            // …and a shorter one in September.
            Fixture.session(on: Fixture.day(2026, 9, 18)),
            Fixture.session(on: Fixture.day(2026, 9, 19)),
        ]

        #expect(longestStreakDays(sessions, calendar: calendar) == 4)
    }

    @Test func aRunAcrossAMonthBoundaryStillCounts() {
        let sessions = [
            Fixture.session(on: Fixture.day(2026, 8, 30)),
            Fixture.session(on: Fixture.day(2026, 8, 31)),
            Fixture.session(on: Fixture.day(2026, 9, 1)),
        ]

        #expect(longestStreakDays(sessions, calendar: calendar) == 3)
    }

    @Test func oneWorkoutIsAStreakOfOne() {
        #expect(longestStreakDays([Fixture.session(on: Fixture.day(2026, 9, 19))], calendar: calendar) == 1)
    }

    @Test func noHistoryIsZero() {
        #expect(longestStreakDays([], calendar: calendar) == 0)
    }
}

@Suite
struct HeatmapTests {
    private let calendar = Fixture.calendar

    private func window(_ from: Date, _ to: Date) -> DateInterval {
        DateInterval(start: from, end: to)
    }

    @Test func levelsComeFromWorkingSetCount() {
        #expect(HeatLevel(workingSetCount: 0) == .none)
        #expect(HeatLevel(workingSetCount: 3) == .light)
        #expect(HeatLevel(workingSetCount: 9) == .moderate)
        #expect(HeatLevel(workingSetCount: 16) == .heavy)
        #expect(HeatLevel(workingSetCount: 30) == .maximal)
    }

    @Test func mapsEachTrainedDayToItsLevel() {
        let light = Fixture.day(2026, 9, 17)
        let heavy = Fixture.day(2026, 9, 19)
        let sessions = [
            Fixture.session(on: light, workingSets: 3),
            Fixture.session(on: heavy, workingSets: 15),
        ]

        let map = heatmap(sessions, window: window(Fixture.day(2026, 9, 1), Fixture.day(2026, 9, 30)), calendar: calendar)

        #expect(map[calendar.startOfDay(for: light)] == .light)
        #expect(map[calendar.startOfDay(for: heavy)] == .heavy)
    }

    @Test func twoSessionsOnOneDayAreCombined() {
        let date = Fixture.day(2026, 9, 19)
        let sessions = [
            Fixture.session(on: date, workingSets: 4),
            Fixture.session(on: date.addingTimeInterval(6 * 3600), workingSets: 4),
        ]

        let map = heatmap(sessions, window: window(Fixture.day(2026, 9, 1), Fixture.day(2026, 9, 30)), calendar: calendar)

        // 8 working sets, not two separate 4-set days.
        #expect(map.count == 1)
        #expect(map[calendar.startOfDay(for: date)] == .moderate)
    }

    /// Bodyweight work contributes no volume but plenty of sets — it must still
    /// colour the day, which is why the metric is sets rather than kilograms.
    @Test func aBodyweightDayStillRegisters() {
        let date = Fixture.day(2026, 9, 19)
        let session = SessionInput(
            id: UUID(),
            startedAt: date,
            endedAt: date.addingTimeInterval(3600),
            exercises: [WorkoutExerciseInput(
                exercise: Fixture.pullUp,
                sets: (0..<8).map { _ in SetInput(weightKg: nil, reps: 10, isComplete: true) }
            )]
        )

        let map = heatmap([session], window: window(Fixture.day(2026, 9, 1), Fixture.day(2026, 9, 30)), calendar: calendar)

        #expect(map[calendar.startOfDay(for: date)] == .moderate)
    }

    @Test func warmupOnlyAndUnfinishedDaysAreAbsent() {
        let warmupOnly = Fixture.day(2026, 9, 17)
        let unfinished = Fixture.day(2026, 9, 18)
        let sessions = [
            Fixture.session(on: warmupOnly, workingSets: 0, warmups: 5),
            Fixture.session(on: unfinished, workingSets: 5, finished: false),
        ]

        let map = heatmap(sessions, window: window(Fixture.day(2026, 9, 1), Fixture.day(2026, 9, 30)), calendar: calendar)

        #expect(map.isEmpty)
    }

    @Test func sessionsOutsideTheWindowAreExcluded() {
        let sessions = [
            Fixture.session(on: Fixture.day(2026, 7, 4)),
            Fixture.session(on: Fixture.day(2026, 9, 19)),
        ]

        let map = heatmap(sessions, window: window(Fixture.day(2026, 9, 1), Fixture.day(2026, 9, 30)), calendar: calendar)

        #expect(map.count == 1)
    }
}
