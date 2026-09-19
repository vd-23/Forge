import Foundation
import Testing
@testable import ForgeCore

@Suite
struct RecentRecordsTests {
    private let benchID = Fixture.bench.id

    private func benchSession(on date: Date, weightKg: Double, reps: Int) -> SessionInput {
        SessionInput(
            id: UUID(),
            startedAt: date,
            endedAt: date.addingTimeInterval(3600),
            exercises: [WorkoutExerciseInput(
                exercise: Fixture.bench,
                sets: [SetInput(weightKg: weightKg, reps: reps, isComplete: true)]
            )]
        )
    }

    @Test func aFirstEverSessionSetsEveryCategory() {
        let records = recentPRs([benchSession(on: Fixture.day(2026, 9, 12), weightKg: 100, reps: 5)])

        #expect(Set(records.map(\.hit.kind)) == [.weight, .reps, .e1rm])
        #expect(records.allSatisfy { $0.date == Fixture.day(2026, 9, 12) })
    }

    @Test func recordsComeBackNewestFirst() {
        let sessions = [
            benchSession(on: Fixture.day(2026, 9, 12), weightKg: 100, reps: 5),
            benchSession(on: Fixture.day(2026, 9, 19), weightKg: 110, reps: 5),
        ]

        let records = recentPRs(sessions)

        #expect(records.first?.date == Fixture.day(2026, 9, 19))
        #expect(records.last?.date == Fixture.day(2026, 9, 12))
    }

    /// Matching a previous best is not a record — only beating it is.
    @Test func repeatingASessionSetsNothing() {
        let sessions = [
            benchSession(on: Fixture.day(2026, 9, 12), weightKg: 100, reps: 5),
            benchSession(on: Fixture.day(2026, 9, 19), weightKg: 100, reps: 5),
        ]

        let records = recentPRs(sessions)

        #expect(records.allSatisfy { $0.date == Fixture.day(2026, 9, 12) })
    }

    @Test func eachSessionIsScoredAgainstOnlyWhatCameBeforeIt() {
        let sessions = [
            benchSession(on: Fixture.day(2026, 9, 19), weightKg: 110, reps: 5),
            benchSession(on: Fixture.day(2026, 9, 12), weightKg: 100, reps: 5),
        ]

        let records = recentPRs(sessions)

        // The heavier session is later in time but was passed in first: order
        // must come from the dates, or the 110 would not register as a PR.
        let weightPRDates = records.filter { $0.hit.kind == .weight }.map(\.date)
        #expect(weightPRDates == [Fixture.day(2026, 9, 19), Fixture.day(2026, 9, 12)])
    }

    @Test func honoursTheLimit() {
        let sessions = (0..<6).map { index in
            benchSession(on: Fixture.day(2026, 9, 1 + index), weightKg: 100 + Double(index) * 5, reps: 5)
        }

        #expect(recentPRs(sessions, limit: 3).count == 3)
    }

    @Test func unfinishedSessionsAreIgnored() {
        let inProgress = SessionInput(
            id: UUID(),
            startedAt: Fixture.day(2026, 9, 19),
            endedAt: nil,
            exercises: [WorkoutExerciseInput(
                exercise: Fixture.bench,
                sets: [SetInput(weightKg: 200, reps: 5, isComplete: true)]
            )]
        )

        #expect(recentPRs([inProgress]).isEmpty)
    }

    @Test func noHistoryIsNoRecords() {
        #expect(recentPRs([]).isEmpty)
    }
}
