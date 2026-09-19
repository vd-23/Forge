import Foundation

/// The best weight, rep count, and estimated 1RM ever recorded for one exercise.
/// Any field is `nil` when there is no qualifying working set in history.
public struct PRSet: Sendable, Equatable {
    public let maxWeightKg: Double?
    public let maxReps: Int?
    public let bestE1RM: Double?

    public init(maxWeightKg: Double?, maxReps: Int?, bestE1RM: Double?) {
        self.maxWeightKg = maxWeightKg
        self.maxReps = maxReps
        self.bestE1RM = bestE1RM
    }
}

public enum PRKind: Sendable, Equatable, Hashable {
    case weight, reps, e1rm
}

/// A personal record achieved in a specific session.
public struct PRHit: Sendable, Equatable {
    public let exerciseID: UUID
    public let kind: PRKind
    public let value: Double

    public init(exerciseID: UUID, kind: PRKind, value: Double) {
        self.exerciseID = exerciseID
        self.kind = kind
        self.value = value
    }
}

/// All working sets for one exercise across finished sessions.
private func workingSetsForExercise(_ sessions: [SessionInput], exerciseID: UUID) -> [SetInput] {
    sessions
        .filter(\.isFinished)
        .flatMap(\.exercises)
        .filter { $0.exercise.id == exerciseID }
        .flatMap { workingSets($0.sets) }
}

/// Aggregate personal records for one exercise over the given sessions
/// (finished sessions only).
public func personalRecords(_ sessions: [SessionInput], exerciseID: UUID) -> PRSet {
    let sets = workingSetsForExercise(sessions, exerciseID: exerciseID)
    let weights = sets.compactMap(\.weightKg)
    let e1rms = sets.compactMap { set -> Double? in
        guard let weight = set.weightKg else { return nil }
        return estimatedOneRepMax(weightKg: weight, reps: set.reps)
    }
    return PRSet(
        maxWeightKg: weights.max(),
        maxReps: sets.map(\.reps).max(),
        bestE1RM: e1rms.max()
    )
}

/// Records set by `session` that exceed everything in `history`.
/// `history` MUST NOT contain `session`.
public func newPersonalRecords(in session: SessionInput, history: [SessionInput]) -> [PRHit] {
    var hits: [PRHit] = []

    for workoutExercise in session.exercises {
        let exerciseID = workoutExercise.exercise.id
        let todaysSets = workingSets(workoutExercise.sets)
        guard !todaysSets.isEmpty else { continue }

        let previous = personalRecords(history, exerciseID: exerciseID)

        if let bestWeight = todaysSets.compactMap(\.weightKg).max(),
           bestWeight > (previous.maxWeightKg ?? 0) {
            hits.append(PRHit(exerciseID: exerciseID, kind: .weight, value: bestWeight))
        }
        if let bestReps = todaysSets.map(\.reps).max(),
           bestReps > (previous.maxReps ?? 0) {
            hits.append(PRHit(exerciseID: exerciseID, kind: .reps, value: Double(bestReps)))
        }
        if let bestE1RM = sessionBestE1RM(session, exerciseID: exerciseID),
           bestE1RM > (previous.bestE1RM ?? 0) {
            hits.append(PRHit(exerciseID: exerciseID, kind: .e1rm, value: bestE1RM))
        }
    }
    return hits
}
