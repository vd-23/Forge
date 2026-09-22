import Testing
import Foundation
import SwiftData
@testable import Forge

@Suite @MainActor
struct BodyPartCatalogTests {
    let container = PersistenceController.makeInMemoryContainer()
    var ctx: ModelContext { container.mainContext }
    let defaults = UserDefaults(suiteName: "BodyPartCatalogTests-\(UUID().uuidString)")!

    var catalog: BodyPartCatalog { BodyPartCatalog(defaults: defaults) }

    @Test func builtInsKeepTheirRawValuesAndNames() {
        #expect(BodyPart.chest.rawValue == "chest")
        #expect(BodyPart.fullBody.displayName == "Full Body")
        #expect(BodyPart(rawValue: "quads") == .quads)
        #expect(BodyPart.builtIn.count == 15)
    }

    @Test func allStartsAsBuiltInsAndGrowsWithCustomOnes() throws {
        #expect(catalog.all == BodyPart.builtIn)
        let neck = try catalog.add("Neck")
        #expect(neck.displayName == "Neck")
        #expect(neck.isCustom)
        #expect(catalog.all.last == neck)
        #expect(catalog.custom == [neck])
    }

    @Test func addRejectsBlankDuplicateAndBuiltInNames() throws {
        #expect(throws: BodyPartCatalog.Error.emptyName) { try catalog.add("   ") }
        _ = try catalog.add("Neck")
        #expect(throws: BodyPartCatalog.Error.duplicate) { try catalog.add("neck") }
        #expect(throws: BodyPartCatalog.Error.duplicate) { try catalog.add("Chest") }
    }

    @Test func renamePropagatesToExercises() throws {
        let neck = try catalog.add("Neck")
        let exercise = Exercise(name: "Neck curl", primaryBodyPart: neck)
        ctx.insert(exercise)

        let renamed = try catalog.rename(neck, to: "Cervical", in: ctx)
        #expect(renamed.displayName == "Cervical")
        #expect(exercise.primaryBodyPart == renamed)
        #expect(catalog.custom == [renamed])
    }

    @Test func removeIsBlockedWhileInUse() throws {
        let neck = try catalog.add("Neck")
        let exercise = Exercise(name: "Neck curl", primaryBodyPart: neck)
        ctx.insert(exercise)

        #expect(throws: BodyPartCatalog.Error.inUse(count: 1)) { try catalog.remove(neck, in: ctx) }
        ctx.delete(exercise)
        try catalog.remove(neck, in: ctx)
        #expect(catalog.custom.isEmpty)
    }

    @Test func unknownRawValueStillDisplaysItsName() {
        // A custom part that was later removed shouldn't vanish from old exercises.
        let orphan = BodyPart(rawValue: "custom:Neck")
        #expect(orphan.displayName == "Neck")
        #expect(orphan.isCustom)
    }
}
