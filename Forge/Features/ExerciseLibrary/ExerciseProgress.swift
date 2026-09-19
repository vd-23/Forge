import Foundation
import ForgeCore

/// How far back the chart looks.
enum ChartRange: String, CaseIterable, Identifiable {
    case eightWeeks, sixMonths, year, all

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .eightWeeks: "8W"
        case .sixMonths: "6M"
        case .year: "1Y"
        case .all: "All"
        }
    }

    /// `nil` means no lower bound.
    func start(endingOn today: Date, calendar: Calendar) -> Date? {
        switch self {
        case .eightWeeks: calendar.date(byAdding: .weekOfYear, value: -8, to: today)
        case .sixMonths: calendar.date(byAdding: .month, value: -6, to: today)
        case .year: calendar.date(byAdding: .year, value: -1, to: today)
        case .all: nil
        }
    }
}

/// What the chart plots. A bodyweight exercise has no meaningful 1RM or volume,
/// so it gets a different pair.
enum ExerciseMetric: String, CaseIterable, Identifiable {
    case e1rm, volume, maxReps, addedWeight

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .e1rm: "Est. 1RM"
        case .volume: "Volume"
        case .maxReps: "Max reps"
        case .addedWeight: "Added weight"
        }
    }

    /// Reps are a count; everything else is a load and needs unit conversion.
    var isWeight: Bool { self != .maxReps }

    static func options(bodyweight: Bool) -> [ExerciseMetric] {
        bodyweight ? [.maxReps, .addedWeight] : [.e1rm, .volume]
    }
}

struct ExerciseProgress {
    /// Lifetime, deliberately unaffected by the chart range — a record is a
    /// record whether or not it falls inside the window you are looking at.
    let records: PRSet
    let sessionCount: Int
    let lastPerformed: Date?
    let points: [SeriesPoint]

    static let empty = ExerciseProgress(
        records: PRSet(maxWeightKg: nil, maxReps: nil, bestE1RM: nil),
        sessionCount: 0,
        lastPerformed: nil,
        points: []
    )

    var hasHistory: Bool { sessionCount > 0 }
}

@MainActor
enum ExerciseProgressBuilder {
    static func build(
        exerciseID: UUID,
        sessions: [WorkoutSession],
        metric: ExerciseMetric,
        range: ChartRange,
        today: Date = .now,
        calendar: Calendar = .current
    ) -> ExerciseProgress {
        let inputs = sessions.filter { $0.endedAt != nil }.map(\.coreInput)

        let trained = inputs.filter { session in
            session.exercises.contains { exercise in
                exercise.exercise.id == exerciseID && !workingSets(exercise.sets).isEmpty
            }
        }
        guard !trained.isEmpty else { return .empty }

        let windowed: [SessionInput]
        if let start = range.start(endingOn: today, calendar: calendar) {
            windowed = inputs.filter { $0.startedAt >= start }
        } else {
            windowed = inputs
        }

        return ExerciseProgress(
            records: personalRecords(inputs, exerciseID: exerciseID),
            sessionCount: trained.count,
            lastPerformed: trained.map(\.startedAt).max(),
            points: series(windowed, exerciseID: exerciseID, metric: metric)
        )
    }

    private static func series(
        _ sessions: [SessionInput],
        exerciseID: UUID,
        metric: ExerciseMetric
    ) -> [SeriesPoint] {
        switch metric {
        case .e1rm: e1rmSeries(sessions, exerciseID: exerciseID)
        case .volume: exerciseVolumeSeries(sessions, exerciseID: exerciseID)
        case .maxReps: maxRepsSeries(sessions, exerciseID: exerciseID)
        case .addedWeight: addedWeightSeries(sessions, exerciseID: exerciseID)
        }
    }
}
