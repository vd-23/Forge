import Foundation

/// Mutations shared by the routine editor and the exercise picker.
@MainActor
enum RoutineEditing {
    /// A fresh routine item starts with a real target so the workout screen
    /// pre-creates sets straight away; the editor's stepper adjusts it.
    static let defaultTargetSets = 3

    /// Appends `exercises` after the routine's existing items, in the order
    /// given, stopping at the per-routine cap. Returns how many were added.
    @discardableResult
    static func add(_ exercises: [Exercise], to routine: Routine) -> Int {
        var order = routine.items.count
        var added = 0
        for exercise in exercises {
            guard routine.items.count < Limits.maxItemsPerRoutine else { break }
            routine.items.append(RoutineItem(exercise: exercise, order: order, targetSets: defaultTargetSets))
            order += 1
            added += 1
        }
        return added
    }

    static func setTargetSets(_ item: RoutineItem, to sets: Int) {
        item.targetSets = min(max(sets, 1), Limits.maxSetsPerExercise)
    }
}
