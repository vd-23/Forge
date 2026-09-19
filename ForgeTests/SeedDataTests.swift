import Testing
import SwiftData
@testable import Forge

@Suite @MainActor
struct SeedDataTests {
    @Test func seedsAFreshStore() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = container.mainContext

        PersistenceController.seedIfEmpty(context)
        let exercises = try context.fetch(FetchDescriptor<Exercise>())

        #expect(exercises.count == seedExercises.count)
        #expect(exercises.contains { $0.name == "Barbell Bench Press" })
        #expect(exercises.first { $0.name == "Pull-up" }?.isBodyweight == true)
        #expect(exercises.first { $0.name == "Bulgarian Split Squat" }?.isUnilateral == true)
    }

    @Test func seedingIsIdempotent() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = container.mainContext

        PersistenceController.seedIfEmpty(context)
        PersistenceController.seedIfEmpty(context)

        #expect(try context.fetch(FetchDescriptor<Exercise>()).count == seedExercises.count)
    }
}
