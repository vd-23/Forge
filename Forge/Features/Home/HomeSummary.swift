import Foundation
import ForgeCore

/// One cell of the heatmap grid.
struct HeatmapDay: Identifiable {
    let date: Date
    let level: HeatLevel
    /// Days after today are laid out but drawn blank, so the grid keeps a
    /// rectangular shape instead of ending mid-column.
    let isFuture: Bool

    var id: Date { date }
}

/// One column: seven days, starting on the locale's first weekday.
struct HeatmapWeek: Identifiable {
    let start: Date
    let days: [HeatmapDay]
    /// Set on the first column of each month, for the labels above the grid.
    let monthLabel: String?

    var id: Date { start }
}

struct HomePRRow: Identifiable {
    let id = UUID()
    let exerciseName: String
    let kind: PRKind
    let value: Double
    let date: Date
}

/// Everything the Home tab draws, computed once from history.
struct HomeSummary {
    let currentStreak: Int
    let longestStreak: Int
    let thisWeekWorkouts: Int
    let lastWeekWorkouts: Int
    let thisWeekVolumeKg: Double
    let weeks: [HeatmapWeek]
    let dailyVolume: [SeriesPoint]
    let recentPRs: [HomePRRow]

    static let empty = HomeSummary(
        currentStreak: 0,
        longestStreak: 0,
        thisWeekWorkouts: 0,
        lastWeekWorkouts: 0,
        thisWeekVolumeKg: 0,
        weeks: [],
        dailyVolume: [],
        recentPRs: []
    )

    var hasHistory: Bool { !weeks.isEmpty }
}

@MainActor
enum HomeSummaryBuilder {
    /// - Parameter heatmapWeeks: columns in the grid, ending with this week.
    static func build(
        sessions: [WorkoutSession],
        today: Date = .now,
        calendar: Calendar = .current,
        heatmapWeeks: Int = 18,
        volumeDays: Int = 30,
        prLimit: Int = 5
    ) -> HomeSummary {
        let finished = sessions.filter { $0.endedAt != nil }
        guard !finished.isEmpty else { return .empty }

        let inputs = finished.map(\.coreInput)
        let names = exerciseNames(in: finished)

        let weeks = heatmapGrid(
            inputs,
            today: today,
            calendar: calendar,
            weekCount: heatmapWeeks
        )

        let volumeWindow = window(ofLastDays: volumeDays, endingOn: today, calendar: calendar)
        let thisWeek = calendar.dateInterval(of: .weekOfYear, for: today)

        let thisWeekSessions = finished.filter { session in
            thisWeek?.contains(session.startedAt) ?? false
        }
        let lastWeek = thisWeek.flatMap { interval -> DateInterval? in
            guard let start = calendar.date(byAdding: .weekOfYear, value: -1, to: interval.start) else { return nil }
            return DateInterval(start: start, end: interval.start)
        }
        let lastWeekCount = finished.filter { lastWeek?.contains($0.startedAt) ?? false }.count

        return HomeSummary(
            currentStreak: currentStreakDays(inputs, today: today, calendar: calendar),
            longestStreak: longestStreakDays(inputs, calendar: calendar),
            thisWeekWorkouts: thisWeekSessions.count,
            lastWeekWorkouts: lastWeekCount,
            thisWeekVolumeKg: thisWeekSessions.reduce(0) { $0 + sessionVolumeKg($1.coreInput) },
            weeks: weeks,
            dailyVolume: dailyVolumeSeries(inputs, window: volumeWindow, calendar: calendar),
            recentPRs: recentPRs(inputs, limit: prLimit).map { dated in
                HomePRRow(
                    exerciseName: names[dated.hit.exerciseID] ?? "Exercise",
                    kind: dated.hit.kind,
                    value: dated.hit.value,
                    date: dated.date
                )
            }
        )
    }

    // MARK: Grid

    /// Columns oldest first, each running from the locale's first weekday.
    static func heatmapGrid(
        _ sessions: [SessionInput],
        today: Date = .now,
        calendar: Calendar = .current,
        weekCount: Int
    ) -> [HeatmapWeek] {
        guard weekCount > 0,
              let thisWeekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start
        else { return [] }

        let starts: [Date] = (0..<weekCount)
            .compactMap { calendar.date(byAdding: .weekOfYear, value: -$0, to: thisWeekStart) }
            .reversed()

        guard let earliest = starts.first,
              let end = calendar.date(byAdding: .weekOfYear, value: 1, to: thisWeekStart)
        else { return [] }

        let heat = heatmap(sessions, window: DateInterval(start: earliest, end: end), calendar: calendar)
        let startOfToday = calendar.startOfDay(for: today)

        var lastMonth: Int?
        return starts.map { start in
            let days = (0..<7).compactMap { offset -> HeatmapDay? in
                guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
                let day = calendar.startOfDay(for: date)
                return HeatmapDay(
                    date: day,
                    level: heat[day] ?? .none,
                    isFuture: day > startOfToday
                )
            }

            let month = calendar.component(.month, from: start)
            let label = month == lastMonth ? nil : start.formatted(.dateTime.month(.abbreviated))
            lastMonth = month

            return HeatmapWeek(start: start, days: days, monthLabel: label)
        }
    }

    // MARK: Helpers

    /// The last `days` days including today.
    static func window(ofLastDays days: Int, endingOn today: Date, calendar: Calendar) -> DateInterval {
        let startOfToday = calendar.startOfDay(for: today)
        let start = calendar.date(byAdding: .day, value: -(days - 1), to: startOfToday) ?? startOfToday
        let end = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? today
        return DateInterval(start: start, end: end)
    }

    private static func exerciseNames(in sessions: [WorkoutSession]) -> [UUID: String] {
        sessions.reduce(into: [:]) { names, session in
            for workoutExercise in session.exercises {
                if let name = workoutExercise.exercise?.name {
                    names[workoutExercise.exerciseID] = name
                }
            }
        }
    }
}
