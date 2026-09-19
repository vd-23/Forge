import Foundation

/// One plotted point. Every series returns the same shape — the caller knows
/// what it asked for, so naming the value per-series would only add types.
public struct SeriesPoint: Sendable, Equatable {
    public let date: Date
    public let value: Double

    public init(date: Date, value: Double) {
        self.date = date
        self.value = value
    }
}

/// Finished sessions in chronological order.
private func chronological(_ sessions: [SessionInput]) -> [SessionInput] {
    sessions.filter(\.isFinished).sorted { $0.startedAt < $1.startedAt }
}

/// One point per exercise-session, dropping sessions where the exercise has no
/// qualifying working set. `metric` returns `nil` to skip a session.
private func exerciseSeries(
    _ sessions: [SessionInput],
    exerciseID: UUID,
    metric: ([SetInput]) -> Double?
) -> [SeriesPoint] {
    chronological(sessions).compactMap { session in
        let sets = session.exercises
            .filter { $0.exercise.id == exerciseID }
            .flatMap { workingSets($0.sets) }
        guard !sets.isEmpty, let value = metric(sets) else { return nil }
        return SeriesPoint(date: session.startedAt, value: value)
    }
}

// MARK: Whole-workout volume

/// Total working volume per day within `window`, oldest first. Days without a
/// finished session are omitted rather than plotted as zero.
public func dailyVolumeSeries(
    _ sessions: [SessionInput],
    window: DateInterval,
    calendar: Calendar = .current
) -> [SeriesPoint] {
    var volumePerDay: [Date: Double] = [:]

    for session in sessions where session.isFinished && window.contains(session.startedAt) {
        let day = calendar.startOfDay(for: session.startedAt)
        volumePerDay[day, default: 0] += sessionVolumeKg(session)
    }

    return volumePerDay
        .map { SeriesPoint(date: $0.key, value: $0.value) }
        .sorted { $0.date < $1.date }
}

/// Total working volume per week for the last `weeks` weeks including the week
/// containing `endingOn`, oldest first. Unlike the daily series this *does*
/// emit zeroes: a blank week is the point of a weekly chart.
public func weeklyVolumeSeries(
    _ sessions: [SessionInput],
    weeks: Int,
    endingOn: Date = .now,
    calendar: Calendar = .current
) -> [SeriesPoint] {
    guard weeks > 0 else { return [] }
    guard let thisWeek = calendar.dateInterval(of: .weekOfYear, for: endingOn)?.start else { return [] }

    let weekStarts: [Date] = (0..<weeks)
        .compactMap { calendar.date(byAdding: .weekOfYear, value: -$0, to: thisWeek) }
        .reversed()

    var volumePerWeek: [Date: Double] = [:]
    for session in sessions where session.isFinished {
        guard let start = calendar.dateInterval(of: .weekOfYear, for: session.startedAt)?.start else { continue }
        volumePerWeek[start, default: 0] += sessionVolumeKg(session)
    }

    return weekStarts.map { SeriesPoint(date: $0, value: volumePerWeek[$0] ?? 0) }
}

// MARK: Per-exercise progress

/// Best estimated 1RM per session — the headline trend for a weighted exercise.
public func e1rmSeries(_ sessions: [SessionInput], exerciseID: UUID) -> [SeriesPoint] {
    exerciseSeries(sessions, exerciseID: exerciseID) { sets in
        sets.compactMap { set in
            set.weightKg.map { estimatedOneRepMax(weightKg: $0, reps: set.reps) }
        }.max()
    }
}

/// Working volume for one exercise per session.
public func exerciseVolumeSeries(_ sessions: [SessionInput], exerciseID: UUID) -> [SeriesPoint] {
    chronological(sessions).compactMap { session in
        let matching = session.exercises.filter { $0.exercise.id == exerciseID }
        guard !matching.isEmpty else { return nil }

        let volume = matching.reduce(0.0) { total, workoutExercise in
            total + workingSets(workoutExercise.sets).reduce(0.0) { setTotal, set in
                setTotal + setVolumeKg(set, exercise: workoutExercise.exercise)
            }
        }
        guard volume > 0 else { return nil }
        return SeriesPoint(date: session.startedAt, value: volume)
    }
}

/// Most reps in a single working set per session — the progress metric for a
/// bodyweight exercise, which has no meaningful 1RM or volume.
public func maxRepsSeries(_ sessions: [SessionInput], exerciseID: UUID) -> [SeriesPoint] {
    exerciseSeries(sessions, exerciseID: exerciseID) { sets in
        sets.map(\.reps).max().map(Double.init)
    }
}

/// Heaviest added weight per session, for weighted pull-ups and dips. Sessions
/// trained at pure bodyweight are skipped rather than plotted as zero, so the
/// line tracks loaded work only.
public func addedWeightSeries(_ sessions: [SessionInput], exerciseID: UUID) -> [SeriesPoint] {
    exerciseSeries(sessions, exerciseID: exerciseID) { sets in
        sets.compactMap(\.addedWeightKg).filter { $0 > 0 }.max()
    }
}
