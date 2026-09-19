import SwiftData
import Testing
@testable import Forge

@Suite @MainActor
struct ArchiveScopeTests {
    /// Held as a stored property so the container outlives the context.
    let container = PersistenceController.makeInMemoryContainer()
    var ctx: ModelContext { container.mainContext }

    @Test func scopeMapsOntoTheArchivedFlag() {
        #expect(ArchiveScope.active.isArchived == false)
        #expect(ArchiveScope.archived.isArchived == true)
    }

    /// The lists split one query by `isArchived == scope.isArchived`, so an
    /// archived row must appear in exactly one scope and never both.
    @Test func everyRowBelongsToExactlyOneScope() {
        let active = Exercise(name: "Squat", primaryBodyPart: .quads)
        let retired = Exercise(name: "Smith Machine Squat", primaryBodyPart: .quads)
        retired.isArchived = true
        ctx.insert(active)
        ctx.insert(retired)

        let all = [active, retired]
        for scope in ArchiveScope.allCases {
            let shown = all.filter { $0.isArchived == scope.isArchived }
            #expect(shown.count == 1)
        }
    }

    @Test func unarchivingMovesARowBackToActive() {
        let exercise = Exercise(name: "Dip", primaryBodyPart: .chest)
        exercise.isArchived = true
        ctx.insert(exercise)

        exercise.isArchived = false

        #expect([exercise].filter { $0.isArchived == ArchiveScope.active.isArchived }.count == 1)
        #expect([exercise].filter { $0.isArchived == ArchiveScope.archived.isArchived }.isEmpty)
    }
}
