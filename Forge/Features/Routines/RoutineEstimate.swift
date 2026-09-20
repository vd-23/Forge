import Foundation

extension Routine {
    /// Rough planning aid: ~2.5 min per planned set, assuming 3 sets when the
    /// routine doesn't specify a target.
    var estimatedMinutes: Int {
        orderedItems.reduce(0) { total, item in
            total + Int(Double(item.targetSets ?? 3) * 2.5)
        }
    }

    var plannedSetCount: Int {
        orderedItems.reduce(0) { $0 + ($1.targetSets ?? 3) }
    }
}
