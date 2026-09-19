import Foundation

/// How hard a single day was, for the heatmap's colour ramp.
///
/// Levels come from **working-set count** rather than volume: volume would
/// render every bodyweight day as the lightest shade, since bodyweight sets
/// contribute zero by design.
public enum HeatLevel: Int, Sendable, Comparable, CaseIterable {
    case none = 0, light, moderate, heavy, maximal

    public static func < (lhs: HeatLevel, rhs: HeatLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Absolute thresholds rather than quantiles of the user's own history, so
    /// a given shade means the same thing in January as it does in December.
    public init(workingSetCount: Int) {
        switch workingSetCount {
        case ..<1: self = .none
        case 1...5: self = .light
        case 6...12: self = .moderate
        case 13...20: self = .heavy
        default: self = .maximal
        }
    }
}

/// Days that contain at least one finished session, normalised to midnight.
private func trainedDays(_ sessions: [SessionInput], calendar: Calendar) -> Set<Date> {
    Set(
        sessions
            .filter(\.isFinished)
            .map { calendar.startOfDay(for: $0.startedAt) }
    )
}

/// Consecutive days trained, counting back from today.
///
/// If today has no workout yet but yesterday does, the streak anchors to
/// yesterday — otherwise the number would read 0 every morning until you train.
/// It only resets once a full day passes with no finished session.
public func currentStreakDays(
    _ sessions: [SessionInput],
    today: Date = .now,
    calendar: Calendar = .current
) -> Int {
    let days = trainedDays(sessions, calendar: calendar)
    guard !days.isEmpty else { return 0 }

    let startOfToday = calendar.startOfDay(for: today)
    guard let yesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday) else { return 0 }

    var cursor: Date
    if days.contains(startOfToday) {
        cursor = startOfToday
    } else if days.contains(yesterday) {
        cursor = yesterday
    } else {
        return 0
    }

    var streak = 0
    while days.contains(cursor) {
        streak += 1
        guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
        cursor = previous
    }
    return streak
}

/// The longest run of consecutive trained days anywhere in history.
public func longestStreakDays(
    _ sessions: [SessionInput],
    calendar: Calendar = .current
) -> Int {
    let days = trainedDays(sessions, calendar: calendar).sorted()
    guard !days.isEmpty else { return 0 }

    var longest = 1
    var run = 1
    for (previous, day) in zip(days, days.dropFirst()) {
        let gap = calendar.dateComponents([.day], from: previous, to: day).day ?? 0
        run = gap == 1 ? run + 1 : 1
        longest = max(longest, run)
    }
    return longest
}

/// Heat level per day across `window`. Only trained days appear — a caller
/// rendering a grid fills the gaps with `.none` itself, which keeps this
/// independent of how many cells the view decides to draw.
public func heatmap(
    _ sessions: [SessionInput],
    window: DateInterval,
    calendar: Calendar = .current
) -> [Date: HeatLevel] {
    var setsPerDay: [Date: Int] = [:]

    for session in sessions where session.isFinished && window.contains(session.startedAt) {
        let day = calendar.startOfDay(for: session.startedAt)
        let count = session.exercises.reduce(0) { total, exercise in
            total + workingSets(exercise.sets).count
        }
        setsPerDay[day, default: 0] += count
    }

    return setsPerDay.compactMapValues { count in
        let level = HeatLevel(workingSetCount: count)
        // A day whose sets were all warm-ups isn't a trained day.
        return level == .none ? nil : level
    }
}
