import Foundation
import Testing
@testable import ForgeCore

@Suite
struct VolumeSeriesTests {
    private let calendar = Fixture.calendar

    @Test func dailyVolumeIsOnePointPerTrainedDayOldestFirst() {
        let sessions = [
            Fixture.session(on: Fixture.day(2026, 9, 19), workingSets: 2),   // 1000 kg
            Fixture.session(on: Fixture.day(2026, 9, 17), workingSets: 3),   // 1500 kg
        ]

        let series = dailyVolumeSeries(
            sessions,
            window: DateInterval(start: Fixture.day(2026, 9, 1), end: Fixture.day(2026, 9, 30)),
            calendar: calendar
        )

        #expect(series.map(\.value) == [1500, 1000])
        #expect(series[0].date < series[1].date)
    }

    @Test func twoSessionsInADayAreSummedIntoOnePoint() {
        let date = Fixture.day(2026, 9, 19)
        let sessions = [
            Fixture.session(on: date, workingSets: 2),
            Fixture.session(on: date.addingTimeInterval(6 * 3600), workingSets: 1),
        ]

        let series = dailyVolumeSeries(
            sessions,
            window: DateInterval(start: Fixture.day(2026, 9, 1), end: Fixture.day(2026, 9, 30)),
            calendar: calendar
        )

        #expect(series.count == 1)
        #expect(series[0].value == 1500)
    }

    @Test func restDaysAreOmittedRatherThanPlottedAsZero() {
        let series = dailyVolumeSeries(
            [Fixture.session(on: Fixture.day(2026, 9, 19))],
            window: DateInterval(start: Fixture.day(2026, 9, 1), end: Fixture.day(2026, 9, 30)),
            calendar: calendar
        )

        #expect(series.count == 1)
    }

    /// The weekly chart is the opposite: a blank week is information.
    @Test func weeklyVolumeEmitsZeroForAWeekWithNoTraining() {
        let series = weeklyVolumeSeries(
            [Fixture.session(on: Fixture.day(2026, 9, 19), workingSets: 2)],
            weeks: 4,
            endingOn: Fixture.day(2026, 9, 19),
            calendar: calendar
        )

        #expect(series.count == 4)
        #expect(series.dropLast().allSatisfy { $0.value == 0 })
        #expect(series.last?.value == 1000)
    }

    @Test func weeklyVolumeRunsOldestToNewest() {
        let series = weeklyVolumeSeries([], weeks: 3, endingOn: Fixture.day(2026, 9, 19), calendar: calendar)

        #expect(series.count == 3)
        #expect(series[0].date < series[1].date)
        #expect(series[1].date < series[2].date)
    }

    @Test func zeroWeeksIsAnEmptySeries() {
        #expect(weeklyVolumeSeries([], weeks: 0, endingOn: Fixture.day(2026, 9, 19), calendar: calendar).isEmpty)
    }
}

@Suite
struct ExerciseSeriesTests {
    private let benchID = Fixture.bench.id

    /// 100 kg × 5 → 100 × (1 + 5/30) = 116.66…
    private let e1rmOf100x5 = 100 * (1 + 5.0 / 30)

    private func benchSession(on date: Date, weightKg: Double, reps: Int, warmup: Bool = false) -> SessionInput {
        SessionInput(
            id: UUID(),
            startedAt: date,
            endedAt: date.addingTimeInterval(3600),
            exercises: [WorkoutExerciseInput(
                exercise: Fixture.bench,
                sets: [SetInput(weightKg: weightKg, reps: reps, isWarmup: warmup, isComplete: true)]
            )]
        )
    }

    @Test func e1rmSeriesTakesTheBestWorkingSetPerSessionOldestFirst() {
        let sessions = [
            benchSession(on: Fixture.day(2026, 9, 19), weightKg: 110, reps: 5),
            benchSession(on: Fixture.day(2026, 9, 12), weightKg: 100, reps: 5),
        ]

        let series = e1rmSeries(sessions, exerciseID: benchID)

        #expect(series.count == 2)
        #expect(abs(series[0].value - e1rmOf100x5) < 0.001)
        #expect(series[0].date < series[1].date)
    }

