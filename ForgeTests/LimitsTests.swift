import Testing
import Foundation
import SwiftData
@testable import Forge

@Suite @MainActor
struct LimitsTests {
    let container = PersistenceController.makeInMemoryContainer()
    var ctx: ModelContext { container.mainContext }

    @Test func namesAreTrimmedAndCapped() {
        #expect(Limits.cleanName("  Bench  ") == "Bench")
        #expect(Limits.cleanName("   ") == nil)
        let long = String(repeating: "x", count: Limits.maxNameLength + 20)
        #expect(Limits.cleanName(long)?.count == Limits.maxNameLength)
        #expect(Limits.cleanName("a\nb\tc") == "a b c", "control characters collapse to spaces")
    }

    @Test func numericInputsAreClampedNotRejected() {
        #expect(Limits.clampWeightKg(-5) == nil)
        #expect(Limits.clampWeightKg(0) == nil)
        #expect(Limits.clampWeightKg(42.5) == 42.5)
        #expect(Limits.clampWeightKg(99_999) == Limits.maxWeightKg)
        #expect(Limits.clampWeightKg(.nan) == nil)
        #expect(Limits.clampWeightKg(.infinity) == Limits.maxWeightKg)

        #expect(Limits.clampReps(-3) == 0)
        #expect(Limits.clampReps(12) == 12)
        #expect(Limits.clampReps(5_000) == Limits.maxReps)
    }

    @Test func setsPerExerciseAreCapped() throws {
        let squat = Exercise(name: "Squat", primaryBodyPart: .quads)
        ctx.insert(squat)
        let routine = Routine(name: "Legs")
        routine.items = [RoutineItem(exercise: squat, order: 0)]
        ctx.insert(routine)
        let controller = WorkoutController(context: ctx)
        let session = try controller.start(from: routine)
        let we = session.orderedExercises[0]

        for _ in 0..<(Limits.maxSetsPerExercise + 5) {
            controller.addSet(to: we, weightKg: 100, addedWeightKg: nil, reps: 5, rpe: nil, isWarmup: false)
        }
        #expect(we.sets.count == Limits.maxSetsPerExercise)
        #expect(!controller.canAddSet(to: we))
    }

    @Test func exercisesPerSessionAreCapped() throws {
        let routine = Routine(name: "Everything")
        ctx.insert(routine)
        let controller = WorkoutController(context: ctx)
        let session = try controller.start(from: routine)

        for i in 0..<(Limits.maxExercisesPerWorkout + 3) {
            let exercise = Exercise(name: "E\(i)", primaryBodyPart: .other)
            ctx.insert(exercise)
            controller.addExercise(exercise, to: session)
        }
        #expect(session.exercises.count == Limits.maxExercisesPerWorkout)
        #expect(!controller.canAddExercise(to: session))
    }

    @Test func storeSizeIsReportedInBytes() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("LimitsTests-\(UUID().uuidString)")
        try Data(count: 1_500).write(to: url)
        try Data(count: 500).write(to: URL(fileURLWithPath: url.path + "-wal"))
        defer { try? FileManager.default.removeItem(at: url); try? FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + "-wal")) }

        let health = StoreHealth.measure(storeURL: url)
        #expect(health.bytes == 2_000)
        #expect(!health.isOverBudget)
        #expect(StoreHealth(bytes: StoreHealth.budgetBytes + 1).isOverBudget)
    }

    @Test func storeHealthFormatsForHumans() {
        #expect(StoreHealth(bytes: 0).label == "Zero KB")
        #expect(StoreHealth(bytes: 1_500_000).label.hasPrefix("1"))
    }
}
