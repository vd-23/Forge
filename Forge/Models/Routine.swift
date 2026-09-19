import Foundation
import SwiftData

@Model
final class Routine {
    @Attribute(.unique) var id: UUID = UUID()
    var name: String
    var isArchived: Bool
    var createdAt: Date
    var lastPerformedAt: Date?

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
