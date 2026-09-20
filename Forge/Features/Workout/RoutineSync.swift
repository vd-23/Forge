import Foundation

/// Compares what a workout ended up doing against the routine it started from,
/// so Finish can offer to make the routine match.
enum RoutineSync {
    /// One exercise as the workout had it, captured before Finish prunes the
    /// session — skipping an exercise isn't a request to drop it from the plan.
    struct PlannedExercise {
        let exercise: Exercise
        let targetSets: Int?
        let targetRepMin: Int?
        let targetRepMax: Int?
        let restSeconds: Int?
    }

    struct Diff: Equatable {
        let added: [String]
        let removed: [String]
        let reordered: Bool

        var isEmpty: Bool { added.isEmpty && removed.isEmpty && !reordered }

        var summary: String {
            var parts: [String] = []
            if !added.isEmpty { parts.append("added \(added.joined(separator: ", "))") }
            if !removed.isEmpty { parts.append("removed \(removed.joined(separator: ", "))") }
            if reordered { parts.append("reordered") }
            return parts.joined(separator: " · ").prefix(1).uppercased() + parts.joined(separator: " · ").dropFirst()
        }
    }

    @MainActor
    static func plan(from session: WorkoutSession) -> [PlannedExercise] {
        session.orderedExercises.compactMap { workoutExercise in
            guard let exercise = workoutExercise.exercise else { return nil }
            return PlannedExercise(
                exercise: exercise,
                targetSets: workoutExercise.targetSets,
                targetRepMin: workoutExercise.targetRepMin,
                targetRepMax: workoutExercise.targetRepMax,
                restSeconds: workoutExercise.restSeconds
            )
        }
    }

    /// `nil` when the routine is gone or archived, or nothing changed.
    @MainActor
    static func diff(plan: [PlannedExercise], against routine: Routine?) -> Diff? {
        guard let routine, !routine.isArchived else { return nil }
        let planned = plan.map(\.exercise.id)
        let current = routine.orderedItems.compactMap { $0.exercise?.id }
        guard planned != current else { return nil }

        let names = Dictionary(
            (plan.map { ($0.exercise.id, $0.exercise.name) } + routine.orderedItems.compactMap { item in
                item.exercise.map { ($0.id, $0.name) }
            }),
            uniquingKeysWith: { first, _ in first }
        )
        let added = planned.filter { !current.contains($0) }.compactMap { names[$0] }
        let removed = current.filter { !planned.contains($0) }.compactMap { names[$0] }
        let shared = planned.filter { current.contains($0) }
        let reordered = shared != current.filter { planned.contains($0) }

        let diff = Diff(added: added, removed: removed, reordered: reordered)
        return diff.isEmpty ? nil : diff
    }
}
