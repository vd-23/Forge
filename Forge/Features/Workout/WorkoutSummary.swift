import Foundation
import ForgeCore

/// A personal record, resolved to something the summary screen can print.
struct PRHitDisplay: Identifiable {
    let id = UUID()
    let exerciseName: String
    let kind: PRKind
}

/// What a finished workout amounted to. Built once at finish time and handed to
/// the summary sheet, so the sheet never re-reads the model objects.
struct WorkoutSummary: Identifiable {
    let id = UUID()
    let durationSeconds: Int
    let totalVolumeKg: Double
    let workingSetCount: Int
    let bodyParts: [BodyPart]
    let prHits: [PRHitDisplay]

    var durationLabel: String { DurationFormatting.short(seconds: durationSeconds) }
}

@MainActor
enum WorkoutSummaryBuilder {
    /// - Parameter history: every *other* finished session. `newPersonalRecords`
    ///   requires `session` itself to be absent, or nothing would ever be a PR.
    static func build(
        session: WorkoutSession,
        finishedAt: Date,
        history: [SessionInput]
    ) -> WorkoutSummary {
        let input = session.coreInput
        let names = exerciseNames(in: session)

        let workingSetCount = input.exercises.reduce(0) { count, exercise in
            count + workingSets(exercise.sets).count
        }

        let hits = newPersonalRecords(in: input, history: history).map { hit in
            PRHitDisplay(exerciseName: names[hit.exerciseID] ?? "Exercise", kind: hit.kind)
        }

        return WorkoutSummary(
            durationSeconds: Int(finishedAt.timeIntervalSince(session.startedAt).rounded()),
            totalVolumeKg: sessionVolumeKg(input),
            workingSetCount: workingSetCount,
            bodyParts: trainedBodyParts(in: session),
            prHits: hits
        )
    }

    /// Primary body parts in workout order, de-duplicated, counting only
    /// exercises that were actually worked rather than merely planned.
    private static func trainedBodyParts(in session: WorkoutSession) -> [BodyPart] {
        var parts: [BodyPart] = []
        for workoutExercise in session.orderedExercises {
            guard workoutExercise.orderedSets.contains(where: \.isWorkingSet),
                  let part = workoutExercise.exercise?.primaryBodyPart,
                  !parts.contains(part)
            else { continue }
            parts.append(part)
        }
        return parts
    }

    private static func exerciseNames(in session: WorkoutSession) -> [UUID: String] {
        session.orderedExercises.reduce(into: [:]) { names, workoutExercise in
            if let name = workoutExercise.exercise?.name {
                names[workoutExercise.exerciseID] = name
            }
        }
    }
}

extension PRKind {
    var displayName: String {
        switch self {
        case .weight: "Heaviest weight"
        case .reps: "Most reps"
        case .e1rm: "Best estimated 1RM"
        }
    }
}
