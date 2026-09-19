import Foundation
import SwiftData

/// Looks up what was logged the last time an exercise was trained, so the
/// active workout can show a reference line above today's sets.
enum LastPerformance {
    /// Working sets from the most recent finished session that actually trained
    /// `exerciseID`, ignoring the session in progress. A session where the
    /// exercise was only warmed up is skipped in favour of an older one.
    ///
    /// Sessions are fetched and scanned newest-first in Swift rather than
    /// filtered by a predicate on `WorkoutExercise`: reaching the session from
    /// there means traversing an optional to-one relationship, which
    /// `#Predicate` does not handle reliably.
    static func mostRecentSets(
        ofExerciseID exerciseID: UUID,
        excludingSession sessionID: UUID,
        in context: ModelContext
    ) -> [ExerciseSet] {
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.endedAt != nil },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        guard let sessions = try? context.fetch(descriptor) else { return [] }

        for session in sessions where session.id != sessionID {
            let sets = session.orderedExercises
                .filter { $0.exerciseID == exerciseID }
                .flatMap(\.orderedSets)
                .filter(\.isWorkingSet)
            if !sets.isEmpty { return sets }
        }
        return []
    }

    /// `"100 kg × 5, 5, 4 · 95 kg × 8"` — consecutive sets at the same load are
    /// collapsed into a single rep list, the way a lifter would write them down.
    /// Returns `nil` when there is nothing to show.
    static func summary(of sets: [ExerciseSet], isBodyweight: Bool, unit: WeightUnit) -> String? {
        guard !sets.isEmpty else { return nil }

        var groups: [(load: String, reps: [Int])] = []
        for set in sets {
            let load = SetFormatting.loadLabel(set, isBodyweight: isBodyweight, unit: unit)
            if groups.last?.load == load {
                groups[groups.count - 1].reps.append(set.reps)
            } else {
                groups.append((load, [set.reps]))
            }
        }

        return groups
            .map { "\($0.load) × \($0.reps.map(String.init).joined(separator: ", "))" }
            .joined(separator: " · ")
    }
}
