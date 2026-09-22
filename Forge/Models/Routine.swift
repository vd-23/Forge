import Foundation
import SwiftData

@Model
final class Routine {
    @Attribute(.unique) var id: UUID = UUID()
    var name: String
    var isArchived: Bool
    var createdAt: Date
    var lastPerformedAt: Date?
    /// Position in the Workout tab grid. Added after the first stores shipped,
    /// so it defaults to 0 and `RoutineOrdering` breaks ties by creation date.
    var sortOrder: Int = 0

    @Relationship(deleteRule: .cascade, inverse: \RoutineItem.routine)
    var items: [RoutineItem] = []

    init(name: String) {
        self.name = name
        self.isArchived = false
        self.createdAt = .now
        self.lastPerformedAt = nil
    }

    var orderedItems: [RoutineItem] {
        items.sorted { $0.order < $1.order }
    }
}