    @Test func aSessionWithoutTheExerciseIsSkipped() {
        let other = ExerciseInput(id: UUID(), isBodyweight: false, isUnilateral: false)
        let sessions = [
            benchSession(on: Fixture.day(2026, 9, 12), weightKg: 100, reps: 5),
            SessionInput(
                id: UUID(),
                startedAt: Fixture.day(2026, 9, 14),
                endedAt: Fixture.day(2026, 9, 14),
                exercises: [WorkoutExerciseInput(
                    exercise: other,
                    sets: [SetInput(weightKg: 60, reps: 8, isComplete: true)]
                )]
            ),
        ]

        #expect(e1rmSeries(sessions, exerciseID: benchID).count == 1)
    }

    @Test func warmupOnlySessionsProduceNoPoint() {
        let sessions = [benchSession(on: Fixture.day(2026, 9, 12), weightKg: 60, reps: 10, warmup: true)]
        #expect(e1rmSeries(sessions, exerciseID: benchID).isEmpty)
    }

    @Test func exerciseVolumeSeriesCountsOnlyThatExercise() {
        let sessions = [Fixture.session(on: Fixture.day(2026, 9, 19), workingSets: 3)]

        let series = exerciseVolumeSeries(sessions, exerciseID: benchID)

        #expect(series.map(\.value) == [1500])
    }

    @Test func maxRepsSeriesTracksTheBestSetPerSession() {
        let pullUpID = Fixture.pullUp.id
        let session = SessionInput(
            id: UUID(),
            startedAt: Fixture.day(2026, 9, 19),
            endedAt: Fixture.day(2026, 9, 19),
            exercises: [WorkoutExerciseInput(
                exercise: Fixture.pullUp,
                sets: [
                    SetInput(weightKg: nil, reps: 12, isComplete: true),
                    SetInput(weightKg: nil, reps: 9, isComplete: true),
                    SetInput(weightKg: nil, reps: 20, isComplete: false),   // never ticked
                ]
            )]
        )

        #expect(maxRepsSeries([session], exerciseID: pullUpID).map(\.value) == [12])
    }

    /// Pure-bodyweight sessions are skipped so the added-weight line tracks
    /// loaded work rather than dropping to zero every time you train unweighted.
    @Test func addedWeightSeriesSkipsUnloadedSessions() {
        let pullUpID = Fixture.pullUp.id
        let unloaded = SessionInput(
            id: UUID(),
            startedAt: Fixture.day(2026, 9, 12),
            endedAt: Fixture.day(2026, 9, 12),
            exercises: [WorkoutExerciseInput(
                exercise: Fixture.pullUp,
                sets: [SetInput(weightKg: nil, reps: 10, isComplete: true)]
            )]
        )
        let loaded = SessionInput(
            id: UUID(),
            startedAt: Fixture.day(2026, 9, 19),
            endedAt: Fixture.day(2026, 9, 19),
            exercises: [WorkoutExerciseInput(
                exercise: Fixture.pullUp,
                sets: [
                    SetInput(weightKg: nil, addedWeightKg: 10, reps: 6, isComplete: true),
                    SetInput(weightKg: nil, addedWeightKg: 15, reps: 4, isComplete: true),
                ]
            )]
        )

        let series = addedWeightSeries([unloaded, loaded], exerciseID: pullUpID)

        #expect(series.map(\.value) == [15])
    }

    @Test func unfinishedSessionsNeverAppearInASeries() {
        let sessions = [
            SessionInput(
                id: UUID(),
                startedAt: Fixture.day(2026, 9, 19),
                endedAt: nil,
                exercises: [WorkoutExerciseInput(
                    exercise: Fixture.bench,
                    sets: [SetInput(weightKg: 100, reps: 5, isComplete: true)]
                )]
            )
        ]

        #expect(e1rmSeries(sessions, exerciseID: benchID).isEmpty)
        #expect(exerciseVolumeSeries(sessions, exerciseID: benchID).isEmpty)
        #expect(maxRepsSeries(sessions, exerciseID: benchID).isEmpty)
    }
}
