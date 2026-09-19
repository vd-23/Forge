import Foundation
import SwiftData

@Model
final class RoutineItem {
    var routine: Routine?
    var exercise: Exercise?
    var order: Int
    var targetSets: Int?
    var targetRepMin: Int?
    var targetRepMax: Int?
    var targetRestSeconds: Int?

    init(
        exercise: Exercise,
        order: Int,
        targetSets: Int? = nil,
        targetRepMin: Int? = nil,
        targetRepMax: Int? = nil,
        targetRestSeconds: Int? = nil
    ) {
        self.exercise = exercise
        self.order = order
        self.targetSets = targetSets
        self.targetRepMin = targetRepMin
        self.targetRepMax = targetRepMax
        self.targetRestSeconds = targetRestSeconds
    }
}
