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
    /// Lives here rather than in the workout screen so the countdown can sit in
    /// the tab bar's accessory and survive leaving the screen.
    let restTimer: RestTimer

    init(context: ModelContext, restTimer: RestTimer = RestTimer()) {
        self.context = context
        self.restTimer = restTimer
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
            let workoutExercise = WorkoutExercise(
                exercise: exercise,
                exerciseID: exercise.id,
                order: item.order,
                targetSets: item.targetSets,
                targetRepMin: item.targetRepMin,
                targetRepMax: item.targetRepMax,
                restSeconds: item.targetRestSeconds ?? exercise.defaultRestSeconds
            )
            session.exercises.append(workoutExercise)
            prefillSets(for: workoutExercise, in: session)
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
        restTimer.skip()
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
        restTimer.skip()
        context.delete(session)
        save()
        if activeSession?.id == session.id { activeSession = nil }
    }

    /// Sets are laid out up front so the screen shows the whole plan: the
    /// routine's target count, each pre-filled from the matching set last time
    /// (or the last one logged, when there are fewer). They start unticked and
    /// are pruned at finish if never done, so nothing is logged by default.
    private func prefillSets(for workoutExercise: WorkoutExercise, in session: WorkoutSession) {
        let last = LastPerformance.mostRecentSets(
            ofExerciseID: workoutExercise.exerciseID,
            excludingSession: session.id,
            in: context
        )
        let count = workoutExercise.targetSets ?? last.count
        guard count > 0 else { return }

        for index in 0..<count {
            let reference = last.isEmpty ? nil : last[min(index, last.count - 1)]
            workoutExercise.sets.append(ExerciseSet(
                order: index,
                weightKg: reference?.weightKg,
                addedWeightKg: reference?.addedWeightKg,
                reps: reference?.reps ?? workoutExercise.targetRepMin ?? 8
            ))
        }
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

    /// Reorders the session's exercises with `IndexSet`/offset semantics, as
    /// `List.onMove` reports them. Every survivor's `order` is rewritten so it
    /// stays contiguous.
    func moveExercises(in session: WorkoutSession, from source: IndexSet, to destination: Int) {
        var exercises = session.orderedExercises
        exercises.move(fromOffsets: source, toOffset: destination)
        for (position, exercise) in exercises.enumerated() where exercise.order != position {
            exercise.order = position
        }
        save()
    }

    /// Drops an exercise from the session along with anything logged in it.
    func removeExercise(_ workoutExercise: WorkoutExercise) {
        let survivors = workoutExercise.session?.orderedExercises.filter { $0 !== workoutExercise } ?? []
        context.delete(workoutExercise)
        for (position, survivor) in survivors.enumerated() where survivor.order != position {
            survivor.order = position
        }
        save()
    }

    /// Rewrites the routine's items to match the exercises the workout ended up
    /// with. Existing items keep their targets; exercises added mid-workout
    /// start with none.
    func updateRoutine(_ routine: Routine, toMatch plan: [RoutineSync.PlannedExercise]) {
        let existing = Dictionary(routine.items.map { ($0.exercise?.id, $0) }, uniquingKeysWith: { first, _ in first })
        var kept: [RoutineItem] = []
        for (position, planned) in plan.enumerated() {
            if let item = existing[planned.exercise.id] {
                item.order = position
                kept.append(item)
            } else {
                let item = RoutineItem(
                    exercise: planned.exercise,
                    order: position,
                    targetSets: planned.targetSets,
                    targetRepMin: planned.targetRepMin,
                    targetRepMax: planned.targetRepMax,
                    targetRestSeconds: planned.restSeconds
                )
                routine.items.append(item)
                kept.append(item)
            }
        }
        for item in routine.items where !kept.contains(where: { $0 === item }) {
            context.delete(item)
        }
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
