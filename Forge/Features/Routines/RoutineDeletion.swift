import Foundation
import SwiftData

/// Same rule as `ExerciseDeletion`: a routine referenced by history is
/// archived rather than deleted, so past sessions keep their context.
enum RoutineDeletion {
    @MainActor
    static func canHardDelete(_ routine: Routine) -> Bool {
        guard let context = routine.modelContext else { return true }
        // SwiftData predicates over optional relationships are unreliable, and
        // the session count is small for a personal app, so filter in Swift.
        let sessions = (try? context.fetch(FetchDescriptor<WorkoutSession>())) ?? []
        return !sessions.contains { $0.sourceRoutine?.id == routine.id }
    }
}
