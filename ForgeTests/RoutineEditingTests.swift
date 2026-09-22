import Testing
import SwiftData
@testable import Forge

@Suite @MainActor
struct RoutineEditingTests {
    let container = PersistenceController.makeInMemoryContainer()
    var ctx: ModelContext { container.mainContext }

    private func exercises(_ count: Int) -> [Exercise] {
        (0..<count).map { i in
            let exercise = Exercise(name: "Ex \(i)", primaryBodyPart: .chest)
            ctx.insert(exercise)
            return exercise
        }
    }

    @Test func addingSeveralAppendsInOrderWithDefaultSets() {
        let routine = Routine(name: "Push")
        ctx.insert(routine)
        let picked = exercises(3)
        let added = RoutineEditing.add(picked, to: routine)
        #expect(added == 3)
        #expect(routine.orderedItems.map(\.order) == [0, 1, 2])
        #expect(routine.orderedItems.map { $0.exercise?.name } == ["Ex 0", "Ex 1", "Ex 2"])
        #expect(routine.orderedItems.allSatisfy { $0.targetSets == RoutineEditing.defaultTargetSets })
    }

    @Test func addingContinuesAfterExistingItems() {
        let routine = Routine(name: "Push")
        ctx.insert(routine)
        let picked = exercises(2)
        RoutineEditing.add([picked[0]], to: routine)
        RoutineEditing.add([picked[1]], to: routine)
        #expect(routine.orderedItems.map(\.order) == [0, 1])
    }

    @Test func addingStopsAtTheRoutineLimit() {
        let routine = Routine(name: "Everything")
        ctx.insert(routine)
        let picked = exercises(Limits.maxItemsPerRoutine + 5)
        let added = RoutineEditing.add(picked, to: routine)
        #expect(added == Limits.maxItemsPerRoutine)
        #expect(routine.items.count == Limits.maxItemsPerRoutine)
    }

    @Test func setsAreClampedToTheAllowedRange() {
        let routine = Routine(name: "Push")
        ctx.insert(routine)
        RoutineEditing.add(exercises(1), to: routine)
        let item = routine.orderedItems[0]
        RoutineEditing.setTargetSets(item, to: 0)
        #expect(item.targetSets == 1)
        RoutineEditing.setTargetSets(item, to: Limits.maxSetsPerExercise + 10)
        #expect(item.targetSets == Limits.maxSetsPerExercise)
        RoutineEditing.setTargetSets(item, to: 5)
        #expect(item.targetSets == 5)
    }
}
