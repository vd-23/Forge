import Testing
import Foundation
import SwiftData
@testable import Forge

@Suite @MainActor
struct ShortcutLauncherTests {
    let container = PersistenceController.makeInMemoryContainer()
    var ctx: ModelContext { container.mainContext }

    private func routine(_ name: String, archived: Bool = false) -> Routine {
        let squat = Exercise(name: "Squat \(name)", primaryBodyPart: .quads)
        ctx.insert(squat)
        let routine = Routine(name: name)
        routine.items = [RoutineItem(exercise: squat, order: 0, targetSets: 3)]
        routine.isArchived = archived
        ctx.insert(routine)
        try? ctx.save()
        return routine
    }

    @Test func startsTheRequestedRoutine() throws {
        let legs = routine("Legs")
        let controller = WorkoutController(context: ctx)

        let outcome = ShortcutLauncher.start(routineID: legs.id, controller: controller, context: ctx)

        #expect(outcome == .started)
        #expect(controller.activeSession?.sourceRoutine?.id == legs.id)
    }

    @Test func resumesWhenAWorkoutIsAlreadyRunning() throws {
        let legs = routine("Legs")
        let push = routine("Push")
        let controller = WorkoutController(context: ctx)
        _ = try controller.start(from: push)

        let outcome = ShortcutLauncher.start(routineID: legs.id, controller: controller, context: ctx)

        #expect(outcome == .resumedExisting)
        #expect(controller.activeSession?.sourceRoutine?.id == push.id)
    }

    @Test func refusesUnknownOrArchivedRoutines() throws {
        let archived = routine("Old", archived: true)
        let controller = WorkoutController(context: ctx)

        #expect(ShortcutLauncher.start(routineID: UUID(), controller: controller, context: ctx) == .notFound)
        #expect(ShortcutLauncher.start(routineID: archived.id, controller: controller, context: ctx) == .notFound)
        #expect(!controller.hasActiveSession)
    }

    @Test func pendingRequestIsConsumedOnce() {
        let defaults = UserDefaults(suiteName: "ShortcutLauncherTests-\(UUID().uuidString)")!
        let id = UUID()
        ShortcutLauncher.setPending(id, defaults: defaults)
        #expect(ShortcutLauncher.takePending(defaults: defaults) == id)
        #expect(ShortcutLauncher.takePending(defaults: defaults) == nil)
    }

    @Test func featuredRoutinesAreRecentFirstAndCappedAtFour() {
        let names = ["A", "B", "C", "D", "E", "F"]
        let routines = names.map { routine($0) }
        routines[2].lastPerformedAt = Date(timeIntervalSince1970: 300)  // C most recent
        routines[4].lastPerformedAt = Date(timeIntervalSince1970: 200)  // E
        routines[0].lastPerformedAt = Date(timeIntervalSince1970: 100)  // A
        try? ctx.save()

        let featured = ShortcutLauncher.featuredRoutines(in: ctx).map(\.name)
        #expect(featured == ["C", "E", "A", "B"], "performed ones first by recency, then unperformed by name")
        #expect(featured.count == ShortcutLauncher.shortcutSlots)
    }

    @Test func listsOnlyActiveRoutinesForTheShortcutMenu() {
        _ = routine("Legs")
        _ = routine("Old", archived: true)
        let names = ShortcutLauncher.availableRoutines(in: ctx).map(\.name)
        #expect(names == ["Legs"])
    }
}
