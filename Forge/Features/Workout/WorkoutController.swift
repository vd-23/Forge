import Foundation
import ForgeCore
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

    /// Stamps the session finished and returns what it amounted to, or `nil`
    /// when nothing was logged and the session was discarded instead.
    ///
    /// History is read *before* the end timestamp is written, so the session
    /// being finished cannot count as its own previous best.
    @discardableResult
    func finish(_ session: WorkoutSession) -> WorkoutSummary? {
        guard session.exercises.contains(where: { $0.sets.contains(where: \.isComplete) }) else {
            discard(session)
            return nil
        }
        pruneUnloggedWork(from: session)

        let history = finishedSessionInputs(excluding: session.id)
        let finishedAt = Date.now
        session.endedAt = finishedAt
        session.sourceRoutine?.lastPerformedAt = finishedAt
        save()
        if activeSession?.id == session.id { activeSession = nil }
        return WorkoutSummaryBuilder.build(session: session, finishedAt: finishedAt, history: history)
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
        // The survivors are captured before the delete: the relationship may
        // not have dropped the deleted set yet when we renumber.
        let survivors = set.workoutExercise?.orderedSets.filter { $0 !== set } ?? []
        context.delete(set)
        for (position, survivor) in survivors.enumerated() where survivor.order != position {
            survivor.order = position
        }
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

    /// A set that was never ticked was never performed — volume and PRs already
    /// ignored it, so keeping it only litters history. An exercise that was
    /// planned but never worked goes with its sets.
    private func pruneUnloggedWork(from session: WorkoutSession) {
        for workoutExercise in session.exercises {
            let wasWorked = workoutExercise.sets.contains(where: \.isComplete)
            for set in workoutExercise.sets where !set.isComplete {
                context.delete(set)
            }
            if !wasWorked { context.delete(workoutExercise) }
        }
    }

    private func finishedSessionInputs(excluding sessionID: UUID) -> [SessionInput] {
        let descriptor = FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.endedAt != nil })
        let sessions = (try? context.fetch(descriptor)) ?? []
        return sessions.filter { $0.id != sessionID }.map(\.coreInput)
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
