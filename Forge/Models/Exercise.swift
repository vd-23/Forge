import Foundation
import SwiftData

@Model
final class Exercise {
    /// Stable identifier used by history queries and the ForgeCore mapping.
    /// `@Model` already provides `persistentModelID`, but an explicit `UUID`
    /// is stable across contexts and safe to use inside `#Predicate`.
    @Attribute(.unique) var id: UUID = UUID()
    var name: String
    var primaryBodyPartRaw: String
    var isBodyweight: Bool
    var isUnilateral: Bool
    var defaultRestSeconds: Int?
    var isArchived: Bool
    var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \RoutineItem.exercise)
    var routineItems: [RoutineItem] = []

    init(
        name: String,
        primaryBodyPart: BodyPart,
        isBodyweight: Bool = false,
        isUnilateral: Bool = false,
        defaultRestSeconds: Int? = nil
    ) {
        self.name = name
        self.primaryBodyPartRaw = primaryBodyPart.rawValue
        self.isBodyweight = isBodyweight
        self.isUnilateral = isUnilateral
        self.defaultRestSeconds = defaultRestSeconds
        self.isArchived = false
        self.createdAt = .now
    }

    var primaryBodyPart: BodyPart {
        get { BodyPart(rawValue: primaryBodyPartRaw) ?? .other }
        set { primaryBodyPartRaw = newValue.rawValue }
    }
}
