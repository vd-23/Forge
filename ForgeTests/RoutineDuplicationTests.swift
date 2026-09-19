import Testing
import SwiftData
@testable import Forge

@Suite @MainActor
struct RoutineDuplicationTests {
    let container = PersistenceController.makeInMemoryContainer()
    var ctx: ModelContext { container.mainContext }

    @Test func deepCopiesItemsAndKeepsExerciseReferences() throws {
        let squat = Exercise(name: "Squat", primaryBodyPart: .quads)
        let curl = Exercise(name: "Curl", primaryBodyPart: .biceps)
        ctx.insert(squat)
        ctx.insert(curl)

        let original = Routine(name: "Legs & Arms")
        original.items = [
            RoutineItem(exercise: squat, order: 0, targetSets: 3, targetRepMin: 5, targetRepMax: 5),
            RoutineItem(exercise: curl, order: 1, targetSets: 3, targetRepMin: 8, targetRepMax: 12),
        ]
        original.lastPerformedAt = .now
        ctx.insert(original)
        try ctx.save()

        let copy = RoutineDuplication.duplicate(original, into: ctx)
        try ctx.save()

        #expect(copy.name == "Legs & Arms Copy")
        #expect(copy.lastPerformedAt == nil)
        #expect(copy.orderedItems.count == 2)
        #expect(copy.orderedItems[0].exercise === squat)           // same exercise reference
        #expect(copy.orderedItems[0].targetSets == 3)
        #expect(copy.orderedItems[1].targetRepMax == 12)
        #expect(original.orderedItems[0] !== copy.orderedItems[0])  // distinct item objects
        #expect(try ctx.fetch(FetchDescriptor<Routine>()).count == 2)
    }

    @Test func copyingARoutineWithNoItemsProducesAnEmptyCopy() throws {
        let original = Routine(name: "Empty")
        ctx.insert(original)
        try ctx.save()

        let copy = RoutineDuplication.duplicate(original, into: ctx)
        try ctx.save()

        #expect(copy.name == "Empty Copy")
        #expect(copy.orderedItems.isEmpty)
    }
}
