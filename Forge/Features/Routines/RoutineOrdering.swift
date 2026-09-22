import Foundation
import SwiftData

/// User-defined order of routines in the Workout tab. `sortOrder` is only
/// meaningful relative to the other routines, so every move rewrites all of
/// them contiguously and a new routine takes the next free slot.
@MainActor
enum RoutineOrdering {
    static func ordered(_ routines: [Routine]) -> [Routine] {
        routines.sorted { lhs, rhs in
            if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
            if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
            return lhs.name < rhs.name
        }
    }

    static func move(_ routines: [Routine], from source: IndexSet, to destination: Int) {
        var reordered = ordered(routines)
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, routine) in reordered.enumerated() {
            routine.sortOrder = index
        }
    }

    static func nextSortOrder(in context: ModelContext) -> Int {
        var descriptor = FetchDescriptor<Routine>(sortBy: [SortDescriptor(\.sortOrder, order: .reverse)])
        descriptor.fetchLimit = 1
        guard let last = try? context.fetch(descriptor).first else { return 0 }
        return last.sortOrder + 1
    }
}
