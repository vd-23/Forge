import Testing
import Foundation
import SwiftData
@testable import Forge

@Suite @MainActor
struct RoutineOrderingTests {
    let container = PersistenceController.makeInMemoryContainer()
    var ctx: ModelContext { container.mainContext }

    private func make(_ names: [String]) -> [Routine] {
        names.map { name in
            let routine = Routine(name: name)
            ctx.insert(routine)
            return routine
        }
    }

    @Test func routinesWithoutAnOrderFallBackToCreationThenName() {
        let routines = make(["Pull", "Push"])
        routines[0].createdAt = .distantPast
        #expect(RoutineOrdering.ordered(routines).map(\.name) == ["Pull", "Push"])
        routines[1].createdAt = routines[0].createdAt
        #expect(RoutineOrdering.ordered(routines).map(\.name) == ["Pull", "Push"])
    }

    @Test func sortOrderWinsOverCreationDate() {
        let routines = make(["A", "B", "C"])
        routines[2].sortOrder = 0
        routines[0].sortOrder = 1
        routines[1].sortOrder = 2
        #expect(RoutineOrdering.ordered(routines).map(\.name) == ["C", "A", "B"])
    }

    @Test func movingRewritesEveryOrderContiguously() {
        let routines = make(["A", "B", "C", "D"])
        for (index, routine) in routines.enumerated() { routine.sortOrder = index }
        RoutineOrdering.move(routines, from: IndexSet(integer: 3), to: 0)
        #expect(RoutineOrdering.ordered(routines).map(\.name) == ["D", "A", "B", "C"])
        #expect(RoutineOrdering.ordered(routines).map(\.sortOrder) == [0, 1, 2, 3])
    }

    @Test func newRoutinesGoToTheEnd() throws {
        let routines = make(["A", "B"])
        routines[0].sortOrder = 4
        routines[1].sortOrder = 9
        try ctx.save()
        #expect(RoutineOrdering.nextSortOrder(in: ctx) == 10)
        let empty = PersistenceController.makeInMemoryContainer()
        #expect(RoutineOrdering.nextSortOrder(in: empty.mainContext) == 0)
    }

    @Test func duplicatesLandAfterTheOriginals() throws {
        let routines = make(["A"])
        routines[0].sortOrder = 3
        try ctx.save()
        let copy = RoutineDuplication.duplicate(routines[0], into: ctx)
        #expect(copy.sortOrder == 4)
    }
}
