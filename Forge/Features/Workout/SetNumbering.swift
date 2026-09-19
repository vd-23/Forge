import Foundation
import SwiftData

/// How set rows are labelled inside an exercise card.
enum SetNumbering {
    /// The field is `exerciseSet` rather than `set` because a computed property
    /// starting with `set.` parses as a setter definition.
    struct Numbered: Identifiable {
        let exerciseSet: ExerciseSet
        /// "1", "2", … for working sets; "W" for warm-ups.
        let label: String

        var id: PersistentIdentifier { exerciseSet.persistentModelID }
    }

    /// Working sets are numbered by position, not by the stored `order`.
    /// Deleting the second of three sets should leave 1, 2 — deriving the label
    /// from `order` left a gap and showed 1, 3.
    ///
    /// Warm-ups are labelled rather than numbered, so they don't consume a
    /// working-set number.
    static func number(_ sets: [ExerciseSet]) -> [Numbered] {
        var workingSetCount = 0
        return sets.map { set in
            guard !set.isWarmup else { return Numbered(exerciseSet: set, label: "W") }
            workingSetCount += 1
            return Numbered(exerciseSet: set, label: "\(workingSetCount)")
        }
    }
}
