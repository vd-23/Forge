import Foundation
import Testing
@testable import Forge

@Suite @MainActor
struct MonthGroupingTests {
    /// Fixed so the expected headings don't drift with the wall clock.
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private func session(_ year: Int, _ month: Int, _ day: Int) -> WorkoutSession {
        let startedAt = calendar.date(from: DateComponents(year: year, month: month, day: day))!
        let session = WorkoutSession(startedAt: startedAt, sourceRoutine: nil, sourceRoutineName: "Push")
        session.endedAt = startedAt.addingTimeInterval(3600)
        return session
    }

    @Test func groupsByMonthNewestFirst() {
        let sections = MonthGrouping.sections([
            session(2026, 8, 30),
            session(2026, 9, 4),
            session(2026, 9, 18),
        ], calendar: calendar)

        #expect(sections.map(\.title) == ["September 2026", "August 2026"])
        #expect(sections[0].sessions.count == 2)
        #expect(sections[1].sessions.count == 1)
    }

    @Test func ordersSessionsWithinAMonthNewestFirst() {
        let sections = MonthGrouping.sections([
            session(2026, 9, 4),
            session(2026, 9, 18),
            session(2026, 9, 11),
        ], calendar: calendar)

        let days = sections[0].sessions.map { calendar.component(.day, from: $0.startedAt) }
        #expect(days == [18, 11, 4])
    }

    @Test func separatesTheSameMonthInDifferentYears() {
        let sections = MonthGrouping.sections([
            session(2025, 9, 20),
            session(2026, 9, 20),
        ], calendar: calendar)

        #expect(sections.map(\.title) == ["September 2026", "September 2025"])
    }

    @Test func reversesBothMonthsAndSessionsWhenAskedForOldestFirst() {
        let sections = MonthGrouping.sections([
            session(2026, 9, 18),
            session(2026, 8, 30),
            session(2026, 9, 4),
        ], newestFirst: false, calendar: calendar)

        #expect(sections.map(\.title) == ["August 2026", "September 2026"])
        let septemberDays = sections[1].sessions.map { calendar.component(.day, from: $0.startedAt) }
        #expect(septemberDays == [4, 18])
    }

    @Test func returnsNothingForNoSessions() {
        #expect(MonthGrouping.sections([], calendar: calendar).isEmpty)
    }
}
