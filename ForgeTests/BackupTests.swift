import Testing
import Foundation
import SwiftData
@testable import Forge

@Suite @MainActor
struct BackupTests {
    let defaults = UserDefaults(suiteName: "BackupTests-\(UUID().uuidString)")!

    /// A small but complete world: a custom body part, two exercises, a
    /// routine with targets, one finished session with a warm-up and an
    /// archived exercise.
    private func populate(_ ctx: ModelContext, defaults: UserDefaults? = nil) throws -> (Exercise, Routine, WorkoutSession) {
        let catalog = BodyPartCatalog(defaults: defaults ?? self.defaults)
        let neck = try catalog.add("Neck")

        let squat = Exercise(name: "Squat", primaryBodyPart: .quads, defaultRestSeconds: 180)
        let neckCurl = Exercise(name: "Neck curl", primaryBodyPart: neck, isBodyweight: true)
        neckCurl.isArchived = true
        ctx.insert(squat); ctx.insert(neckCurl)

        let routine = Routine(name: "Legs")
        routine.items = [RoutineItem(exercise: squat, order: 0, targetSets: 3, targetRepMin: 5, targetRepMax: 5, targetRestSeconds: 200)]
        ctx.insert(routine)

        let session = WorkoutSession(startedAt: Date(timeIntervalSince1970: 1_000_000), sourceRoutine: routine, sourceRoutineName: "Legs")
        session.endedAt = Date(timeIntervalSince1970: 1_003_600)
        session.notes = "felt strong"
        let we = WorkoutExercise(exercise: squat, exerciseID: squat.id, order: 0, targetSets: 3, targetRepMin: 5, targetRepMax: 5, restSeconds: 200)
        let warm = ExerciseSet(order: 0, weightKg: 60, reps: 8, isWarmup: true); warm.isComplete = true
        let work = ExerciseSet(order: 1, weightKg: 100, reps: 5, rpe: 8); work.isComplete = true; work.completedAt = session.endedAt
        we.sets = [warm, work]
        session.exercises = [we]
        ctx.insert(session)
        routine.lastPerformedAt = session.endedAt
        routine.sortOrder = 7
        try ctx.save()
        return (squat, routine, session)
    }

    @Test func roundTripsEverything() throws {
        let source = PersistenceController.makeInMemoryContainer()
        let (squat, routine, session) = try populate(source.mainContext)
        Preferences(defaults: defaults).weightUnit = .lb

        let data = try BackupCoder.export(from: source.mainContext, defaults: defaults)

        let target = PersistenceController.makeInMemoryContainer()
        let targetDefaults = UserDefaults(suiteName: "BackupTests-target-\(UUID().uuidString)")!
        let summary = try BackupCoder.restore(data, into: target.mainContext, defaults: targetDefaults)
        #expect(summary.exercises == 2 && summary.routines == 1 && summary.sessions == 1)

        let ctx = target.mainContext
        let exercises = try ctx.fetch(FetchDescriptor<Exercise>(sortBy: [SortDescriptor(\.name)]))
        #expect(exercises.map(\.name) == ["Neck curl", "Squat"])
        #expect(exercises[1].id == squat.id, "ids survive so history keeps pointing at the same exercise")
        #expect(exercises[1].defaultRestSeconds == 180)
        #expect(exercises[0].isArchived && exercises[0].isBodyweight)
        #expect(exercises[0].primaryBodyPart.displayName == "Neck")
        #expect(BodyPartCatalog(defaults: targetDefaults).custom.map(\.displayName) == ["Neck"])
        #expect(Preferences(defaults: targetDefaults).weightUnit == .lb)

        let routines = try ctx.fetch(FetchDescriptor<Routine>())
        #expect(routines.count == 1 && routines[0].id == routine.id)
        #expect(routines[0].orderedItems.first?.targetRestSeconds == 200)
        #expect(routines[0].orderedItems.first?.exercise?.id == squat.id)
        #expect(routines[0].lastPerformedAt == session.endedAt)
        #expect(routines[0].sortOrder == 7)

        let sessions = try ctx.fetch(FetchDescriptor<WorkoutSession>())
        #expect(sessions.count == 1 && sessions[0].id == session.id)
        #expect(sessions[0].notes == "felt strong")
        #expect(sessions[0].sourceRoutine?.id == routine.id)
        let sets = try #require(sessions[0].orderedExercises.first?.orderedSets)
        #expect(sets.map(\.isWarmup) == [true, false])
        #expect(sets[1].rpe == 8 && sets[1].weightKg == 100 && sets[1].isComplete)
        #expect(sessions[0].orderedExercises.first?.exercise?.id == squat.id)
    }

    @Test func restoreReplacesWhatWasThere() throws {
        let source = PersistenceController.makeInMemoryContainer()
        _ = try populate(source.mainContext)
        let data = try BackupCoder.export(from: source.mainContext, defaults: defaults)

        let target = PersistenceController.makeInMemoryContainer()
        PersistenceController.seedIfEmpty(target.mainContext)
        // Existing routines and history are what made the batch delete fail.
        _ = try populate(target.mainContext, defaults: UserDefaults(suiteName: "BackupTests-existing-\(UUID().uuidString)")!)
        #expect(try target.mainContext.fetch(FetchDescriptor<Exercise>()).count > 2)

        _ = try BackupCoder.restore(data, into: target.mainContext, defaults: defaults)
        let ctx = target.mainContext
        #expect(try ctx.fetch(FetchDescriptor<Exercise>()).count == 2)
        #expect(try ctx.fetch(FetchDescriptor<Routine>()).count == 1)
        #expect(try ctx.fetch(FetchDescriptor<RoutineItem>()).count == 1, "old items must not be orphaned")
        #expect(try ctx.fetch(FetchDescriptor<WorkoutSession>()).count == 1)
        #expect(try ctx.fetch(FetchDescriptor<WorkoutExercise>()).count == 1)
        #expect(try ctx.fetch(FetchDescriptor<ExerciseSet>()).count == 2)
    }

    @Test func exportSkipsTheUnfinishedSession() throws {
        let source = PersistenceController.makeInMemoryContainer()
        let (_, routine, _) = try populate(source.mainContext)
        let controller = WorkoutController(context: source.mainContext)
        _ = try controller.start(from: routine)

        let backup = try BackupCoder.decode(try BackupCoder.export(from: source.mainContext, defaults: defaults))
        #expect(backup.sessions.count == 1)
        #expect(backup.sessions.allSatisfy { $0.endedAt != nil })
    }

    @Test func rejectsUnknownFormatVersion() throws {
        let json = #"{"version": 99, "exercises": []}"#.data(using: .utf8)!
        let target = PersistenceController.makeInMemoryContainer()
        #expect(throws: BackupCoder.Error.unsupportedVersion(99)) {
            try BackupCoder.restore(json, into: target.mainContext, defaults: defaults)
        }
    }

    @Test func rejectsGarbage() throws {
        let target = PersistenceController.makeInMemoryContainer()
        #expect(throws: BackupCoder.Error.self) {
            try BackupCoder.restore(Data("nope".utf8), into: target.mainContext, defaults: defaults)
        }
    }
}
