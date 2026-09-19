import Foundation
import SwiftData
import Testing
@testable import Forge

@Suite @MainActor
struct HistoryFilteringTests {
    /// Held as a stored property so the container outlives the context.
    let container = PersistenceController.makeInMemoryContainer()
    var ctx: ModelContext { container.mainContext }

    @discardableResult
    private func session(
        _ routine: String,
        daysAgo: Double,
        minutes: Double,
        weightKg: Double,
        reps: Int
    ) -> WorkoutSession {
        let exercise = Exercise(name: "Squat", primaryBodyPart: .quads)
        ctx.insert(exercise)

        let startedAt = Date.now.addingTimeInterval(-daysAgo * 24 * 3600)
        let session = WorkoutSession(startedAt: startedAt, sourceRoutine: nil, sourceRoutineName: routine)
        session.endedAt = startedAt.addingTimeInterval(minutes * 60)
        ctx.insert(session)

        let workoutExercise = WorkoutExercise(exercise: exercise, exerciseID: exercise.id, order: 0)
        let set = ExerciseSet(order: 0, weightKg: weightKg, reps: reps)
        set.isComplete = true
        workoutExercise.sets.append(set)
        session.exercises.append(workoutExercise)

        try? ctx.save()
        return session
    }

    /// Push is the oldest but heaviest; Legs is the newest but longest.
    private func makeHistory() -> [WorkoutSession] {
        [
            session("Push", daysAgo: 10, minutes: 40, weightKg: 200, reps: 5),   // 1000 kg
            session("Pull", daysAgo: 5, minutes: 30, weightKg: 100, reps: 5),    //  500 kg
            session("Legs", daysAgo: 1, minutes: 75, weightKg: 150, reps: 5),    //  750 kg
        ]
    }

    private func names(_ sessions: [WorkoutSession]) -> [String] {
        sessions.map(\.sourceRoutineName)
    }

    @Test func newestAndOldestAreMirrorImages() {
        let history = makeHistory()

        #expect(names(HistoryFiltering.apply(to: history, sort: .newest)) == ["Legs", "Pull", "Push"])
        #expect(names(HistoryFiltering.apply(to: history, sort: .oldest)) == ["Push", "Pull", "Legs"])
    }

    @Test func sortsByVolumeRatherThanDate() {
        let sorted = HistoryFiltering.apply(to: makeHistory(), sort: .mostVolume)
        #expect(names(sorted) == ["Push", "Legs", "Pull"])
    }

    @Test func sortsByDuration() {
        let sorted = HistoryFiltering.apply(to: makeHistory(), sort: .longest)
        #expect(names(sorted) == ["Legs", "Push", "Pull"])
    }

    @Test func filtersToASingleRoutineWithoutDisturbingTheSort() {
        let history = makeHistory()
        session("Push", daysAgo: 2, minutes: 20, weightKg: 60, reps: 5)
        let all = history + [session("Push", daysAgo: 20, minutes: 20, weightKg: 60, reps: 5)]

        let pushOnly = HistoryFiltering.apply(to: all, sort: .newest, routine: "Push")

        #expect(pushOnly.count == 2)
        #expect(pushOnly.allSatisfy { $0.sourceRoutineName == "Push" })
        #expect(pushOnly[0].startedAt > pushOnly[1].startedAt)
    }

    @Test func nilRoutineMeansEveryRoutine() {
        let history = makeHistory()
        #expect(HistoryFiltering.apply(to: history, sort: .newest, routine: nil).count == 3)
    }

    @Test func routineNamesAreUniqueAndAlphabetical() {
        let history = makeHistory() + [session("Push", daysAgo: 30, minutes: 20, weightKg: 60, reps: 5)]
        #expect(HistoryFiltering.routineNames(in: history) == ["Legs", "Pull", "Push"])
    }
}
