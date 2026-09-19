import Foundation
import SwiftData

@Model
final class WorkoutSession {
    @Attribute(.unique) var id: UUID = UUID()
    var startedAt: Date
    var endedAt: Date?
    var notes: String?
    var sourceRoutine: Routine?
    var sourceRoutineName: String

    @Relationship(deleteRule: .cascade, inverse: \WorkoutExercise.session)
    var exercises: [WorkoutExercise] = []

    init(startedAt: Date = .now, sourceRoutine: Routine?, sourceRoutineName: String) {
        self.startedAt = startedAt
        self.endedAt = nil
        self.sourceRoutine = sourceRoutine
        self.sourceRoutineName = sourceRoutineName
    }

    var isActive: Bool { endedAt == nil }

    var orderedExercises: [WorkoutExercise] {
        exercises.sorted { $0.order < $1.order }
    }
}
