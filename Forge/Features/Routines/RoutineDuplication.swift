import Foundation
import SwiftData

enum RoutineDuplication {
    /// Deep-copies a routine: new `Routine` and new `RoutineItem`s carrying the
    /// same targets, pointing at the same `Exercise` objects. The copy has never
    /// been performed, so `lastPerformedAt` starts nil.
    @MainActor
    @discardableResult
    static func duplicate(_ routine: Routine, into context: ModelContext) -> Routine {
        let copy = Routine(name: routine.name + " Copy")
        copy.sortOrder = RoutineOrdering.nextSortOrder(in: context)
        context.insert(copy)

        for item in routine.orderedItems {
            guard let exercise = item.exercise else { continue }
            copy.items.append(RoutineItem(
                exercise: exercise,
                order: item.order,
                targetSets: item.targetSets,
                targetRepMin: item.targetRepMin,
                targetRepMax: item.targetRepMax,
                targetRestSeconds: item.targetRestSeconds
            ))
        }
        return copy
    }
}
