import Foundation

/// Groups finished sessions into the month headings the history list shows.
enum MonthGrouping {
    struct Section: Identifiable {
        var id: String { title }
        let title: String
        let sessions: [WorkoutSession]
    }

    /// Sessions are grouped by the month they *started*, so one that runs past
    /// midnight into a new month still belongs to the day it began. Months and
    /// the sessions inside them share the same direction.
    static func sections(
        _ sessions: [WorkoutSession],
        newestFirst: Bool = true,
        calendar: Calendar = .current
    ) -> [Section] {
        let byMonth = Dictionary(grouping: sessions) { session in
            calendar.dateComponents([.year, .month], from: session.startedAt)
        }

        return byMonth
            .sorted { lhs, rhs in
                let left = (lhs.key.year ?? 0, lhs.key.month ?? 0)
                let right = (rhs.key.year ?? 0, rhs.key.month ?? 0)
                return newestFirst ? left > right : left < right
            }
            .map { month, sessions in
                Section(
                    title: title(for: month, calendar: calendar),
                    sessions: sessions.sorted {
                        newestFirst ? $0.startedAt > $1.startedAt : $0.startedAt < $1.startedAt
                    }
                )
            }
    }

    private static func title(for month: DateComponents, calendar: Calendar) -> String {
        guard let date = calendar.date(from: month) else { return "" }
        return date.formatted(.dateTime.month(.wide).year())
    }
}
