import Foundation
import Observation
import SwiftData

/// Owns the lifecycle of the single in-progress workout: starting one from a
/// routine, logging sets into it, and finishing or discarding it.
///
/// Exactly one session may be active at a time. The controller recovers an
/// already-open session on init, so relaunching mid-workout resumes cleanly.
@Observable
@MainActor
final class WorkoutController {
    private let context: ModelContext
    private(set) var activeSession: WorkoutSession?

    init(context: ModelContext) {
        self.context = context
        self.activeSession = Self.fetchActiveSession(in: context)
    }

    var hasActiveSession: Bool { activeSession != nil }

    enum WorkoutError: Error, Equatable {
        case sessionAlreadyActive
    }

    // MARK: Lifecycle

    func start(from routine: Routine) throws -> WorkoutSession {
        guard activeSession == nil else { throw WorkoutError.sessionAlreadyActive }

        let session = WorkoutSession(
            startedAt: .now,
            sourceRoutine: routine,
            sourceRoutineName: routine.name
        )
        context.insert(session)

        for item in routine.orderedItems {
            guard let exercise = item.exercise else { continue }
            session.exercises.append(WorkoutExercise(
                exercise: exercise,
                exerciseID: exercise.id,
                order: item.order,
                targetSets: item.targetSets,
                targetRepMin: item.targetRepMin,
                targetRepMax: item.targetRepMax,
                restSeconds: item.targetRestSeconds ?? exercise.defaultRestSeconds
            ))
        }

        save()
        activeSession = session
        return session
    }

    func finish(_ session: WorkoutSession) {
        let finishedAt = Date.now
        session.endedAt = finishedAt
        session.sourceRoutine?.lastPerformedAt = finishedAt
        save()
        if activeSession?.id == session.id { activeSession = nil }
    }

    func discard(_ session: WorkoutSession) {
        context.delete(session)
        save()
        if activeSession?.id == session.id { activeSession = nil }
    }

    // MARK: Editing

    func addExercise(_ exercise: Exercise, to session: WorkoutSession) {
        let order = (session.orderedExercises.last?.order ?? -1) + 1
        session.exercises.append(WorkoutExercise(
            exercise: exercise,
            exerciseID: exercise.id,
            order: order,
            restSeconds: exercise.defaultRestSeconds
        ))
        save()
    }

    @discardableResult
    func addSet(
        to workoutExercise: WorkoutExercise,
        weightKg: Double?,
        addedWeightKg: Double?,
        reps: Int,
        rpe: Double?,
        isWarmup: Bool
    ) -> ExerciseSet {
        let order = (workoutExercise.orderedSets.last?.order ?? -1) + 1
        let set = ExerciseSet(
            order: order,
            weightKg: weightKg,
            addedWeightKg: addedWeightKg,
            reps: reps,
            rpe: rpe,
            isWarmup: isWarmup
        )
        workoutExercise.sets.append(set)
        save()
        return set
    }

    func deleteSet(_ set: ExerciseSet) {
        context.delete(set)
        save()
    }

    func toggleComplete(_ set: ExerciseSet) {
        set.isComplete.toggle()
        set.completedAt = set.isComplete ? .now : nil
        save()
    }

    // MARK: Helpers

    private func save() {
        do {
            try context.save()
        } catch {
            assertionFailure("WorkoutController save failed: \(error)")
        }
    }

    private static func fetchActiveSession(in context: ModelContext) -> WorkoutSession? {
        var descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.endedAt == nil },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }
}
